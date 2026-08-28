// ============================================================================
// parity_gen_check — 纯组合奇偶校验原子构件 (A1, COD-001)
// VLNV: aixsilicon:cbb:parity_gen_check:0.1.0
// ----------------------------------------------------------------------------
// PC_IMPL 微架构选择（XOR 归约树结构 trade-off）：
//   0 = TREE    平衡 XOR 归约树（默认，O(log W) 深度）
//   1 = LINEAR  线性 XOR 链（面积略小、深度 O(W)）
// PARITY_TYPE: even|odd（even: parity_o=^data_i；odd: parity_o=~^data_i）
// 函数: parity_o = ^data_i（even）/ ~^data_i（odd）；X 输入不作承诺（ASM-001）。
// ============================================================================

module parity_gen_check #(
    parameter int DATA_WIDTH  = 64,
    // PARITY_TYPE: {0=even, 1=odd}（int 枚举——DC 综合不支持 string 参数，VER-700 教训）
    parameter int PARITY_TYPE = 0,
    parameter int PC_IMPL     = 0          // {0=TREE,1=LINEAR}
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
        if (PC_IMPL < 0 || PC_IMPL > 1) begin : g_param_impl
            $error("parity_gen_check illegal PC_IMPL=%0d not in {0,1}", PC_IMPL);
        end
    endgenerate

    // ---- 分派（多实现：XOR 归约树结构）----
    generate
        if (PC_IMPL == 0) begin : g_tree
            parity_impl_tree #(.DATA_WIDTH(W)) u_impl (.data_i(data_i), .parity_i(xor_i));
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
// parity_impl_tree — 平衡 XOR 归约树（SV 一行 reduction XOR）
// 综合工具（DC/Genus）对 `^` 归约自动生成最优平衡 XOR 树——这是 G6 实测 tree/linear
// 综合收敛的本质（RTL 写法不影响综合最优解）。生成方式决策：SV（Python 与 SV 均可
// 时倾向 SV；规整归约用一元运算符由综合器自动优化）。
// ============================================================================
module parity_impl_tree #(
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
