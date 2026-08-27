// ============================================================================
// popcount — 纯组合 Hamming 权重计数原子构件 (A1, SEL-014)
// VLNV: aixsilicon:cbb:popcount:0.1.0
// ----------------------------------------------------------------------------
// 极简单文件默认规范（artifact-contract §2）：pkg+module 同居单一文件，
// 参数上限用 localparam、参数检查用 generate 块内 $error（elaboration 期拦截）。
//
// 本文件为**契约顶层**：
//   * 公共端口 / 全精度输出位宽 CNT_W = $clog2(INPUT_WIDTH+1)
//   * elaboration 期参数检查（PC-001/PC-002 → REQ-004/tc_negative_elab）
//   * 就近 SVA（PROP-PC_FUNC-001 / PROP-PC_BOUND-002；INV-001/002）
//   * 按参数 PC_IMPL 编译期选择实现（design.md §1 冻结稿三实现）
//     注意：PC_IMPL 属微架构参数（domain-rules §2.3），不进公共功能参数表；
//     合法值对应 profiles.yaml 的 implementation 字段。
//
// 函数定义: cnt_o = Σ_{b=0}^{INPUT_WIDTH-1} data_i[b]
// X 语义  : 输入含 X 时输出不作承诺（ASM-001）；SVA 仅对 2-state 采样有效。
// ============================================================================

module popcount #(
    // ---- 功能参数（公共契约）----
    parameter int INPUT_WIDTH = 64,          // 输入向量位宽 [4..256]（PC-001）
    parameter int CHUNK_W     = 8,           // lookup 分段位宽 [4..8]（PC-002，仅 impl_lookup）
    // ---- 派生端口宽度参数（端口声明前解析；一致性由 g_cntw 卫兵校验）----
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1),   // 数值域 [0, W]，全精度无截断
    // ---- 微架构选择（profile 挂接点）----
    parameter int PC_IMPL     = 0            // 0=impl_tree(默认) 1=impl_column_compress 2=impl_lookup
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);

    // ---- 局部常量（防零宽/负宽：W>=4 保证 CNT_W>=3，无需 DEPTH=1 式保护，
    //      但仍按 domain-rules §3.1.1 显式 localparam 表达）----
    localparam int W = INPUT_WIDTH;

    // ------------------------------------------------------------------
    // 参数检查（elaboration 期拦截 —— generate 块内 $error，REQ-004）
    // ------------------------------------------------------------------
    generate
        if (INPUT_WIDTH < 4 || INPUT_WIDTH > 256) begin : g_param_w
            $error("popcount PC-001 violation: INPUT_WIDTH=%0d outside legal [4..256]",
                   INPUT_WIDTH);
        end
        if (CHUNK_W < 4 || CHUNK_W > 8) begin : g_param_cw
            $error("popcount PC-002 violation: CHUNK_W=%0d outside legal [4..8]", CHUNK_W);
        end
        if (CNT_W != $clog2(INPUT_WIDTH + 1)) begin : g_cntw
            $error("popcount CNT_W=%0d inconsistent with INPUT_WIDTH=%0d", CNT_W, INPUT_WIDTH);
        end
        if (PC_IMPL < 0 || PC_IMPL > 2) begin : g_param_impl
            $error("popcount illegal microarchitecture select: PC_IMPL=%0d not in {0,1,2}",
                   PC_IMPL);
        end
    endgenerate

    // ------------------------------------------------------------------
    // 实现分派（编译期 generate choice；子模块极简单文件同居于各自 impl 目录）
    // ------------------------------------------------------------------
    // Change C1 (2026-08-27): impl_lookup 经 DC 折叠为 tree 同构被移除；
    // PC_IMPL=2 改挂 impl_dadda（Dadda 调度列压缩）。
    generate
        case (PC_IMPL)
            0: popcount_impl_tree #(.INPUT_WIDTH(W)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
            1: popcount_impl_colcmp #(.INPUT_WIDTH(W)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
            2: popcount_impl_dadda #(.INPUT_WIDTH(W)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
            default: popcount_impl_tree #(.INPUT_WIDTH(W)) u_impl (.data_i(data_i), .cnt_o(cnt_o));
        endcase
    endgenerate

    // ------------------------------------------------------------------
    // 就近 SVA（并发断言即时钟化进程包裹纯组合构件的检查视角；
    // 无时钟构件的 SVA 以 free property 形式在仿真 TB 内采样执行，
    // 此处提供 golden 形式化表达供 formal LEC 与仿真复用同一语义锚点）
    // ------------------------------------------------------------------
`ifdef POPCOUNT_SVA_ON
    always_comb begin : sva_sample
        // INV-001 函数一致性 / PROP-PC_FUNC-001
        assert_cnt_functional : assert final (cnt_o == popcount_golden(data_i))
            else $error("PROP-PC_FUNC-001 violated: cnt_o=%0d golden=%0d",
                        cnt_o, popcount_golden(data_i));
        // INV-002 值域封闭 / PROP-PC_BOUND-002
        assert_cnt_range : assert final ((cnt_o >= 0) && (cnt_o <= W))
            else $error("PROP-PC_BOUND-002 violated: cnt_o=%0d out of [0,%0d]", cnt_o, W);
        if (data_i === '0)
            assert_cnt_all0 : assert final (cnt_o == 0)
                else $error("PROP-PC_BOUND-002 all-zero anchor failed");
        if (data_i === '1)
            assert_cnt_all1 : assert final (cnt_o == W[CNT_W-1:0])
                else $error("PROP-PC_BOUND-002 all-one anchor failed");
    end

    // 黄金参考模型（独立 for-loop 数位，不复用综合路径，保障 checker 同源独立性）
    function automatic logic [CNT_W-1:0] popcount_golden(input logic [W-1:0] v);
        logic [CNT_W-1:0] acc;
        acc = '0;
        for (int b = 0; b < W; b++) acc = acc + CNT_W'(v[b]);
        return acc;
    endfunction
`endif

endmodule
