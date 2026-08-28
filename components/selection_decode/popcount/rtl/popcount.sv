// ============================================================================
// popcount — 人口统计/位计数（Population Count, SEL-014, A1/P1）
// VLNV: aixsilicon:cbb:popcount:0.1.0
// ----------------------------------------------------------------------------
// 语义：popcnt = sum(din[i]) = din 中 1 的个数；结果位宽 NBITS=$clog2(W+1)。
// 纯组合，X 输入不作承诺（ASM-001）。
//
// PC_IMPL 微架构选择（面积/时序 Pareto 实证对比，见 reports/ppa-report.md）：
//   0 = DIRECT   直接加法基线：W 个 1-bit 计数串行相加（加法器链，O(W) 级深）
//                结构最直观，作为 PPA 的"最差/最直接"参照基线
//   1 = TREE     平衡归约树：2 输入加法器逐级折半（O(log W) 级深，全并行，
//                深度最小，时序最优）
//   2 = WALLACE  Wallace tree（3:2 FA + 2:1 HA 归约），tools/gen_popcount.py 生成
//   3 = COMP4_2  4:2 compressor（cin/cout 列间链）+ FA/HA 归约，同样由生成器生成
//   4 = LUT      4bit 子块 LUT 查表（case 真值表）+ 小加法树，结构规整
//
// Wallace/compressor 由 Python 动态展开的原因：归约级数、每级列高、4:2 列间
// cin/cout 链随 W 变化；用 generate 参数化模板冗长易错且结构不可预测。生成器
// 按位宽显式展开为扁平 assign 网表（结构完全确定，综合/STA 结果可复现）。
// 生成源 tools/gen_popcount.py 为 SSOT，rtl/gen/*.sv 为派生物（重新生成不手改）。
// ============================================================================

`include "gen/popcount_wallace_d8.sv"
`include "gen/popcount_wallace_d16.sv"
`include "gen/popcount_wallace_d32.sv"
`include "gen/popcount_wallace_d64.sv"
`include "gen/popcount_compressor_d8.sv"
`include "gen/popcount_compressor_d16.sv"
`include "gen/popcount_compressor_d32.sv"
`include "gen/popcount_compressor_d64.sv"

module popcount #(
    parameter int DATA_W  = 32,
    parameter int PC_IMPL = 1            // {0=direct,1=tree,2=wallace,3=comp4_2,4=lut}
) (
    input  logic [DATA_W-1:0] din,
    output logic [$clog2(DATA_W+1)-1:0] popcnt
);
    localparam int W     = DATA_W;
    localparam int NBITS = $clog2(W + 1);   // 结果 0..W 所需位数

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..004）----
    generate
        if (W < 2 || W > 1024) begin : g_param_w
            $error("popcount PC-001/002 violation: DATA_W=%0d outside [2..1024]", W);
        end
        if (PC_IMPL < 0 || PC_IMPL > 4) begin : g_param_impl
            $error("popcount illegal PC_IMPL=%0d not in {0,1,2,3,4}", PC_IMPL);
        end
        // Wallace/compressor 生成器仅支持 {8,16,32,64}
        if ((PC_IMPL == 2 || PC_IMPL == 3) &&
            (W != 8 && W != 16 && W != 32 && W != 64)) begin : g_param_genw
            $error("popcount PC-004 violation: PC_IMPL=%0d only supports DATA_W in {8,16,32,64} (got %0d); use DIRECT/TREE/LUT for other widths", PC_IMPL, W);
        end
    endgenerate

    // ---- 实现分派（多实现：同契约等价）----
    generate
        if (PC_IMPL == 0) begin : g_direct
            popcount_impl_direct #(.DATA_W(W)) u_impl (.din(din), .popcnt(popcnt));
        end else if (PC_IMPL == 1) begin : g_tree
            popcount_impl_tree   #(.DATA_W(W)) u_impl (.din(din), .popcnt(popcnt));
        end else if (PC_IMPL == 2) begin : g_wallace
            if (W == 8)  popcount_wallace_d8  u_gen (.din(din), .popcnt(popcnt));
            if (W == 16) popcount_wallace_d16 u_gen (.din(din), .popcnt(popcnt));
            if (W == 32) popcount_wallace_d32 u_gen (.din(din), .popcnt(popcnt));
            if (W == 64) popcount_wallace_d64 u_gen (.din(din), .popcnt(popcnt));
        end else if (PC_IMPL == 3) begin : g_comp
            if (W == 8)  popcount_compressor_d8  u_gen (.din(din), .popcnt(popcnt));
            if (W == 16) popcount_compressor_d16 u_gen (.din(din), .popcnt(popcnt));
            if (W == 32) popcount_compressor_d32 u_gen (.din(din), .popcnt(popcnt));
            if (W == 64) popcount_compressor_d64 u_gen (.din(din), .popcnt(popcnt));
        end else begin : g_lut
            popcount_impl_lut    #(.DATA_W(W)) u_impl (.din(din), .popcnt(popcnt));
        end
    endgenerate

    // ---- 就近 SVA（关键不变量）----
    // 本构件纯组合无时钟；内嵌 always_comb 立即断言会在 t=0 输入未初始化时误报
    // （X 传播），且 $isunknown 防护不可综合（SpyGlass SYNTH_5285）。故 RTL 不内嵌
    // 可综合断言，正确性由验证台黄金模型 + 多实现等价覆盖（verification/simulation/
    // popcount_tb.sv：tc_exhaust_w4/w8、tc_edge、tc_random、tc_equiv）。
    // 行为契约见 behavior.yaml（INV-001/002/003）。

endmodule

// ============================================================================
// popcount_impl_direct — 直接加法基线（O(W) 级加法器链）
//   把 W 个输入位当作 W 个 1-bit 计数，串行两两相加为 2bit、3bit、… 直到 W-bit。
//   结构最直观（"把 1 的个数一个个加起来"），面积/时序最差，作为 PPA 基线参照。
// ============================================================================
module popcount_impl_direct #(
    parameter int DATA_W = 32
) (
    input  logic [DATA_W-1:0] din,
    output logic [$clog2(DATA_W+1)-1:0] popcnt
);
    localparam int W     = DATA_W;
    localparam int NBITS = $clog2(W + 1);

    // acc[i] = 前 i 个输入位的计数（串行累加，按 W 缩放，避免大静态数组）
    logic [NBITS:0] acc [0:W];
    assign acc[0] = '0;
    for (genvar i = 0; i < W; i++) begin : g_acc
        assign acc[i+1] = acc[i] + din[i];
    end
    assign popcnt = acc[W][NBITS-1:0];
endmodule

// ============================================================================
// popcount_impl_tree — 平衡归约树（O(log W) 级，全并行）
//   每级把相邻两节点的 2 输入计数相加；lv[0]=各输入位，逐级折半至单节点。
//   深度最小、时序最优，作为"理想深度"参照。
// ============================================================================
module popcount_impl_tree #(
    parameter int DATA_W = 32
) (
    input  logic [DATA_W-1:0] din,
    output logic [$clog2(DATA_W+1)-1:0] popcnt
);
    localparam int W     = DATA_W;
    localparam int NBITS = $clog2(W + 1);
    localparam int NLEV  = $clog2(W) + 1;    // lv[0]..lv[NLEV-1]（末级 1 节点）

    // lv[s] 有 ceil(W/2^s) 个节点，每节点 NBITS+1 位计数；第二维按 W 缩放
    logic [NBITS:0] lv [0:NLEV-1][0:W];
    generate
        for (genvar s = 0; s < NLEV; s++) begin : g_lev
            localparam int CNT  = (W + (1 << s) - 1) >> s;       // 本级节点数
            localparam int PREV = (s == 0) ? 0 : (W + (1 << (s-1)) - 1) >> (s-1);  // 上一级节点数
            for (genvar j = 0; j < CNT; j++) begin : g_node
                if (s == 0) begin
                    assign lv[0][j] = {NBITS'(1'b0), din[j]};
                end else if (2*j + 1 < PREV) begin
                    assign lv[s][j] = lv[s-1][2*j] + lv[s-1][2*j+1];
                end else begin
                    assign lv[s][j] = lv[s-1][2*j];              // 奇数直通
                end
            end
        end
    endgenerate
    assign popcnt = lv[NLEV-1][0][NBITS-1:0];
endmodule

// ============================================================================
// popcount_impl_lut — LUT 查找表（4bit 子块查表 + 小加法树）
//   每 4 输入位一个 3-bit 计数真值表（case），再以折半加法树合并各子块计数。
//   结构规整、面积可预测，适合中小位宽（综合映射为查找表/复用逻辑）。
// ============================================================================
module popcount_impl_lut #(
    parameter int DATA_W = 32
) (
    input  logic [DATA_W-1:0] din,
    output logic [$clog2(DATA_W+1)-1:0] popcnt
);
    localparam int W     = DATA_W;
    localparam int NBITS = $clog2(W + 1);
    localparam int NBLK  = (W + 3) / 4;      // 4bit 子块数
    localparam int NLEV  = $clog2(NBLK) + 1;

    // 4bit → 3bit popcount 真值表
    function automatic logic [2:0] lut4(input logic [3:0] v);
        case (v)
            4'b0000: lut4 = 3'd0;  4'b0001: lut4 = 3'd1;  4'b0010: lut4 = 3'd1;  4'b0011: lut4 = 3'd2;
            4'b0100: lut4 = 3'd1;  4'b0101: lut4 = 3'd2;  4'b0110: lut4 = 3'd2;  4'b0111: lut4 = 3'd3;
            4'b1000: lut4 = 3'd1;  4'b1001: lut4 = 3'd2;  4'b1010: lut4 = 3'd2;  4'b1011: lut4 = 3'd3;
            4'b1100: lut4 = 3'd2;  4'b1101: lut4 = 3'd3;  4'b1110: lut4 = 3'd3;  4'b1111: lut4 = 3'd4;
            default: lut4 = 3'd0;
        endcase
    endfunction

    logic [2:0] blk [0:NBLK-1];              // 各子块计数（按 NBLK 缩放）
    logic [NBITS:0] lv [0:NLEV-1][0:NBLK];

    generate
        for (genvar b = 0; b < NBLK; b++) begin : g_blk
            if (b*4 + 4 <= W) begin
                assign blk[b] = lut4(din[b*4 +: 4]);
            end else begin
                // 末块不足 4bit：高位补 0
                logic [3:0] t4;
                assign t4 = '0;
                for (genvar k = 0; k < W - b*4; k++) begin : g_pad
                    assign t4[k] = din[b*4 + k];
                end
                assign blk[b] = lut4(t4);
            end
        end
        // 折半合并各子块计数（3bit → 4bit → ... → NBITS+1 bit）
        for (genvar s = 0; s < NLEV; s++) begin : g_lev
            localparam int CNT  = (NBLK + (1 << s) - 1) >> s;
            localparam int PREV = (s == 0) ? 0 : (NBLK + (1 << (s-1)) - 1) >> (s-1);
            for (genvar j = 0; j < CNT; j++) begin : g_node
                if (s == 0) begin
                    assign lv[0][j] = {NBITS'(1'b0), blk[j]};
                end else if (2*j + 1 < PREV) begin
                    assign lv[s][j] = lv[s-1][2*j] + lv[s-1][2*j+1];
                end else begin
                    assign lv[s][j] = lv[s-1][2*j];
                end
            end
        end
    endgenerate
    assign popcnt = lv[NLEV-1][0][NBITS-1:0];
endmodule
