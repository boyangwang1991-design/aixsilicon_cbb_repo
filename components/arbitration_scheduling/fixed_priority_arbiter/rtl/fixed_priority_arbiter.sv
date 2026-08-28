// ============================================================================
// fixed_priority_arbiter — 固定优先级仲裁器 (A2, ARB-001)
// VLNV: aixsilicon:cbb:fixed_priority_arbiter:0.1.0
// ----------------------------------------------------------------------------
// PC_IMPL 微架构选择（优先级链三形态，PPA 实证对比）：
//   0 = LINEAR  显式线性优先级链（O(N) 深度，最小面积）
//   1 = TREE    折半并行前缀网络（O(log N) 深度，时序优）
//   2 = GROUPED 分组树 + 组内链（GS=4，面积/时序折中）
// PRIORITY:  {0=LSB 优先（req[0] 最高），1=MSB 优先（req[N-1] 最高）}
// REQ_TYPE:  {0=level 纯组合，1=latched 锁存请求直至 grant_ack_i 应答}
// FAST_GRANT:{0=组合授权（零延迟），1=输出寄存授权（1 拍延迟，异步复位）}
// 函数（核心统一 LSB 优先归一化）：
//   grant_core[i] = req_core[i] & ~|req_core[i-1:0]   （i>0）
//   grant_core[0] = req_core[0]
// X 输入不作承诺（ASM-001）。
// ============================================================================

module fixed_priority_arbiter #(
    parameter int NUM_REQ    = 8,
    parameter int PRIORITY   = 0,          // {0=LSB优先, 1=MSB优先}
    parameter int REQ_TYPE   = 0,          // {0=level, 1=latched}
    parameter int FAST_GRANT = 0,          // {0=组合授权, 1=寄存授权}
    parameter int PC_IMPL    = 0           // {0=linear,1=tree,2=grouped}
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [NUM_REQ-1:0]   req_i,
    input  logic                 grant_ack_i,   // REQ_TYPE=1 应答（授权消费确认）
    output logic [NUM_REQ-1:0]   grant_o
);
    localparam int N = NUM_REQ;

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..006）----
    generate
        if (N < 2 || N > 64) begin : g_param_w
            $error("fixed_priority_arbiter PC-001/002 violation: NUM_REQ=%0d outside [2..64]", N);
        end
        if (PRIORITY < 0 || PRIORITY > 1) begin : g_param_p
            $error("fixed_priority_arbiter illegal PRIORITY=%0d not in {0,1}", PRIORITY);
        end
        if (REQ_TYPE < 0 || REQ_TYPE > 1) begin : g_param_rt
            $error("fixed_priority_arbiter illegal REQ_TYPE=%0d not in {0,1}", REQ_TYPE);
        end
        if (FAST_GRANT < 0 || FAST_GRANT > 1) begin : g_param_fg
            $error("fixed_priority_arbiter illegal FAST_GRANT=%0d not in {0,1}", FAST_GRANT);
        end
        if (PC_IMPL < 0 || PC_IMPL > 2) begin : g_param_impl
            $error("fixed_priority_arbiter illegal PC_IMPL=%0d not in {0,1,2}", PC_IMPL);
        end
    endgenerate

    // ---- 请求源（原始索引空间）：level 直通 / latched 用锁存寄存器 ----
    logic [N-1:0] req_src;
    logic [N-1:0] req_hold;
    logic [N-1:0] grant_mid;          // 原始空间组合授权（FAST_GRANT 前）

    assign req_src = (REQ_TYPE == 1) ? req_hold : req_i;

    generate
        if (REQ_TYPE == 1) begin : g_latch
            // 捕获新请求；ack 应答后清除被授权请求（INV-004）
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    req_hold <= '0;
                else
                    req_hold <= (req_hold | req_i) & ~(grant_ack_i ? grant_mid : '0);
            end
        end
    endgenerate

    // ---- 优先级归一化：核心统一 LSB 优先（索引 0 最高）----
    logic [N-1:0] req_core;
    logic [N-1:0] grant_core;

    generate
        if (PRIORITY == 0) begin : g_norm0
            assign req_core  = req_src;
            assign grant_mid = grant_core;
        end else begin : g_norm1
            for (genvar i = 0; i < N; i++) begin : g_rev
                assign req_core[i]  = req_src[N-1-i];
                assign grant_mid[i] = grant_core[N-1-i];
            end
        end
    endgenerate

    // ---- 核心分派（多实现：优先级链三形态）----
    generate
        if (PC_IMPL == 0) begin : g_lin
            fpa_impl_linear #(.NUM_REQ(N)) u_core (.req_i(req_core), .grant_o(grant_core));
        end else if (PC_IMPL == 1) begin : g_tree
            fpa_impl_tree   #(.NUM_REQ(N)) u_core (.req_i(req_core), .grant_o(grant_core));
        end else begin : g_grp
            fpa_impl_grouped#(.NUM_REQ(N)) u_core (.req_i(req_core), .grant_o(grant_core));
        end
    endgenerate

    // ---- 输出：组合授权 / 寄存授权（FAST_GRANT）----
    generate
        if (FAST_GRANT == 1) begin : g_regout
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    grant_o <= '0;
                else
                    grant_o <= grant_mid;
            end
        end else begin : g_comboout
            assign grant_o = grant_mid;
        end
    endgenerate

    // ---- 就近 SVA（关键不变量；@(posedge clk) 并发断言，综合忽略）----
    // 注：$countones()（popcount 系统函数）仅用于验证期断言——返回向量中 1 的个数，
    // 综合工具（DC/SpyGlass）对 assert 内表达式一律忽略，不产生硬件（SYNTH_5064 waiver）。
    // 若需硬件 popcount（如 QoS 统计），另用 arithmetic_datapath 的 adder_tree/multiway 构件，
    // 不在本仲裁器内物化（A2 原子职责）。
    // 采用 @(posedge clk) 并发断言而非 always_comb immediate assert / @(*) 并发属性：
    // ① tree/grouped 内部多级组合在输入变化后存在 delta 传播，immediate assert 捕获中间态
    //    （fpa_tb 实测 linear 无中间态、tree/grouped 逻辑层深误报）；
    // ② VCS 不支持 '@(*)' 序列/属性时钟（NYI）；
    // ③ 时钟沿采样组合信号已稳定（TB 驱动在 negedge 间 #1 更新，避开时钟沿）。
    // INV-001 授权互斥：至多一个授权
    assert property (@(posedge clk) $countones(grant_core) <= 1);
    // INV-003 活性：有请求必有且仅有一个授权；无请求全零
    assert property (@(posedge clk) (|req_core) |-> ($countones(grant_core) == 1));
    assert property (@(posedge clk) (~|req_core) |-> (~|grant_core));
    // INV-002 优先级语义：授权是请求子集
    assert property (@(posedge clk) (grant_core & req_core) == grant_core);

    generate
        // INV-002 优先级语义：更高优先级段无请求时才可授权该位
        for (genvar i = 1; i < N; i++) begin : g_sva_prio
            assert property (@(posedge clk) grant_core[i] |-> (~|req_core[i-1:0]));
        end
        // INV-004 latched：无 ack 应答时锁存请求不减少（授权保持）
        if (REQ_TYPE == 1) begin : g_sva_latch
            assert property (@(posedge clk) disable iff(!rst_n)
                (!grant_ack_i) |-> (req_hold >= $past(req_hold)));
        end
        // INV-005 registered：寄存授权 == 组合授权打拍（1 拍延迟）
        if (REQ_TYPE == 0 && FAST_GRANT == 1) begin : g_sva_reg
            assert property (@(posedge clk) disable iff(!rst_n)
                grant_o == $past(grant_mid));
        end
    endgenerate

endmodule

// ============================================================================
// fpa_impl_linear — 显式线性优先级链（O(N) 深度，最小面积）
//   grant[i] = req[i] & ~|req[i-1:0]；grant[0] = req[0]
// ============================================================================
module fpa_impl_linear #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0] req_i,
    output logic [NUM_REQ-1:0] grant_o
);
    localparam int N = NUM_REQ;
    logic [N-1:0] hi_req;                 // hi_req[i] = |req_i[i-1:0]（更高优先级段）
    assign hi_req[0] = 1'b0;
    for (genvar i = 1; i < N; i++) begin : g_hi
        assign hi_req[i] = |req_i[i-1:0];
    end
    for (genvar i = 0; i < N; i++) begin : g_gr
        assign grant_o[i] = req_i[i] & ~hi_req[i];
    end
endmodule

// ============================================================================
// fpa_impl_tree — 折半并行前缀网络（Kogge-Stone 式，O(log N) 深度）
//   pref[d+1][i] = pref[d][i] | pref[d][i-2^d]（折半前缀）；pref[LOGN][i]=|req_i[i:0]
// ============================================================================
module fpa_impl_tree #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0] req_i,
    output logic [NUM_REQ-1:0] grant_o
);
    localparam int N    = NUM_REQ;
    localparam int LOGN = (N > 1) ? $clog2(N) : 1;
    logic [N-1:0] pref [LOGN+1];          // pref[0]=req_i，逐级折半前缀

    assign pref[0] = req_i;
    for (genvar d = 0; d < LOGN; d++) begin : g_lev
        for (genvar i = 0; i < N; i++) begin : g_bit
            if (i >= (1 << d))
                assign pref[d+1][i] = pref[d][i] | pref[d][i-(1<<d)];
            else
                assign pref[d+1][i] = pref[d][i];
        end
    end
    for (genvar i = 0; i < N; i++) begin : g_gr
        if (i == 0)
            assign grant_o[0] = req_i[0];
        else
            assign grant_o[i] = req_i[i] & ~pref[LOGN][i-1];
    end
endmodule

// ============================================================================
// fpa_impl_grouped — 分组树 + 组内链（GS=4，面积/时序折中）
//   组内线性链（GS 深）并行 + 组间前缀链（G 深）；深度 ≈ GS + G
// ============================================================================
module fpa_impl_grouped #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0] req_i,
    output logic [NUM_REQ-1:0] grant_o
);
    localparam int N  = NUM_REQ;
    localparam int GS = 4;
    localparam int G  = (N + GS - 1) / GS;

    logic [G-1:0]            grp_any;     // 组有效（组内是否有请求）
    logic [G-1:0]            grp_hi;      // grp_hi[g] = |grp_any[g-1:0]
    logic [G-1:0]            grp_sel;     // 选中组 one-hot
    logic [G*GS-1:0]         grp_grant;   // 组内线性链授权（扁平）

    generate
        for (genvar g = 0; g < G; g++) begin : g_grp
            localparam int LO = g * GS;
            // 组内线性链（扁平）+ 组有效（逐位 OR，避免非法位选）
            logic [GS-1:0] any_bits;
            for (genvar j = 0; j < GS; j++) begin : g_bit
                if (LO + j < N) begin
                    if (j == 0)
                        assign grp_grant[g*GS+j] = req_i[LO];
                    else
                        assign grp_grant[g*GS+j] = req_i[LO+j] & ~|req_i[LO+j-1 -: j];
                    assign any_bits[j] = req_i[LO+j];
                end else begin
                    assign grp_grant[g*GS+j] = 1'b0;
                    assign any_bits[j] = 1'b0;
                end
            end
            assign grp_any[g] = |any_bits;
        end
        // 组间前缀链（组数少，深度 G）
        assign grp_hi[0] = 1'b0;
        for (genvar g = 1; g < G; g++) begin : g_gh
            assign grp_hi[g] = |grp_any[g-1:0];
        end
        for (genvar g = 0; g < G; g++) begin : g_sel
            assign grp_sel[g] = grp_any[g] & ~grp_hi[g];
        end
        // 输出：选中组内授权 → 全局
        for (genvar g = 0; g < G; g++) begin : g_out
            for (genvar j = 0; j < GS; j++) begin : g_ob
                if (g*GS + j < N)
                    assign grant_o[g*GS+j] = grp_sel[g] & grp_grant[g*GS+j];
            end
        end
    endgenerate
endmodule
