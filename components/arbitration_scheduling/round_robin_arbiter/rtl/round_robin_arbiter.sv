// ============================================================================
// round_robin_arbiter — 轮转仲裁器 (A2, ARB-002)
// VLNV: aixsilicon:cbb:round_robin_arbiter:0.1.0
// ----------------------------------------------------------------------------
// PC_IMPL 微架构选择（轮转选择三形态，PPA 实证对比）：
//   0 = MASK         轮转掩码优先链（O(N) 深度，最小面积；经典 RR mask 法）
//   1 = ROTATE_PRIO  旋转索引 + LSB 优先编码（O(log N) 深度，fmax 优）
//   2 = POINTER      二进制指针 + 循环移位选择（O(log N) 深度，结构规整/N 大 LUT 友好）
// REQ_TYPE:  {0=level 纯组合，1=latched 锁存请求直至 grant_ack_i 应答}
// FAST_GRANT:{0=组合授权（零延迟），1=输出寄存授权（1 拍延迟，异步复位）}
// GRANT_ACK_EN:{0=每拍按当前请求重新决策（纯轮转），1=grant 锁定至 grant_ack_i 应答后轮转}
// 统一轮转语义（INV-002/ASM-005）：
//   从 rr_ptr（本轮起始索引）起回绕扫描请求向量中首个置位；授权后 rr_ptr 更新为
//   (grant_index+1) % N。单请求一直有效 → 重复授权同一位（不饿死其它请求）。
// X 输入不作承诺（ASM-001）。
// ============================================================================

module round_robin_arbiter #(
    parameter int NUM_REQ      = 8,
    parameter int REQ_TYPE     = 0,          // {0=level, 1=latched}
    parameter int FAST_GRANT   = 0,          // {0=组合授权, 1=寄存授权}
    parameter int PC_IMPL      = 0,          // {0=mask,1=rotate+priority,2=pointer}
    parameter int GRANT_ACK_EN = 0           // {0=每拍决策, 1=ack 锁定}
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [NUM_REQ-1:0]   req_i,
    input  logic                 grant_ack_i,   // REQ_TYPE=1 或 GRANT_ACK_EN=1 应答（授权消费确认）
    output logic [NUM_REQ-1:0]   grant_o
);
    localparam int N = NUM_REQ;
    localparam int PTR_W = (N > 1) ? $clog2(N) : 1;

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..006）----
    generate
        if (N < 2 || N > 64) begin : g_param_w
            $error("round_robin_arbiter PC-001/002 violation: NUM_REQ=%0d outside [2..64]", N);
        end
        if (REQ_TYPE < 0 || REQ_TYPE > 1) begin : g_param_rt
            $error("round_robin_arbiter illegal REQ_TYPE=%0d not in {0,1}", REQ_TYPE);
        end
        if (FAST_GRANT < 0 || FAST_GRANT > 1) begin : g_param_fg
            $error("round_robin_arbiter illegal FAST_GRANT=%0d not in {0,1}", FAST_GRANT);
        end
        if (PC_IMPL < 0 || PC_IMPL > 2) begin : g_param_impl
            $error("round_robin_arbiter illegal PC_IMPL=%0d not in {0,1,2}", PC_IMPL);
        end
        if (GRANT_ACK_EN < 0 || GRANT_ACK_EN > 1) begin : g_param_ack
            $error("round_robin_arbiter illegal GRANT_ACK_EN=%0d not in {0,1}", GRANT_ACK_EN);
        end
    endgenerate

    // ---- 请求源（原始索引空间）：level 直通 / latched 用锁存寄存器 ----
    logic [N-1:0] req_src;
    logic [N-1:0] req_hold;
    logic [N-1:0] grant_combo;        // 核心组合授权（基于当前 rr_ptr 与 req_src）
    logic [N-1:0] grant_mid;          // 最终授权（GRANT_ACK_EN=1 时可能被锁定）
    logic [PTR_W-1:0] grant_idx;      // 核心输出：本轮被授权索引（供 rr_ptr/锁定更新）
    logic         core_hit;           // 核心输出：本轮是否有请求被授权

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

    // ---- 轮转指针状态（rr_ptr：本轮起始索引；复位 0，授权后 (grant_idx+1) % N）----
    // GRANT_ACK_EN=0：rr_ptr 每拍在 core_hit 时推进（纯轮转）
    // GRANT_ACK_EN=1：rr_ptr 仅在 ack 应答被消费授权后推进（锁定期间不变）
    logic [PTR_W-1:0] rr_ptr;
    logic [PTR_W-1:0] grant_idx_q;    // 保持中的授权索引（GRANT_ACK_EN=1，ack 应答用于推进）
    logic            grant_held;      // GRANT_ACK_EN=1：授权是否处于锁定状态
    // GRANT_ACK_EN=1 的锁定授权寄存器：ack 未应答期间保持当前授权位不变
    // （即使请求向量变化，授权也保持到 ack 应答，INV-006）
    logic [N-1:0] grant_combo_locked;

    // ---- rr_ptr 状态更新（GRANT_ACK_EN 分支：ack 锁定 / 纯轮转）----
    generate
        if (GRANT_ACK_EN == 1) begin : g_ptr_ack
            // ack 锁定：rr_ptr 仅在 ack 应答被消费授权后推进；锁定期间不变
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    rr_ptr <= '0;
                else if (grant_ack_i && grant_held)
                    rr_ptr <= (grant_idx_q + 1) % N;   // 应答：推进到被消费授权索引+1
                // 锁定/空闲未应答：保持
            end
        end else begin : g_ptr_free
            // 纯轮转：rr_ptr 每拍在 core_hit 时推进到 (grant_idx+1)%N；无请求保持
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    rr_ptr <= '0;
                else if (core_hit)
                    rr_ptr <= (grant_idx + 1) % N;
            end
        end
    endgenerate

    // ---- ack 锁定引擎（GRANT_ACK_EN=1）：捕获/保持授权与索引，输出授权 MUX ----
    generate
        if (GRANT_ACK_EN == 1) begin : g_ack_engine
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    grant_idx_q  <= '0;
                    grant_held   <= 1'b0;
                end else if (grant_ack_i && grant_held) begin
                    // 应答：解除锁定，下拍按新 ptr 重选
                    grant_held   <= 1'b0;
                end else if (!grant_held) begin
                    // 空闲：跟随组合选择，捕获新授权与索引
                    grant_idx_q  <= grant_idx;
                    grant_held   <= core_hit;
                end
                // grant_held=1 且未应答：保持（不更新任何状态）
            end
            // 输出授权：锁定时保持 grant_mid（用锁定授权旁路）；空闲时跟随组合
            assign grant_mid = grant_held ? grant_combo_locked : grant_combo;
            // 注意：锁定时 core 仍基于 rr_ptr/req_src 组合计算；为避免锁定期间组合授权漂移，
            // 用额外寄存器保持锁定授权（见 grant_combo_locked）
        end else begin : g_free_engine
            assign grant_mid = grant_combo;
        end
    endgenerate

    generate
        if (GRANT_ACK_EN == 1) begin : g_holdreg
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    grant_combo_locked <= '0;
                else if (!grant_held)
                    grant_combo_locked <= grant_combo;   // 空闲捕获
                // 锁定：保持
            end
        end
    endgenerate

    // ---- 核心分派（多实现：轮转选择三形态；均组合，从 rr_ptr 起回绕扫描）----
    generate
        if (PC_IMPL == 0) begin : g_mask
            rra_impl_mask         #(.NUM_REQ(N)) u_core (.req_i(req_src), .rr_ptr(rr_ptr),
                                                       .grant_o(grant_combo), .grant_idx(grant_idx), .hit(core_hit));
        end else if (PC_IMPL == 1) begin : g_rot
            rra_impl_rotate_prio  #(.NUM_REQ(N)) u_core (.req_i(req_src), .rr_ptr(rr_ptr),
                                                       .grant_o(grant_combo), .grant_idx(grant_idx), .hit(core_hit));
        end else begin : g_ptr
            rra_impl_pointer      #(.NUM_REQ(N)) u_core (.req_i(req_src), .rr_ptr(rr_ptr),
                                                       .grant_o(grant_combo), .grant_idx(grant_idx), .hit(core_hit));
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
    // INV-001 授权互斥：至多一个授权（对所有模式适用，含 ack 锁定）
    assert property (@(posedge clk) $countones(grant_mid) <= 1);
    // INV-003 活性 + INV-002 授权子集：仅对非锁定模式适用
    //   （GRANT_ACK_EN=1 锁定期间授权保持到 ack 应答，请求可能已撤——INV-006 定义语义）
    generate
        if (GRANT_ACK_EN == 0) begin : g_sva_live
            assert property (@(posedge clk) (|req_src) |-> ($countones(grant_mid) == 1));
            assert property (@(posedge clk) (~|req_src) |-> (~|grant_mid));
            assert property (@(posedge clk) (grant_mid & req_src) == grant_mid);
        end
    endgenerate

    generate
        // INV-004 latched：无 ack 应答时锁存请求不减少（授权保持）
        if (REQ_TYPE == 1) begin : g_sva_latch
            assert property (@(posedge clk) disable iff(!rst_n)
                (!grant_ack_i) |-> (req_hold >= $past(req_hold)));
        end
        // INV-005 registered：寄存授权 == 组合授权打拍（1 拍延迟）
        if (REQ_TYPE == 0 && GRANT_ACK_EN == 0 && FAST_GRANT == 1) begin : g_sva_reg
            assert property (@(posedge clk) disable iff(!rst_n)
                grant_o == $past(grant_mid));
        end
        // INV-006 ack 锁定：GRANT_ACK_EN=1 且未应答时锁定授权保持、rr_ptr 不变
        if (GRANT_ACK_EN == 1) begin : g_sva_ack
            assert property (@(posedge clk) disable iff(!rst_n)
                (grant_held && !grant_ack_i) |-> (grant_mid == $past(grant_mid)));
            assert property (@(posedge clk) disable iff(!rst_n)
                (!grant_ack_i) |-> (rr_ptr == $past(rr_ptr)));
        end
    endgenerate

endmodule

// ============================================================================
// rra_impl_mask — 轮转掩码优先链（O(N) 深度，最小面积；经典 RR mask 法）
//   upper = req & ~((1<<ptr)-1)   （ptr 及以上位）
//   lower = req &  ((1<<ptr)-1)   （ptr 以下位）
//   grant = (|upper) ? first_set(upper) : first_set(lower)
//   （从 ptr 起回绕扫描首个置位）
// ============================================================================
module rra_impl_mask #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0]       req_i,
    input  logic [$clog2(NUM_REQ)-1:0] rr_ptr,
    output logic [NUM_REQ-1:0]       grant_o,
    output logic [$clog2(NUM_REQ)-1:0] grant_idx,
    output logic                    hit
);
    localparam int N = NUM_REQ;
    logic [N-1:0] mask_ge;            // mask_ge[i] = (i >= rr_ptr)
    logic [N-1:0] upper, lower;
    logic [N-1:0] g_upper, g_lower;

    // 掩码生成：mask_ge[i] = (i >= rr_ptr)（N 位比较）
    for (genvar i = 0; i < N; i++) begin : g_mask
        assign mask_ge[i] = (i >= rr_ptr);
    end
    assign upper = req_i & mask_ge;
    assign lower = req_i & ~mask_ge;

    // 两段 LSB 优先链（first_set：优先级编码，O(N) 深）
    rra_first_set #(.NUM_REQ(N)) u_up (.v(upper), .onehot(g_upper));
    rra_first_set #(.NUM_REQ(N)) u_lo (.v(lower), .onehot(g_lower));

    // 选择：高段有请求 → 高段首个；否则低段首个（回绕）
    assign grant_o = (|upper) ? g_upper : g_lower;
    assign hit     = |req_i;

    // 授权索引编码（LSB 优先首个置位的索引）
    rra_idx_encode #(.NUM_REQ(N)) u_idx (.req_i(grant_o), .idx(grant_idx));
endmodule

// ============================================================================
// rra_impl_rotate_prio — 旋转索引 + LSB 优先编码（O(log N) 深度）
//   rotated[i] = req[(ptr + i) % N]      （按 rr_ptr 旋转，ptr 位落到新 LSB）
//   grant_rot  = first_set(rotated)      （LSB 优先，O(log N) 并行前缀）
//   grant[(ptr+j)%N] = grant_rot[j]      （逆旋转回原始索引空间）
// ============================================================================
module rra_impl_rotate_prio #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0]       req_i,
    input  logic [$clog2(NUM_REQ)-1:0] rr_ptr,
    output logic [NUM_REQ-1:0]       grant_o,
    output logic [$clog2(NUM_REQ)-1:0] grant_idx,
    output logic                    hit
);
    localparam int N = NUM_REQ;
    logic [N-1:0] rotated, grant_rot;

    // 旋转：rotated[i] = req[(ptr + i) % N]（N 路 N:1 MUX，桶形移位 O(log N) 深）
    for (genvar i = 0; i < N; i++) begin : g_rot
        assign rotated[i] = req_i[(rr_ptr + i) % N];
    end

    // LSB 优先编码（O(log N) 并行前缀）
    rra_first_set #(.NUM_REQ(N)) u_fs (.v(rotated), .onehot(grant_rot));

    // 逆旋转：grant[(ptr+j)%N] = grant_rot[j]（动态索引 LHS 需 always_comb 内赋值）
    always_comb begin
        grant_o = '0;
        for (int j = 0; j < N; j++)
            grant_o[(rr_ptr + j) % N] = grant_rot[j];
    end

    assign hit = |req_i;
    rra_idx_encode #(.NUM_REQ(N)) u_idx (.req_i(grant_o), .idx(grant_idx));
endmodule

// ============================================================================
// rra_impl_pointer — 二进制指针 + 循环移位选择（O(log N) 深度，折中）
//   与 rotate_prio 相同旋转语义，但显式物化"循环移位 → 选择"两阶段，
//   逻辑组织更规整（shift→select），综合器可独立优化。
// ============================================================================
module rra_impl_pointer #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0]       req_i,
    input  logic [$clog2(NUM_REQ)-1:0] rr_ptr,
    output logic [NUM_REQ-1:0]       grant_o,
    output logic [$clog2(NUM_REQ)-1:0] grant_idx,
    output logic                    hit
);
    localparam int N = NUM_REQ;
    localparam int PW = $clog2(N);
    logic [N-1:0] shifted, sel_onehot;

    // 循环右移 rr_ptr 位（barrel，O(log N) 深）；移位后 LSB 为 req[rr_ptr]
    assign shifted = (req_i >> rr_ptr) | (req_i << ((N - rr_ptr) % N));

    // 选择：从 LSB 起首个置位（即 shifted 的 LSB 优先编码）
    rra_first_set #(.NUM_REQ(N)) u_fs (.v(shifted), .onehot(sel_onehot));

    // 逆旋转回原始索引空间：grant[(ptr+j)%N] = sel_onehot[j]（动态索引 LHS 需 always_comb）
    always_comb begin
        grant_o = '0;
        for (int j = 0; j < N; j++)
            grant_o[(rr_ptr + j) % N] = sel_onehot[j];
    end

    assign hit = |req_i;
    rra_idx_encode #(.NUM_REQ(N)) u_idx (.req_i(grant_o), .idx(grant_idx));
endmodule

// ============================================================================
// rra_first_set — LSB 优先编码（first_set：返回 v 中首个置位的一位热码）
//   onehot[i] = v[i] & ~|v[i-1:0]；onehot[0] = v[0]
//   逻辑深度 O(N)（线性链）；综合器自动平衡（DC 可重组为前缀树）。
// ============================================================================
module rra_first_set #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0] v,
    output logic [NUM_REQ-1:0] onehot
);
    localparam int N = NUM_REQ;
    logic [N-1:0] hi;                 // hi[i] = |v[i-1:0]（更高优先级段，i=0 为 0）
    assign hi[0] = 1'b0;
    for (genvar i = 1; i < N; i++) begin : g_hi
        assign hi[i] = |v[i-1:0];
    end
    for (genvar i = 0; i < N; i++) begin : g_gr
        assign onehot[i] = v[i] & ~hi[i];
    end
endmodule

// ============================================================================
// rra_idx_encode — 一位热码 → 二进制索引（priority encoder）
//   输入一位热（至多 1 位有效），输出该位索引（log2(N) 位）。
// ============================================================================
module rra_idx_encode #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0]       req_i,
    output logic [$clog2(NUM_REQ)-1:0] idx
);
    localparam int N = NUM_REQ;
    localparam int PW = $clog2(N);
    logic [PW-1:0] idx_int;
    always_comb begin
        idx_int = '0;
        for (int i = 0; i < N; i++) begin
            if (req_i[i])
                idx_int = PW'(i);
        end
    end
    assign idx = idx_int;
endmodule
