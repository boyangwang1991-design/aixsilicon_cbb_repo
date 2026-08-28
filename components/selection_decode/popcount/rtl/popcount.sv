// ============================================================================
// popcount — 纯组合 Hamming 权重计数原子构件 (A1, SEL-014)
// VLNV: aixsilicon:cbb:popcount:0.1.0   Change C2: 打平布局 + 四实现
// ----------------------------------------------------------------------------
// 打平布局（用户指令）：本目录无子级目录结构；
//   popcount.sv             = wrapper + 参数检查 + SVA + 四路分派（本文件）
//   popcount_compressed.sv  = wallace 显式 FA 核（gen_schedule.py 生成）
//   pc_sched_table.svh      = 调度常量表          （同上生成）
//   pc_lut_pkg_inline 内嵌分级查表函数（见 POPCNT_IMPL_LUT）
//
// PC_IMPL 微架构选择（profile 挂接点）：
//   0 = TREE    平衡加法树（默认推荐，28nm@1GHz 主选）
//   1 = WALLACE 能压尽压显式 FA 压缩核
//   2 = LUT     分级查表（nibble LUT4 → chunk 合并 → 小归并树）
//
// 函数定义: cnt_o = Σ data_i[b]；X 输入不作承诺（ASM-001）。
// ============================================================================

module popcount #(
    parameter int INPUT_WIDTH = 64,
    // 派生端口宽度参数（一致性由 g_cntw 卫兵校验；见 domain-rules §3.1.1）
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1),
    // 微架构选择 {0=TREE,1=WALLACE,2=LUT}  (Change C3: dadda 移除)
    parameter int PC_IMPL     = 0
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    localparam int W = INPUT_WIDTH;

    generate
        if (INPUT_WIDTH < 4 || INPUT_WIDTH > 256) begin : g_param_w
            $error("popcount PC-001 violation: INPUT_WIDTH=%0d outside legal [4..256]",
                   INPUT_WIDTH);
        end
        if (CNT_W != $clog2(INPUT_WIDTH + 1)) begin : g_cntw
            $error("popcount CNT_W=%0d inconsistent with INPUT_WIDTH=%0d",
                   CNT_W, INPUT_WIDTH);
        end
        if (PC_IMPL < 0 || PC_IMPL > 2) begin : g_param_impl
            $error("popcount illegal microarchitecture select: PC_IMPL=%0d not in {0..3}",
                   PC_IMPL);
        end
    endgenerate


    // pc_sched_table.svh 已随 define 就位——压缩核依赖其常量函数

    // ------------------------------------------------------------------
    // 分派
    // ------------------------------------------------------------------
    generate
        if (PC_IMPL == 0) begin : g_tree
            popcount_impl_tree #(.INPUT_WIDTH(W)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
        end else if (PC_IMPL == 2) begin : g_lut
            popcount_impl_lut #(.INPUT_WIDTH(W)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
`ifdef POPCNT_WALLACE_ON
        end else if (PC_IMPL == 1) begin : g_wallace
            popcount_impl_wallace #(.INPUT_WIDTH(64)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
`endif
        end else begin : g_fallback
            $error("popcount: PC_IMPL=%0d unavailable — enable matching POPCNT macro",
                   PC_IMPL);
        end
    endgenerate

endmodule

// ============================================================================
// popcount_impl_tree — 平衡加法树（保留原实现；O(log W) 深度默认推荐）
// ============================================================================
module popcount_impl_tree #(
    parameter int INPUT_WIDTH = 64,
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    localparam int W = INPUT_WIDTH;
    localparam int LEVELS = $clog2(W) + 1;

    function automatic int level_nodes(input int k);
        return (W + (1 << k) - 1) >> k;
    endfunction

    logic [CNT_W-1:0] nodes [LEVELS][W];

    for (genvar b = 0; b < W; b++) begin : g_l0
        assign nodes[0][b] = CNT_W'(data_i[b]);
    end
    for (genvar k = 1; k < LEVELS; k++) begin : g_fold
        localparam int NK   = level_nodes(k);
        localparam int NPRE = level_nodes(k-1);
        for (genvar j = 0; j < NK; j++) begin : g_pair
            if (2*j + 1 < NPRE) begin : g_add
                assign nodes[k][j] = nodes[k-1][2*j] + nodes[k-1][2*j + 1];
            end else begin : g_pass
                assign nodes[k][j] = nodes[k-1][2*j];
            end
        end
    end
    assign cnt_o = nodes[LEVELS-1][0];
endmodule

// ============================================================================
// popcount_impl_lut — 分级查表（Change C2 重构：LUT2 nibble → 字节合并 → 树）
// ----------------------------------------------------------------------------
// 三级流水式组合分层（非流水，纯组合层级）：
//   L1 nibble 表：16 entry ROM，per 4-bit
//   L2 chunk 合并：两两 (nibble_hi<<?) 无——按字节段把 2 个 nibble 权重相加
//      （+chunk 补零对齐），等价于每字节 8→cnt(8bit)=0..8 的 mini 加法器对
//   L3 归并树：各 chunk 结果经平衡加法树合并（复用 tree 折叠模式）
// 面积导向；小宽度最优。与 tree 共享常数折叠收益。
// ============================================================================
module popcount_impl_lut #(
    parameter int INPUT_WIDTH = 64,
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    localparam int W    = INPUT_WIDTH;
    localparam int NIBS = (W + 3) / 4;           // nibble 数

    // ---- L1: nibble 计数表（case 全枚举 0..15，推断 16x3 ROM/LUT4）----
    function automatic logic [2:0] cnt_nib(input logic [3:0] v);
        case (v)
            4'd0:  cnt_nib = 3'd0;
            4'd1,4'd2,4'd4,4'd8: cnt_nib = 3'd1;
            4'd3,4'd5,4'd6,4'd9,4'd10,4'd12: cnt_nib = 3'd2;
            4'd7,4'd11,4'd13,4'd14: cnt_nib = 3'd3;
            default: cnt_nib = 3'd4;              // 4'b1111
        endcase
    endfunction

    // ---- L2: nibble → 累计块（每块 = 一对 nibble 相加 = byte 计数）----
    // 末尾越界 nibble 用安全高位补零向量（先零扩展 W 到 4*NIBS，规避负 multiconcat）
    localparam int WPAD = NIBS * 4;
    logic [WPAD-1:0] d_pad;
    always_comb begin
        d_pad = '0;
        d_pad[W-1:0] = data_i;
    end

    localparam int NPAIR = (NIBS + 1) / 2;
    logic [CNT_W-1:0] pair_cnt [NPAIR];
    for (genvar p = 0; p < NPAIR; p++) begin : g_pair_cnt
        localparam int LO = 8 * p;                       // byte 基址
        assign pair_cnt[p] = CNT_W'(cnt_nib(d_pad[LO +: 4])) +
                             CNT_W'(cnt_nib(d_pad[LO + 4 +: 4]));
    end

    // ---- L3: 平衡合并树（NSEG=pair 数）----
    localparam int MLEVELS = $clog2(NPAIR) + 1;
    function automatic int mnodes(input int k);
        return (NPAIR + (1 << k) - 1) >> k;
    endfunction
    logic [CNT_W-1:0] mn [MLEVELS][NPAIR];
    for (genvar s = 0; s < NPAIR; s++) begin : g_m0
        assign mn[0][s] = pair_cnt[s];
    end
    for (genvar k = 1; k < MLEVELS; k++) begin : g_mfold
        localparam int NK   = mnodes(k);
        localparam int NPRE = mnodes(k-1);
        for (genvar j = 0; j < NK; j++) begin : g_mpair
            if (2*j + 1 < NPRE) begin : g_add
                assign mn[k][j] = mn[k-1][2*j] + mn[k-1][2*j + 1];
            end else begin : g_pass
                assign mn[k][j] = mn[k-1][2*j];
            end
        end
    end
    assign cnt_o = mn[MLEVELS-1][0];
endmodule
