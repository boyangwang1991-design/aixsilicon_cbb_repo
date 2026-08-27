// ============================================================================
// popcount_impl_tree — 平衡加法树实现 (design.md §1.1 冻结稿, 默认推荐 impl)
// ----------------------------------------------------------------------------
// 结构：W 个 1-bit 操作数起点 → generate 分层两两归并：第 k 层将两个 (k)-bit
//       部分和合成 ((k+1))-bit；奇数末项直通（补零参与，不改函数值）。
//       共 LEVELS = $clog2(W)+1 层收敛到 1 个节点 = cnt。
// 值域论证：任一节点 ≤ min(2^k, W) ≤ W < 2^CNT_W → 统一 CNT_W 位宽无溢出截断。
// 极简单文件：无 package/interface，常量内联，elaboration 期全部静态展开。
// ============================================================================

module popcount_impl_tree #(
    parameter int INPUT_WIDTH = 64,
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)  // 派生端口宽度（防篡改一致性见下）
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    localparam int W = INPUT_WIDTH;

    // ---- 一致性卫兵（防止外部显式覆写不一致的派生参数）----
    generate
        if (INPUT_WIDTH < 4 || INPUT_WIDTH > 256) begin : g_illegal_w
            $error("popcount_impl_tree: INPUT_WIDTH=%0d outside legal [4..256]", INPUT_WIDTH);
        end
        if (CNT_W != $clog2(INPUT_WIDTH + 1)) begin : g_cntw_mismatch
            $error("popcount_impl_tree: CNT_W=%0d inconsistent with INPUT_WIDTH=%0d",
                   CNT_W, INPUT_WIDTH);
        end
    endgenerate

    // ---- 分层结构与节点数（编译期常量）----
    localparam int LEVELS = $clog2(W) + 1;                 // W>=4 保证 >=3 层
    // 第 k 层节点数: ceil(W / 2^k)；k=0 即输入位
    function automatic int level_nodes(input int k);
        return (W + (1 << k) - 1) >> k;
    endfunction

    // nodes[k][j] = 第 k 层第 j 个节点（统一 CNT_W 位宽，高位按需恒 0）
    logic [CNT_W-1:0] nodes [LEVELS][W];

    // ---- 层 0：输入位展开 ----
    for (genvar b = 0; b < W; b++) begin : g_l0
        assign nodes[0][b] = CNT_W'(data_i[b]);
    end

    // ---- 层 1..LEVELS-1：两两归并，奇末项直通 ----
    for (genvar k = 1; k < LEVELS; k++) begin : g_fold
        localparam int NK   = level_nodes(k);              // 本层节点数
        localparam int NPRE = level_nodes(k-1);            // 上层节点数
        for (genvar j = 0; j < NK; j++) begin : g_pair
            if (2*j + 1 < NPRE) begin : g_add
                assign nodes[k][j] = nodes[k-1][2*j] + nodes[k-1][2*j + 1];
            end else begin : g_pass
                assign nodes[k][j] = nodes[k-1][2*j];
            end
        end
    end

    assign cnt_o = nodes[LEVELS-1][0];                     // 根节点 = Hamming 权重

endmodule
