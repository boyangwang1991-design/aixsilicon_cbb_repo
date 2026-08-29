// ============================================================================
// weighted_rr_arbiter — 带权轮转仲裁器 (A2, ARB-003)
// VLNV: aixsilicon:cbb:weighted_rr_arbiter:0.1.0
// ----------------------------------------------------------------------------
// WMODE 公平语义选择（功能参数）：
//   0 = QUOTA        每路独立配额计数器（每轮起点=权重）；从 rr_ptr 起在"有配额且有请求"
//                    路中 RR 扫描首个置位；授权后该路配额-1；全部资格路配额耗尽后整轮重置
//                    （窗口内授权次数 <= 权重，不超发、不饿死，INV-002）
//   1 = SMOOTH       统一 credit（复位=权重）；选择 credit 最大且有资格的路（argmax，平局
//                    RR 序）；被选路 credit -= 1；所有资格路 credit < N 时统一回补 += 权重
//                    （回补拍屏蔽授权，保证无负 credit；跨轮累计，比例趋近权重，INV-004）
// PC_IMPL 微架构选择（多实现，PPA 实证对比）：
//   0 = QUOTA_COUNTER  每路独立配额计数器 + RR 扫描（直观，面积小）
//   1 = DEFICIT_ROTATE 统一 credit 状态 + 旋转选择（平滑 WRR；WMODE=0 时退化为与 quota 等价）
// FAST_GRANT:{0=组合授权（零延迟），1=输出寄存授权（1 拍延迟，异步复位）}
// GRANT_ACK_EN:{0=每拍按当前请求重新决策（纯加权轮转），1=grant 锁定至 grant_ack_i 应答后轮转}
// 统一 RR 扫描语义（INV-002/ASM-005）：从 rr_ptr（本轮起始索引）起回绕扫描资格/请求向量
//   中首个置位；授权后 rr_ptr 更新为 (grant_index+1) % N。
// X 输入不作承诺（ASM-001）。
// ============================================================================

module weighted_rr_arbiter #(
    parameter int NUM_REQ        = 8,
    parameter int WEIGHT_WIDTH   = 4,          // 每路权重值位宽（权重上限 2^WW-1）
    parameter int WMODE          = 0,          // {0=quota, 1=smooth}
    parameter int FAST_GRANT     = 0,          // {0=组合授权, 1=寄存授权}
    parameter int GRANT_ACK_EN   = 0,          // {0=每拍决策, 1=ack 锁定}
    parameter int PC_IMPL        = 0           // {0=quota_counter, 1=deficit_rotate}
) (
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic [NUM_REQ-1:0]              req_i,
    input  logic [NUM_REQ*WEIGHT_WIDTH-1:0] weight_i,  // 每路权重（连续打包，[i*WW +: WW]）
    input  logic                            grant_ack_i,  // GRANT_ACK_EN=1 应答（授权消费确认）
    output logic [NUM_REQ-1:0]              grant_o
);
    localparam int N  = NUM_REQ;
    localparam int WW = WEIGHT_WIDTH;
    localparam int PTR_W = (N > 1) ? $clog2(N) : 1;
    // quota 计数位宽：max(权重) = 2^WW-1 → WW 位足够；窗口内配额只减不增（不溢出）
    // smooth credit 位宽：回补后上界 ≈ max(w)+N-1，扣 1 后仍 >=0 → WW + clog2(N+1) 位防溢出
    localparam int CW = WW + $clog2(N + 1);

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..008）----
    generate
        if (N < 2 || N > 64) begin : g_param_n
            $error("weighted_rr_arbiter PC-001/002 violation: NUM_REQ=%0d outside [2..64]", N);
        end
        if (WW < 2 || WW > 16) begin : g_param_ww
            $error("weighted_rr_arbiter PC-003/004 violation: WEIGHT_WIDTH=%0d outside [2..16]", WW);
        end
        if (WMODE < 0 || WMODE > 1) begin : g_param_wm
            $error("weighted_rr_arbiter illegal WMODE=%0d not in {0,1}", WMODE);
        end
        if (FAST_GRANT < 0 || FAST_GRANT > 1) begin : g_param_fg
            $error("weighted_rr_arbiter illegal FAST_GRANT=%0d not in {0,1}", FAST_GRANT);
        end
        if (GRANT_ACK_EN < 0 || GRANT_ACK_EN > 1) begin : g_param_ack
            $error("weighted_rr_arbiter illegal GRANT_ACK_EN=%0d not in {0,1}", GRANT_ACK_EN);
        end
        if (PC_IMPL < 0 || PC_IMPL > 1) begin : g_param_impl
            $error("weighted_rr_arbiter illegal PC_IMPL=%0d not in {0,1}", PC_IMPL);
        end
    endgenerate

    // ---- 权重解析与资格计算 ----
    logic [WW-1:0] w [N];            // 每路权重
    logic [N-1:0]  qual;             // qual[i] = req_i[i] & (w[i] != 0)（权重 0 无资格，INV-003）
    for (genvar i = 0; i < N; i++) begin : g_w
        assign w[i] = weight_i[i*WW +: WW];
    end
    for (genvar i = 0; i < N; i++) begin : g_qual
        assign qual[i] = req_i[i] & (w[i] != '0);
    end

    // ---- 状态数组（顶层声明；未用分支由 generate 默认驱动为 0，避免未驱动 X）----
    logic [WW-1:0] quota_cnt [N];    // WMODE=0：每路剩余配额（每轮起点=权重）
    logic [CW-1:0] credit     [N];   // WMODE=1：每路 credit（复位=权重）

    // ---- ack 锁定状态（顶层声明；GRANT_ACK_EN=0 时由 free 分支默认驱动）----
    logic [PTR_W-1:0] grant_idx_q;   // 保持中的授权索引（GRANT_ACK_EN=1）
    logic            grant_held;     // GRANT_ACK_EN=1：授权是否处于锁定状态
    logic [N-1:0]    grant_mid_locked; // GRANT_ACK_EN=1 锁定授权（ack 未应答期间保持）

    // ---- 轮转指针 / 核心授权信号 ----
    logic [PTR_W-1:0] rr_ptr;
    logic [N-1:0]    grant_combo;    // 核心组合授权（基于 rr_ptr + 资格）
    logic [PTR_W-1:0] grant_idx;     // 核心输出：本轮被授权索引
    logic            core_hit;       // 核心输出：本轮是否有请求被授权
    logic [N-1:0]    grant_mid;      // 最终授权（组合/锁定后）

    // ---- 组合选择核心输入 ----
    logic [N-1:0] elig_quota;        // WMODE=0：qual & (quota_cnt>0)
    logic [N-1:0] elig_smooth;       // WMODE=1：qual & (credit == max_credit)（argmax）
    logic [CW-1:0] max_c;            // smooth：资格路最大 credit
    logic [N-1:0]  is_max;           // smooth：资格路且 credit==max
    logic [N-1:0]  sel_vec;          // 实际参与 RR 扫描的向量
    logic          smooth_all_low;   // WMODE=1：所有资格路 credit < N（回补拍，屏蔽授权）

    // quota eligible（组合，基于当前 quota_cnt 状态）
    for (genvar i = 0; i < N; i++) begin : g_elq
        assign elig_quota[i] = qual[i] & (quota_cnt[i] != '0);
    end

    // smooth argmax（WMODE=1）；WMODE=0 时 elig_smooth 恒 0（不参与）
    generate
        if (WMODE == 1) begin : g_argmax
            always_comb begin
                max_c = '0;
                for (int i = 0; i < N; i++) begin
                    if (qual[i] && credit[i] > max_c)
                        max_c = credit[i];
                end
            end
            for (genvar i = 0; i < N; i++) begin : g_is_max
                assign is_max[i] = qual[i] & (credit[i] == max_c);
            end
            assign elig_smooth = is_max;
        end else begin : g_argmax_idle
            assign max_c       = '0;
            assign is_max      = '0;
            assign elig_smooth = '0;
        end
    endgenerate

    // ---- 回补判定（WMODE=1；回补拍屏蔽授权保证无负 credit）----
    generate
        if (WMODE == 1) begin : g_smooth_low
            logic [N-1:0] low_mask;      // 资格路且 credit < N
            for (genvar i = 0; i < N; i++) begin : g_low
                assign low_mask[i] = qual[i] & (credit[i] < CW'(N));
            end
            // all_low：存在资格且全部资格路 credit < N
            assign smooth_all_low = (|qual) && ((qual & ~low_mask) == '0);
        end else begin : g_smooth_low_idle
            assign smooth_all_low = 1'b0;
        end
    endgenerate

    // 选择向量：quota / smooth；smooth 在回补拍屏蔽授权（无负 credit）
    assign sel_vec = (WMODE == 0) ? elig_quota
                                 : (smooth_all_low ? '0 : elig_smooth);

    // ---- 核心分派（RR 扫描 sel_vec，从 rr_ptr 起回绕；旋转+LSB 优先编码 O(log N)）----
    w_rr_scan #(.NUM_REQ(N)) u_scan (
        .sel_i(sel_vec), .rr_ptr(rr_ptr),
        .grant_o(grant_combo), .grant_idx(grant_idx), .hit(core_hit)
    );

    // ---- rr_ptr 状态更新（GRANT_ACK_EN 分支：ack 锁定 / 纯轮转）----
    generate
        if (GRANT_ACK_EN == 1) begin : g_ptr_ack
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    rr_ptr <= '0;
                else if (grant_ack_i && grant_held)
                    rr_ptr <= (grant_idx_q + 1) % N;   // 应答：推进到被消费授权索引+1
                // 锁定/空闲未应答：保持
            end
        end else begin : g_ptr_free
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
                    grant_held   <= 1'b0;              // 应答：解除锁定
                end else if (!grant_held) begin
                    grant_idx_q  <= grant_idx;         // 空闲：捕获新授权索引
                    grant_held   <= core_hit;
                end
            end
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    grant_mid_locked <= '0;
                else if (!grant_held)
                    grant_mid_locked <= grant_combo;   // 空闲捕获锁定授权
            end
            assign grant_mid = grant_held ? grant_mid_locked : grant_combo;
        end else begin : g_free_engine
            assign grant_idx_q      = '0;
            assign grant_held       = 1'b0;
            assign grant_mid_locked = '0;
            assign grant_mid        = grant_combo;
        end
    endgenerate

    // ---- 状态更新使能：GRANT_ACK_EN=1 时仅在非锁定期间更新配额/credit ----
    // 锁定期间授权未消费（无 grant_ev），也不触发窗口重置/回补，避免配额在锁定未消费前归位
    logic state_update_en;
    assign state_update_en = (GRANT_ACK_EN == 1) ? ~grant_held : 1'b1;

    // ---- WMODE=0 quota 状态更新（INV-002）----
    //  - 授权发生（非锁定）→ 被授权路 cnt-1
    //  - 窗口重置：eligible 全 0 且仍有资格（qual）→ 整轮重置 cnt=w（ASM-006）
    generate
        if (WMODE == 0) begin : g_quota
            logic [N-1:0] grant_ev;    // 授权事件（GRANT_ACK_EN=0 每拍 / =1 仅 ack 消费）
            if (GRANT_ACK_EN == 1) begin : g_ev_ack
                assign grant_ev = (grant_ack_i && grant_held) ? grant_mid_locked : '0;
            end else begin : g_ev_free
                assign grant_ev = grant_combo;
            end
            logic window_reset;
            assign window_reset = state_update_en & (~|elig_quota) & (|qual);
            for (genvar i = 0; i < N; i++) begin : g_cnt
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        quota_cnt[i] <= '0;
                    else if (window_reset)
                        quota_cnt[i] <= w[i];              // 新一轮：配额=权重
                    else if (state_update_en && grant_ev[i])
                        quota_cnt[i] <= quota_cnt[i] - 1'b1; // 被授权路配额-1
                end
            end
            // 复位为 0：复位后第一拍 eligible=0，若 qual 非 0 → window_reset 载入权重（空窗 1 拍）
        end
    endgenerate

    // ---- WMODE=1 smooth 状态更新（INV-004）----
    //  - 回补判定：所有资格路 credit < N（阈值）→ 统一回补 credit += w（回补拍屏蔽授权）
    //  - 授权发生（非回补拍）→ 被选路 credit -= 1（保证无负 credit：被选路在非回补拍必 >= N >= 1）
    generate
        if (WMODE == 1) begin : g_smooth
            logic [N-1:0] grant_ev;
            if (GRANT_ACK_EN == 1) begin : g_ev_ack_s
                assign grant_ev = (grant_ack_i && grant_held) ? grant_mid_locked : '0;
            end else begin : g_ev_free_s
                assign grant_ev = grant_combo;
            end
            logic         replenish;
            assign replenish = state_update_en & smooth_all_low;
            for (genvar i = 0; i < N; i++) begin : g_cred
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        credit[i] <= '0;
                    else if (replenish)
                        credit[i] <= credit[i] + { {(CW-WW){1'b0}}, w[i] }; // 回补 += 权重
                    else if (state_update_en && grant_ev[i])
                        credit[i] <= credit[i] - 1'b1;    // 被选路 credit-1
                end
            end
            // 复位为 0：复位后第一拍 all_low（0 < N）→ replenish 载入权重（空窗 1 拍）
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
    // INV-003 活性 + 授权子集：仅对非锁定模式适用（锁定期间授权保持到 ack 应答，请求可能已撤）
    // 活性以 sel_vec（有可授权资格）为前件：回补拍/窗口重置空窗拍（sel_vec=0）无授权是合法语义
    generate
        if (GRANT_ACK_EN == 0) begin : g_sva_live
            assert property (@(posedge clk) (|sel_vec) |-> ($countones(grant_mid) == 1));
            assert property (@(posedge clk) (~|sel_vec) |-> (~|grant_mid));
            assert property (@(posedge clk) (grant_mid & qual) == grant_mid);
        end
    endgenerate

    generate
        // INV-002 quota 守恒：授权发生的路配额必 >0，且窗口内该路配额不超发（quota_cnt 不减到负）
        if (WMODE == 0 && GRANT_ACK_EN == 0) begin : g_sva_quota
            for (genvar i = 0; i < N; i++) begin : g_sva_q_i
                assert property (@(posedge clk) disable iff(!rst_n)
                    (grant_combo[i]) |-> (quota_cnt[i] > 0));
                // 窗口内累计授权 <= 权重：用"配额=权重时才能被选 + 授权后递减"表达，见仿真 tc_quota_window
                assert property (@(posedge clk) disable iff(!rst_n)
                    (quota_cnt[i] == '0) |-> ~grant_combo[i]);
            end
        end
        // INV-004 smooth 守恒：授权发生的路 credit 必 >= N（回补拍屏蔽授权，无负 credit）
        if (WMODE == 1 && GRANT_ACK_EN == 0) begin : g_sva_smooth
            for (genvar i = 0; i < N; i++) begin : g_sva_s_i
                assert property (@(posedge clk) disable iff(!rst_n)
                    (grant_combo[i]) |-> (credit[i] >= CW'(N)));
                assert property (@(posedge clk) disable iff(!rst_n)
                    (credit[i] < CW'(N)) |-> (~grant_combo[i] || smooth_all_low));
            end
        end
        // INV-005 registered：寄存授权 == 组合授权打拍（1 拍延迟）
        if (GRANT_ACK_EN == 0 && FAST_GRANT == 1) begin : g_sva_reg
            assert property (@(posedge clk) disable iff(!rst_n)
                grant_o == $past(grant_mid));
        end
        // INV-006 ack 锁定：GRANT_ACK_EN=1 且未应答时锁定授权保持、rr_ptr 不变
        // rr_ptr 仅在锁定时未应答才保持；空闲但有 core_hit 时 rr_ptr 照常推进
        if (GRANT_ACK_EN == 1) begin : g_sva_ack
            assert property (@(posedge clk) disable iff(!rst_n)
                (grant_held && !grant_ack_i) |-> (grant_mid == $past(grant_mid)));
            assert property (@(posedge clk) disable iff(!rst_n)
                (grant_held && !grant_ack_i) |-> (rr_ptr == $past(rr_ptr)));
        end
    endgenerate

endmodule

// ============================================================================
// w_rr_scan — 轮转扫描核心（从 rr_ptr 起回绕选择 sel_i 首个置位）
//   rotated = (sel_i >> rr_ptr) | (sel_i << ((N - rr_ptr) % N))   （循环右移，ptr 位落 LSB）
//   grant_rot = first_set(rotated)（LSB 优先编码）
//   逆旋转回原始索引空间（动态索引 LHS 需 always_comb 内循环赋值）
// ============================================================================
module w_rr_scan #(
    parameter int NUM_REQ = 8
) (
    input  logic [NUM_REQ-1:0]         sel_i,
    input  logic [$clog2(NUM_REQ)-1:0] rr_ptr,
    output logic [NUM_REQ-1:0]         grant_o,
    output logic [$clog2(NUM_REQ)-1:0] grant_idx,
    output logic                      hit
);
    localparam int N = NUM_REQ;
    localparam int PW = $clog2(N);
    logic [N-1:0] rotated, grant_rot;

    // 循环右移 rr_ptr 位（barrel，O(log N) 深）；移位后 LSB 为 sel_i[rr_ptr]
    assign rotated = (sel_i >> rr_ptr) | (sel_i << ((N - rr_ptr) % N));

    // 选择：从 LSB 起首个置位（即 rotated 的 LSB 优先编码）
    w_first_set #(.NUM_REQ(N)) u_fs (.v(rotated), .onehot(grant_rot));

    // 逆旋转回原始索引空间：grant[(ptr+j)%N] = grant_rot[j]（动态索引 LHS 需 always_comb）
    always_comb begin
        grant_o = '0;
        for (int j = 0; j < N; j++)
            grant_o[(rr_ptr + j) % N] = grant_rot[j];
    end

    assign hit = |sel_i;
    w_idx_encode #(.NUM_REQ(N)) u_idx (.req_i(grant_o), .idx(grant_idx));
endmodule

// ============================================================================
// w_first_set — LSB 优先编码（first_set：返回 v 中首个置位的一位热码）
//   onehot[i] = v[i] & ~|v[i-1:0]；onehot[0] = v[0]
//   逻辑深度 O(N)（线性链）；综合器自动平衡（DC 可重组为前缀树）。
// ============================================================================
module w_first_set #(
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
// w_idx_encode — 一位热码 → 二进制索引（priority encoder）
//   输入一位热（至多 1 位有效），输出该位索引（log2(N) 位）。
// ============================================================================
module w_idx_encode #(
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
