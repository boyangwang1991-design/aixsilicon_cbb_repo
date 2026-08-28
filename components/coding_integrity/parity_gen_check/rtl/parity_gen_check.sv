// ============================================================================
// parity_gen_check — 纯组合奇偶校验原子构件 (A1, COD-001)
// VLNV: aixsilicon:cbb:parity_gen_check:0.1.0
// ----------------------------------------------------------------------------
// PC_IMPL 微架构选择（XOR 归约三形态，PPA 实证对比）：
//   0 = TREE        显式平衡 XOR 折半树（generate，O(log W) 深度）
//   1 = REDUCTION   一行 reduction XOR（^data_i，综合器自动生成最优平衡树）
//   2 = LINEAR      显式线性 XOR 链（O(W) 深度）
// PARITY_TYPE: {0=even, 1=odd}（int 枚举——DC 综合不支持 string 参数，VER-700 教训）
// 函数: parity_o = ^data_i（even）/ ~^data_i（odd）；X 输入不作承诺（ASM-001）。
// ============================================================================

module parity_gen_check #(
    parameter int DATA_WIDTH  = 64,
    parameter int PARITY_TYPE = 0,          // {0=even, 1=odd}
    parameter int PC_IMPL     = 0           // {0=TREE,1=REDUCTION,2=LINEAR}
) (
    input  logic [DATA_WIDTH-1:0] data_i,
    output logic                  parity_o
);
    localparam int W = DATA_WIDTH;
    localparam logic FLIP = (PARITY_TYPE == 1) ? 1'b1 : 1'b0;

    logic xor_i;

    generate
        if (DATA_WIDTH < 4 || DATA_WIDTH > 512) begin : g_param_w
            $error("parity_gen_check PC-001/002 violation: DATA_WIDTH=%0d outside legal [4..512]",
                   DATA_WIDTH);
        end
        if (PARITY_TYPE < 0 || PARITY_TYPE > 1) begin : g_param_p
            $error("parity_gen_check illegal PARITY_TYPE=%0d not in {0,1}", PARITY_TYPE);
        end
        if (PC_IMPL < 0 || PC_IMPL > 2) begin : g_param_impl
            $error("parity_gen_check illegal PC_IMPL=%0d not in {0,1,2}", PC_IMPL);
        end
    endgenerate

    // ---- 分派（多实现：XOR 归约三形态）----
    generate
        if (PC_IMPL == 0) begin : g_tree
            parity_impl_tree #(.DATA_WIDTH(W)) u_impl (.data_i(data_i), .parity_i(xor_i));
        end else if (PC_IMPL == 1) begin : g_reduction
            parity_impl_reduction #(.DATA_WIDTH(W)) u_impl (.data_i(data_i), .parity_i(xor_i));
        end else begin : g_linear
            parity_impl_linear #(.DATA_WIDTH(W)) u_impl (.data_i(data_i), .parity_i(xor_i));
        end
    endgenerate

    assign parity_o = xor_i ^ FLIP;

    // ---- 就近 SVA（INV-001 函数一致性；纯组合用 immediate assertion，综合忽略）----
    generate
        if (PARITY_TYPE == 0) begin : g_sva_ev
            always_comb begin
                assert (parity_o == ^data_i) else
                    $error("parity_gen_check INV-001 even violation: got=%b", parity_o);
            end
        end else begin : g_sva_od
            always_comb begin
                assert (parity_o == ~^data_i) else
                    $error("parity_gen_check INV-001 odd violation: got=%b", parity_o);
            end
        end
    endgenerate

endmodule

// ============================================================================
// parity_impl_tree — 显式平衡 XOR 折半树（generate，O(log W) 深度）
// 生成方式决策：显式书写以实证"显式树 vs reduction XOR vs 线性链"综合差异
// ============================================================================
module parity_impl_tree #(
    parameter int DATA_WIDTH = 64
) (
    input  logic [DATA_WIDTH-1:0] data_i,
    output logic                  parity_i
);
    localparam int W = DATA_WIDTH;
    localparam int LEVELS = $clog2(W) + 1;

    logic [W-1:0] nodes [LEVELS];

    assign nodes[0] = data_i;
    for (genvar k = 1; k < LEVELS; k++) begin : g_fold
        localparam int NK   = (W + (1 << k) - 1) >> k;
        localparam int NPRE = (W + (1 << (k-1)) - 1) >> (k-1);
        for (genvar j = 0; j < NK; j++) begin : g_pair
            if (2*j + 1 < NPRE) begin : g_xor
                assign nodes[k][j] = nodes[k-1][2*j] ^ nodes[k-1][2*j+1];
            end else begin : g_pass
                assign nodes[k][j] = nodes[k-1][2*j];
            end
        end
    end
    assign parity_i = nodes[LEVELS-1][0];
endmodule

// ============================================================================
// parity_impl_reduction — 一行 reduction XOR（综合器自动生成最优平衡树）
// ============================================================================
module parity_impl_reduction #(
    parameter int DATA_WIDTH = 64
) (
    input  logic [DATA_WIDTH-1:0] data_i,
    output logic                  parity_i
);
    assign parity_i = ^data_i;
endmodule

// ============================================================================
// parity_impl_linear — 线性 XOR 链（逐位累异或，O(W) 深度）
// ============================================================================
module parity_impl_linear #(
    parameter int DATA_WIDTH = 64
) (
    input  logic [DATA_WIDTH-1:0] data_i,
    output logic                  parity_i
);
    localparam int W = DATA_WIDTH;
    always_comb begin
        parity_i = data_i[0];
        for (int b = 1; b < W; b++) parity_i ^= data_i[b];
    end
endmodule
