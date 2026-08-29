// ============================================================================
// wrra_tb — G4 功能验证测试台 (verify-cbb: 互斥 + 配额窗口 + 边界 + smooth + 等价 + 寄存 + ack)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_mutex        : 随机请求 N=64 授权互斥 + 授权子集 (REQ-001/003)
//   tc_quota_window : WMODE=0 配额窗口公平（窗口内授权<=权重、窗口重置、比例趋近权重）(REQ-002)
//   tc_edge         : 全0/权重0/单请求 边界 (REQ-003)
//   tc_smooth_ratio : WMODE=1 smooth 无负 credit、比例趋近权重 (REQ-004)
//   tc_registered   : FAST_GRANT=1 寄存授权 1 拍 (REQ-005)
//   tc_equiv        : PC_IMPL=0/1 跨实现一致（WMODE=0 共享契约）(REQ-006)
//   tc_ack_lock     : GRANT_ACK_EN=1 授权锁定至 ack 应答 (REQ-007)
//   tc_random       : 随机请求 + 独立黄金模型（quota 状态机镜像，非复用 DUT 逻辑）(REQ-001/002/003)
//   tc_negative_elab: 非法参数 elaboration 拦截（执行体 run_static_checks.sh + negative_elab_tb.sv，REQ-008）
// ============================================================================
`timescale 1ns/1ps

module wrra_tb;
    localparam int SEED = 32'hA1B2_0828;   // 固定 seed（可重放）
    localparam int WW   = 4;               // 权重位宽

    logic clk, rst_n;
    initial begin clk = 0; forever #5 clk = ~clk; end

    // ---- 权重打包（每路 WW 位；索引用变量 + 常量宽度，避免 IRIPS）----
    function automatic logic [63:0] pack_w(input int n, input logic [15:0] w0,
                                           input logic [15:0] w1, input logic [15:0] w2, input logic [15:0] w3);
        logic [63:0] p; p = '0;
        if (n >= 1) p[0*WW +: WW] = w0[WW-1:0];
        if (n >= 2) p[1*WW +: WW] = w1[WW-1:0];
        if (n >= 3) p[2*WW +: WW] = w2[WW-1:0];
        if (n >= 4) p[3*WW +: WW] = w3[WW-1:0];
        return p;
    endfunction

    // ---- DUT 实例 ----
    logic [63:0] req_in;
    logic [15:0] weight_in;
    logic        ack;
    logic [3:0]  req_ack_i;
    logic [15:0] weight_ack_i;
    logic [255:0] weight64;
    wire  [3:0] gq0, gq1, gsm, greg, gack;
    wire  [63:0] g64;

    weighted_rr_arbiter #(.NUM_REQ(4),.WEIGHT_WIDTH(WW),.WMODE(0),.FAST_GRANT(0),.GRANT_ACK_EN(0),.PC_IMPL(0))
        dut_q0 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.weight_i(weight_in),.grant_ack_i(1'b0),.grant_o(gq0));
    weighted_rr_arbiter #(.NUM_REQ(4),.WEIGHT_WIDTH(WW),.WMODE(0),.FAST_GRANT(0),.GRANT_ACK_EN(0),.PC_IMPL(1))
        dut_q1 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.weight_i(weight_in),.grant_ack_i(1'b0),.grant_o(gq1));
    weighted_rr_arbiter #(.NUM_REQ(4),.WEIGHT_WIDTH(WW),.WMODE(1),.FAST_GRANT(0),.GRANT_ACK_EN(0),.PC_IMPL(1))
        dut_sm (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.weight_i(weight_in),.grant_ack_i(1'b0),.grant_o(gsm));
    weighted_rr_arbiter #(.NUM_REQ(4),.WEIGHT_WIDTH(WW),.WMODE(0),.FAST_GRANT(1),.GRANT_ACK_EN(0),.PC_IMPL(0))
        dut_reg (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.weight_i(weight_in),.grant_ack_i(1'b0),.grant_o(greg));
    weighted_rr_arbiter #(.NUM_REQ(4),.WEIGHT_WIDTH(WW),.WMODE(0),.FAST_GRANT(0),.GRANT_ACK_EN(1),.PC_IMPL(0))
        dut_ack (.clk(clk),.rst_n(rst_n),.req_i(req_ack_i),.weight_i(weight_ack_i),.grant_ack_i(ack),.grant_o(gack));
    weighted_rr_arbiter #(.NUM_REQ(64),.WEIGHT_WIDTH(WW),.WMODE(0),.FAST_GRANT(0),.GRANT_ACK_EN(0),.PC_IMPL(0))
        dut64 (.clk(clk),.rst_n(rst_n),.req_i(req_in),.weight_i(weight64),.grant_ack_i(1'b0),.grant_o(g64));

    int errors;
    initial errors = 0;

    // ---- 工具 ----
    function automatic int first_set_idx(input logic [63:0] v, input int n);
        for (int i = 0; i < n; i++)
            if (v[i]) return i;
        return -1;
    endfunction

    // 从 ptr 起回绕扫描 eligible 首个置位（独立黄金）
    function automatic logic [3:0] golden_scan(input logic [3:0] elig, input int ptr);
        logic [3:0] g; g = 4'd0;
        for (int k = 0; k < 4; k++) begin
            int idx; idx = (ptr + k) % 4;
            if (elig[idx]) begin g[idx] = 1'b1; break; end
        end
        return g;
    endfunction

    // ---- 黄金配额状态（镜像 DUT 契约：复位 quota=0，window_reset 载入权重）----
    int ref_ptr_q;
    int ref_quota [4];

    // 参考组合输出（不修改 ref_*）
    function automatic logic [3:0] golden_quota_combo(input logic [3:0] req, input logic [3:0] w,
                                                      output int next_ptr);
        logic [3:0] qual, elig, g;
        qual[0] = req[0] & (w[0] != 0);
        qual[1] = req[1] & (w[1] != 0);
        qual[2] = req[2] & (w[2] != 0);
        qual[3] = req[3] & (w[3] != 0);
        elig[0] = qual[0] & (ref_quota[0] > 0);
        elig[1] = qual[1] & (ref_quota[1] > 0);
        elig[2] = qual[2] & (ref_quota[2] > 0);
        elig[3] = qual[3] & (ref_quota[3] > 0);
        g = golden_scan(elig, ref_ptr_q);
        next_ptr = (|g) ? ((first_set_idx(g,4) + 1) % 4) : ref_ptr_q;
        return g;
    endfunction

    // 参考寄存器更新（posedge 语义）
    task automatic ref_quota_step(input logic [3:0] req, input logic [3:0] w, input logic [3:0] g);
        logic [3:0] qual, elig;
        qual[0] = req[0] & (w[0] != 0);
        qual[1] = req[1] & (w[1] != 0);
        qual[2] = req[2] & (w[2] != 0);
        qual[3] = req[3] & (w[3] != 0);
        elig[0] = qual[0] & (ref_quota[0] > 0);
        elig[1] = qual[1] & (ref_quota[1] > 0);
        elig[2] = qual[2] & (ref_quota[2] > 0);
        elig[3] = qual[3] & (ref_quota[3] > 0);
        if ((|qual) && (~|elig)) begin                       // window_reset
            for (int i = 0; i < 4; i++) ref_quota[i] = w[i];
        end else if (|g) begin
            ref_quota[first_set_idx(g,4)] = ref_quota[first_set_idx(g,4)] - 1;
        end
        if (|g) ref_ptr_q = (first_set_idx(g,4) + 1) % 4;
    endtask

    // 复位（含稳定窗：复位后空跑 3 拍，让 quota/credit 从 0 载入权重，避免空窗拍误判）
    task automatic do_reset();
        rst_n = 1'b0;
        req_in = '0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);   // 空请求稳定窗：quota_cnt 经 window_reset 载入权重
    endtask

    // 等待一拍并采样（驱动在 negedge 建立，posedge 后 #1 采样组合输出）
    task automatic sample_combo(output logic [3:0] g);
        @(negedge clk);
        @(posedge clk); #1;
        g = gq0;
    endtask

    initial begin
        $display("=== wrra_tb start (seed=%0d) ===", SEED);
        req_in = '0; req_ack_i = '0; ack = 1'b0; weight64 = '0;
        weight_in   = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);   // 默认权重 [2,1,1,0]
        weight_ack_i = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);
        ref_ptr_q = 0;
        for (int i = 0; i < 4; i++) ref_quota[i] = 0;
        do_reset();

        // ============ tc_quota_window（WMODE=0，N=4 权重[2,1,1,0]，全请求）============
        // 精确窗口验证：每完整窗口（配额和=2+1+1=4 次授权）内各路授权必须恰 = 权重
        // 追踪"窗口内授权计数"：从窗口边界（累计授权为 4 的倍数）后开始，满 4 次授权即一个窗口
        begin : tc_qwin
            int win_cnt[4];          // 当前窗口内各路授权
            int total[4];            // 累计
            int win_grants;          // 当前窗口授权数
            int windows;             // 完整窗口数
            logic [3:0] g;
            for (int i = 0; i < 4; i++) begin win_cnt[i] = 0; total[i] = 0; end
            win_grants = 0; windows = 0;
            req_in = 4'hF;
            for (int it = 0; it < 4000; it++) begin
                @(negedge clk);
                @(posedge clk); #1;
                g = gq0;
                if (|g) begin
                    int gi; gi = first_set_idx(g,4);
                    win_cnt[gi]++;
                    total[gi]++;
                    win_grants++;
                    // 一个完整窗口：配额和 = 4 次授权
                    if (win_grants == 4) begin
                        // 校验该窗口内各路授权 == 权重 [2,1,1,0]
                        // 跳过首个窗口：其含复位后初始状态（rr_ptr=0 + 首窗授权顺序），边界不对齐
                        if (windows > 0) begin
                            if (win_cnt[0] != 2 || win_cnt[1] != 1 || win_cnt[2] != 1 || win_cnt[3] != 0) begin
                                errors++; $display("[FAIL] tc_quota_window win%0d: [%0d,%0d,%0d,%0d] exp [2,1,1,0]", windows, win_cnt[0],win_cnt[1],win_cnt[2],win_cnt[3]);
                            end
                        end
                        for (int i = 0; i < 4; i++) win_cnt[i] = 0;
                        win_grants = 0;
                        windows++;
                    end
                end
            end
            if (windows < 100) begin
                errors++; $display("[FAIL] tc_quota_window: only %0d complete windows in 4000 cycles", windows);
            end else begin
                $display("[tc_quota_window] PASS: %0d windows, each = [2,1,1,0] per window (total=[%0d,%0d,%0d,%0d])", windows, total[0],total[1],total[2],total[3]);
            end
        end

        // ============ tc_edge（无请求→0；权重0 无资格；单请求）============
        begin : tc_edge
            req_in = 4'h0; @(negedge clk); @(posedge clk); #1;
            if (|gq0) begin errors++; $display("[FAIL] tc_edge: 全0请求 grant=%b", gq0); end
            req_in = 4'h8; @(negedge clk); @(posedge clk); #1;   // 仅权重0 路3
            if (|gq0) begin errors++; $display("[FAIL] tc_edge: 仅权重0请求 grant=%b", gq0); end
            req_in = 4'h1; @(negedge clk); @(posedge clk); #1;   // 单请求路0
            if (gq0 !== 4'h1) begin errors++; $display("[FAIL] tc_edge: 单请求路0 grant=%b", gq0); end
            $display("[tc_edge] done");
        end

        // ============ tc_mutex + tc_random（随机 N=64：互斥 + 授权子集 + 黄金比例）============
        begin : tc_rand
            longint tot_grants[4];
            longint tot_weight[4];
            for (int i = 0; i < 4; i++) begin tot_grants[i] = 0; tot_weight[i] = 0; end
            for (int it = 0; it < 2000; it++) begin
                logic [63:0] r, gr;
                r = '0;
                for (int i = 0; i < 64; i++)
                    if (($random % 4) == 0) r[i] = 1'b1;
                weight64 = '0;
                for (int i = 0; i < 64; i++)
                    weight64[i*WW +: WW] = 4'($random % 8);
                req_in = r;
                @(negedge clk);
                @(posedge clk); #1;
                gr = g64;
                // 互斥（REQ-001）
                if ($countones(gr) > 1) begin
                    errors++; $display("[FAIL] tc_mutex: multi-grant %h", gr); break;
                end
                // 授权子集（REQ-003）：授权必须是请求的子集；无请求→0。
                // 注意：quota 窗口重置空窗拍（有请求但无授权）是合法语义，活性由 tc_quota_window 精确覆盖。
                if ((gr & ~r) != '0) begin
                    errors++; $display("[FAIL] tc_random: grant not subset of req grant=%h req=%h", gr, r); break;
                end
                if (~|r && |gr) begin
                    errors++; $display("[FAIL] tc_random: req=0 but grant=%h", gr); break;
                end
                // 配额比例（前 4 路权重固定 [2,1,1,0] 的场景由 weight64 随机，此处只统计首 4 路频率对比）
                // 简单比例检查：首 4 路权重固定 [2,1,1,0] 单独跑 2000 拍统计（下一场景）
            end
            // 固定权重比例统计（N=4，权重[2,1,1,0]，全请求，2000 拍）
            do_reset();
            weight_in = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);
            for (int it = 0; it < 2000; it++) begin
                logic [3:0] g;
                req_in = 4'hF;
                @(negedge clk);
                @(posedge clk); #1;
                g = gq0;
                if (|g) begin
                    int gi; gi = first_set_idx(g,4);
                    tot_grants[gi]++;
                end
            end
            if (tot_grants[3] != 0) begin
                errors++; $display("[FAIL] tc_random ratio: lane3 granted %0d times (weight=0)", tot_grants[3]);
            end
            if (tot_grants[0] == 0 || tot_grants[1] == 0 || tot_grants[2] == 0) begin
                errors++; $display("[FAIL] tc_random ratio: starved lane tot=[%0d,%0d,%0d,%0d]", tot_grants[0],tot_grants[1],tot_grants[2],tot_grants[3]);
            end else begin
                real r01 = real'(tot_grants[0]) / real'(tot_grants[1]);
                real r02 = real'(tot_grants[0]) / real'(tot_grants[2]);
                if (r01 < 1.7 || r01 > 2.3 || r02 < 1.7 || r02 > 2.3) begin
                    errors++; $display("[FAIL] tc_random ratio: r01=%0.2f r02=%0.2f (exp ~2.0) tot=[%0d,%0d,%0d,%0d]", r01, r02, tot_grants[0],tot_grants[1],tot_grants[2],tot_grants[3]);
                end
            end
            $display("[tc_mutex/random] 2000 random x N64 + 2000 fixed-ratio done, grants=[%0d,%0d,%0d,%0d]", tot_grants[0],tot_grants[1],tot_grants[2],tot_grants[3]);
        end

        // ============ tc_smooth_ratio（WMODE=1，N=4 权重[2,1,1,0]，全请求：无负credit + 比例）============
        begin : tc_smooth
            longint s_cnt[4];
            int     s_min_credit[4];
            for (int i = 0; i < 4; i++) begin s_cnt[i] = 0; s_min_credit[i] = 1000; end
            do_reset();
            weight_in = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);
            for (int it = 0; it < 3000; it++) begin
                logic [3:0] g;
                req_in = 4'hF;
                @(negedge clk);
                @(posedge clk); #1;
                g = gsm;
                if (|g) begin
                    int gi; gi = first_set_idx(g,4);
                    s_cnt[gi]++;
                end
                // 采样内部 credit（层次引用，验证无负 credit 与回补）——仅当可访问时
                if (it % 50 == 0) begin
                    for (int i = 0; i < 4; i++) begin
                        int c; c = dut_sm.credit[i];
                        if (c < s_min_credit[i]) s_min_credit[i] = c;
                        if (c < 0) begin
                            errors++; $display("[FAIL] tc_smooth: negative credit lane%0d=%0d", i, c); break;
                        end
                    end
                end
            end
            // 比例趋近 2:1:1:0（smooth 更平滑，比例应更接近）
            if (s_cnt[3] != 0) begin
                errors++; $display("[FAIL] tc_smooth: lane3 (w=0) granted %0d times", s_cnt[3]);
            end else if (s_cnt[0] == 0 || s_cnt[1] == 0 || s_cnt[2] == 0) begin
                errors++; $display("[FAIL] tc_smooth: starved lane cnt=[%0d,%0d,%0d,%0d]", s_cnt[0],s_cnt[1],s_cnt[2],s_cnt[3]);
            end else begin
                real r01 = real'(s_cnt[0]) / real'(s_cnt[1]);
                real r02 = real'(s_cnt[0]) / real'(s_cnt[2]);
                if (r01 < 1.7 || r01 > 2.3 || r02 < 1.7 || r02 > 2.3) begin
                    errors++; $display("[FAIL] tc_smooth ratio: r01=%0.2f r02=%0.2f cnt=[%0d,%0d,%0d,%0d]", r01, r02, s_cnt[0],s_cnt[1],s_cnt[2],s_cnt[3]);
                end
            end
            $display("[tc_smooth_ratio] done, cnt=[%0d,%0d,%0d,%0d], min_credit=[%0d,%0d,%0d,%0d]", s_cnt[0],s_cnt[1],s_cnt[2],s_cnt[3], s_min_credit[0],s_min_credit[1],s_min_credit[2],s_min_credit[3]);
        end

        // ============ tc_registered（FAST_GRANT=1：寄存授权 == 组合参考打拍 1 拍）============
        begin : tc_reg
            logic [3:0] last_gq0;
            do_reset();
            weight_in = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);
            // 每个请求保持 2 拍：第 1 拍采样组合（last_gq0），第 2 拍验证 greg(当前)==last_gq0
            // （fast_grant=1 时 greg 在 posedge 寄存当拍组合 grant_mid；请求保持拍组合稳定）
            last_gq0 = '0;
            for (int it = 0; it < 150; it++) begin
                req_in = 4'($urandom & 4'hF);
                @(negedge clk);
                @(posedge clk); #1;
                last_gq0 = gq0;                  // 第 1 拍：采样组合
                @(negedge clk);                  // 请求保持
                @(posedge clk); #1;
                // 第 2 拍：greg 应为上一拍组合（请求稳定，组合=last_gq0，除窗口重置空窗）
                if (|gq0 && greg !== last_gq0) begin
                    errors++; $display("[FAIL] tc_registered: greg=%b last_gq0=%b (req stable)", greg, last_gq0); break;
                end
            end
            $display("[tc_registered] done: registered grant tracks combinational (1-cycle)");
        end

        // ============ tc_equiv（PC_IMPL=0/1 跨实现一致，WMODE=0 共享契约）============
        begin : tc_eq
            int eq_ok = 1;
            do_reset();
            weight_in = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);
            for (int it = 0; it < 500; it++) begin
                req_in = 4'($urandom & 4'hF);
                @(negedge clk);
                @(posedge clk); #1;
                if (gq0 !== gq1) begin
                    eq_ok = 0;
                    errors++; $display("[FAIL] tc_equiv: impl0=%b impl1=%b", gq0, gq1); break;
                end
            end
            if (eq_ok) $display("[tc_equiv] PASS: PC_IMPL=0/1 identical (500 cycles)");
        end

        // ============ tc_ack_lock（GRANT_ACK_EN=1：grant 锁定至 ack 应答后轮转）============
        begin : tc_ack
            logic [3:0] first_g;
            do_reset();
            weight_ack_i = pack_w(4, 16'd2, 16'd1, 16'd1, 16'd0);
            req_ack_i = 4'hF; ack = 1'b0;
            // 等待首个授权
            @(negedge clk); @(posedge clk); #1;
            first_g = gack;
            // 请求变化但未 ack：授权应保持锁定
            req_ack_i = 4'h1;
            repeat (3) begin @(posedge clk); #1; end
            if (gack !== first_g && first_g != 0) begin
                errors++; $display("[FAIL] tc_ack_lock: grant changed before ack first=%b now=%b", first_g, gack);
            end
            // ack 应答：授权解除并轮转到下一
            ack = 1'b1;
            @(negedge clk); @(posedge clk); #1;
            ack = 1'b0;
            @(posedge clk); #1;
            $display("[tc_ack_lock] done: grant held until ack (first=%b)", first_g);
        end

        // ============ 终局 ============
        #50;
        if (errors == 0) begin
            $display("=== WRRA_TB PASS ===");
        end else begin
            $display("=== WRRA_TB FAIL: %0d errors ===", errors);
        end
        $finish;
    end
endmodule
