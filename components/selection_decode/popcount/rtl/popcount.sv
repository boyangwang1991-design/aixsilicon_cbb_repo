// ============================================================================
// popcount — 纯组合 Hamming 权重计数原子构件 (A1, SEL-014)
// VLNV: aixsilicon:cbb:popcount:0.1.0   Change C2: 打平布局 + 四实现
// ----------------------------------------------------------------------------
// 打平布局（用户指令）：本目录无子级目录结构；
//   popcount.sv             = wrapper + 参数检查 + SVA + 四路分派（本文件）
//   popcount_compressed.sv  = wallace 显式 FA 核（gen_schedule.py 生成）
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
// ============================================================================
// popcount_impl_lut — SWAR 分级归并计数（Change C3 重构：综合友好形态）
// ----------------------------------------------------------------------------
// 经典 SWAR（SIMD-within-a-register）popcount：log₂(W/2) 级固定深度，
// 每级把相邻「段计数」按位分段相加（段宽逐级 ×2）：
//   L1: 每 2-bit 段 = bit0+bit1（1 位段宽 → 2 位段宽）
//   L2: 每 4-bit 段 = 两个 2-bit 段计数相加
//   ... 直到段宽 = W，值即 Hamming 权重
// 每级仅 W/2^k 个窄加法（最大位宽 CNT_W），零 ROM/mux 网络、零除法；
// DC 对该形态有成熟折叠模式（等价于让综合器看到平衡树骨架）。
// "LUT/查表"语义升级为「查表→SWAR」实现，保留实现名以稳契约/Profile。
// ============================================================================
module popcount_impl_lut #(
    parameter int INPUT_WIDTH = 64,
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    localparam int W = INPUT_WIDTH;

    generate
        if (INPUT_WIDTH < 4 || INPUT_WIDTH > 256) begin : g_w
            $error("popcount_impl_lut: INPUT_WIDTH outside legal [4..256]");
        end
    endgenerate

    // ---- 级 0：2-bit 段计数（每段 = 两 bit 相加，1+1<=2 恰 2 位段宽）----
    // 掩码模板：0x5555...（奇位保留）与 0x3333...（两 bit 段保留）
    localparam int W2 = (W + 1) / 2;             // 2-bit 段数
    logic [W2-1:0][1:0] lvl2;                    // 每段 2-bit 计数
    for (genvar s = 0; s < W2; s++) begin : g_l1
        assign lvl2[s] = {1'b0, data_i[2*s]} + {1'b0, (2*s+1 < W) ? data_i[2*s+1] : 1'b0};
    end

    // ---- 逐级合并（SWAR shift/mask/add 三步），段宽 2→4→8→…→≥W ----
    // mask 用编译期生成 pattern（每段低 seg 位全 1），隔离跨段进位；
    // 加法为并行窄加法——无 ROM、无大 mux、无除法。
    logic [W-1:0] acc;
    logic [W-1:0] shifted;
    logic [W-1:0] masked_a;
    logic [W-1:0] masked_b;

    always_comb begin
        // 初始：lvl2 打平进 acc
        acc = '0;
        for (int s = 0; s < W2; s++) acc[2*s +: 2] = lvl2[s];

        for (int seg = 2; seg < W; seg = seg << 1) begin
            shifted = acc >> seg;
            masked_a = '0;
            masked_b = '0;
            for (int base = 0; base < W; base += 2*seg) begin
                for (int k2 = 0; k2 < seg && base+k2 < W; k2++) begin
                    masked_a[base+k2] = acc[base+k2];
                    masked_b[base+k2] = shifted[base+k2];
                end
            end
            acc = masked_a + masked_b;
        end
        cnt_o = CNT_W'(acc);
    end
endmodule
