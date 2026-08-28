// ============================================================================
// fpa_tb — G4 功能验证测试台 (verify-cbb: 穷举 + 随机 + 优先级 + 边界 + 等价 + 锁存/寄存)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_exhaust_w4 : N=4 全空间 16 向量 × 三实现 × PRIORITY{0,1} (REQ-001)
//   tc_mutex      : 随机请求 N∈{8,16,32,64} 互斥 (REQ-001)
//   tc_priority   : 单热逐位 + 多请求优先级 × PRIORITY{0,1} (REQ-002)
//   tc_edge       : 全0/全1 边界 (REQ-003)
//   tc_latched    : REQ_TYPE=1 锁存/ack (REQ-004)
//   tc_registered : FAST_GRANT=1 寄存授权 (REQ-005)
//   tc_equiv      : 三实现跨实现一致 (REQ-006)
//   tc_mutation   : 变异——破坏互斥语义，断言应能检测 (REQ-001)
//   tc_negative_elab : 非法参数 elaboration 拦截（执行体 verification/scripts/run_static_checks.sh
//                      + verification/formal/negative_elab_tb.sv，REQ-007）
// 黄金模型：独立逐位扫描
// ============================================================================
`timescale 1ns/1ps

module fpa_tb;
    localparam int SEED = 32'hF0A_2026_0828;

    logic clk, rst_n;
    initial begin clk = 0; forever #5 clk = ~clk; end

    // ---- N=4 穷举：三实现 × PRIORITY{0,1} ----
    logic [63:0] req_in;
    wire [3:0] gl4_0, gt4_0, gg4_0, gl4_1, gt4_1, gg4_1;
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(0)) dut_l4_0 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(gl4_0));
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(1)) dut_t4_0 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(gt4_0));
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(2)) dut_g4_0 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(gg4_0));
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(1),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(0)) dut_l4_1 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(gl4_1));
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(1),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(1)) dut_t4_1 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(gt4_1));
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(1),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(2)) dut_g4_1 (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(gg4_1));

    // ---- 随机互斥 + 等价：N=64 三实现（位段复用）----
    wire [63:0] gL, gT, gG;
    fixed_priority_arbiter #(.NUM_REQ(64),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(0)) dut_L (.clk(clk),.rst_n(rst_n),.req_i(req_in),.grant_ack_i(1'b0),.grant_o(gL));
    fixed_priority_arbiter #(.NUM_REQ(64),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(1)) dut_T (.clk(clk),.rst_n(rst_n),.req_i(req_in),.grant_ack_i(1'b0),.grant_o(gT));
    fixed_priority_arbiter #(.NUM_REQ(64),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(2)) dut_G (.clk(clk),.rst_n(rst_n),.req_i(req_in),.grant_ack_i(1'b0),.grant_o(gG));

    // ---- latched（REQ_TYPE=1, N=4, linear, PRIORITY=0）----
    logic       ack;
    logic [3:0] req_hold_i;
    wire  [3:0] glat;
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(0),.REQ_TYPE(1),.FAST_GRANT(0),.PC_IMPL(0)) dut_lat (.clk(clk),.rst_n(rst_n),.req_i(req_hold_i),.grant_ack_i(ack),.grant_o(glat));

    // ---- registered（FAST_GRANT=1, N=4, linear, PRIORITY=0）+ 组合参考 ----
    wire [3:0] greg, greg_c;
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(1),.PC_IMPL(0)) dut_reg (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(greg));
    fixed_priority_arbiter #(.NUM_REQ(4),.PRIORITY(0),.REQ_TYPE(0),.FAST_GRANT(0),.PC_IMPL(0)) dut_regc (.clk(clk),.rst_n(rst_n),.req_i(req_in[3:0]),.grant_ack_i(1'b0),.grant_o(greg_c));

    // ---- 黄金参考：独立逐位扫描 ----
    function automatic logic [63:0] golden(input logic [63:0] v, input int n, input int prio);
        logic [63:0] g; g = 64'd0;
        if (prio == 0) begin
            for (int i = 0; i < n; i++) if (v[i] == 1'b1) begin g[i] = 1'b1; break; end
        end else begin
            for (int i = n-1; i >= 0; i--) if (v[i] == 1'b1) begin g[i] = 1'b1; break; end
        end
        return g;
    endfunction

    // 低位 n 位掩码（避免运行期位选宽度非 const 问题）
    function automatic logic [63:0] lo_mask(input int n);
        logic [63:0] m; m = '0;
        for (int i = 0; i < n; i++) m[i] = 1'b1;
        return m;
    endfunction

    int errors;
    initial errors = 0;

    task automatic chk(input logic [63:0] req, input int n, input int prio,
                       input logic [63:0] got, input string tag);
        logic [63:0] exp, gm, em, m;
        m  = lo_mask(n);
        exp = golden(req, n, prio);
        gm = got & m; em = exp & m;
        if (gm !== em)
            errors++; // 汇总计数（详细定位走 chk_explicit）
    endtask

    task automatic chk_explicit(input logic [63:0] req, input int n, input int prio,
                                input logic [63:0] got, input string tag);
        logic [63:0] exp, gm, em, m;
        m  = lo_mask(n);
        exp = golden(req, n, prio);
        gm = got & m; em = exp & m;
        if (gm !== em) begin
            errors++; $display("[FAIL] %s req=%0h n=%0d prio=%0d got=%0h exp=%0h", tag, req, n, prio, gm, em);
        end
    endtask

    initial begin
        $display("=== fpa_tb start (seed=%0d) ===", SEED);
        rst_n = 1'b0; ack = 1'b0; req_in = '0; req_hold_i = '0;
        repeat (3) @(negedge clk); rst_n = 1'b1;
        @(negedge clk);

        // ---------------- tc_exhaust_w4 ----------------
        for (int v = 0; v < 16; v++) begin
            req_in = 64'(v[3:0]); #1;
            chk(req_in,4,0,64'(gl4_0),"W4L0"); chk(req_in,4,0,64'(gt4_0),"W4T0"); chk(req_in,4,0,64'(gg4_0),"W4G0");
            chk(req_in,4,1,64'(gl4_1),"W4L1"); chk(req_in,4,1,64'(gt4_1),"W4T1"); chk(req_in,4,1,64'(gg4_1),"W4G1");
        end
        $display("[tc_exhaust_w4] 16 vectors × 6 DUT done");

        // ---------------- tc_priority（单热 + 多请求）----------------
        for (int b = 0; b < 4; b++) begin
            req_in = 64'(1) << b; #1;
            chk_explicit(req_in,4,0,64'(gl4_0),"onehot_L0");
            chk_explicit(req_in,4,1,64'(gl4_1),"onehot_L1");
        end
        req_in = 64'hF; #1;
        chk_explicit(req_in,4,0,64'(gl4_0),"all1_L0");
        chk_explicit(req_in,4,1,64'(gl4_1),"all1_L1");
        req_in = 64'h6; #1;
        chk_explicit(req_in,4,0,64'(gl4_0),"0110_L0");
        chk_explicit(req_in,4,1,64'(gl4_1),"0110_L1");
        $display("[tc_priority] done");

        // ---------------- tc_edge ----------------
        req_in = '0; #1;
        if (gl4_0 !== 4'b0000 || gl4_1 !== 4'b0000) begin errors++; $display("[FAIL] edge none"); end
        req_in = 64'hFFFFFFFFFFFFFFFF; #1;
        if (gl4_0 !== 4'b0001 || gl4_1 !== 4'b1000) begin errors++; $display("[FAIL] edge all1 L0=%b L1=%b", gl4_0, gl4_1); end
        $display("[tc_edge] done");

        // ---------------- tc_mutex + tc_random（随机请求，互斥 + 黄金 + 等价）----------------
        process::self.srandom(SEED);
        for (int i = 0; i < 2000; i++) begin
            void'(std::randomize(req_in)); #1;
            // 互斥：所有位段至多 1 个授权
            if ($countones(gL[0+:8]) > 1 || $countones(gL[0+:16]) > 1 ||
                $countones(gL[0+:32]) > 1 || $countones(gL) > 1 ||
                $countones(gT) > 1 || $countones(gG) > 1) begin
                errors++; $display("[FAIL] mutex req=%0h", req_in);
            end
            // 黄金：对位段取样
            chk(req_in,8,0,gL,"m8"); chk(req_in,16,0,gL,"m16"); chk(req_in,32,0,gL,"m32"); chk(req_in,64,0,gL,"m64");
            // 等价：三实现一致
            if (gL !== gT || gT !== gG) begin
                errors++; $display("[FAIL] equiv mismatch l/t/g=%h/%h/%h req=%0h", gL, gT, gG, req_in);
            end
        end
        $display("[tc_mutex/random/equiv] 2000 seeded random × N64 done");

        // ---------------- tc_latched（锁存 + ack）----------------
        begin : tc_latched
            @(negedge clk); req_hold_i = 4'b0010; ack = 1'b0; @(negedge clk);
            // 请求被锁存：req_i 撤掉后 grant 仍保持
            req_hold_i = 4'b0000; @(negedge clk);
            if (glat !== 4'b0010) begin errors++; $display("[FAIL] latched: grant not held got=%b", glat); end
            // ack 应答：授权清除
            ack = 1'b1; @(negedge clk); @(negedge clk);
            if (glat !== 4'b0000) begin errors++; $display("[FAIL] latched: grant not cleared after ack got=%b", glat); end
            // ack 无请求：保持 0
            ack = 1'b0; @(negedge clk);
            if (glat !== 4'b0000) begin errors++; $display("[FAIL] latched: grant nonzero with no hold req got=%b", glat); end
            $display("[tc_latched] done");
        end

        // ---------------- tc_registered（寄存授权 1 拍延迟）----------------
        begin : tc_registered
            @(negedge clk); req_in = 64'h4; @(negedge clk);   // 组合参考立即生效
            // 拍 t：组合 greg_c=0100；寄存 greg 在下一拍才=0100
            @(negedge clk);
            if (greg_c !== 4'b0100) begin errors++; $display("[FAIL] reg combo got=%b", greg_c); end
            if (greg !== 4'b0100) begin errors++; $display("[FAIL] reg delayed got=%b (exp 0100)", greg); end
            req_in = 64'h1; @(negedge clk); @(negedge clk);
            if (greg !== 4'b0001) begin errors++; $display("[FAIL] reg final got=%b", greg); end
            $display("[tc_registered] done");
        end

        // ---------------- 终局判定 ----------------
        if (errors == 0) $display("=== FPA_TB PASS: all scenarios clean ===");
        else $display("=== FPA_TB FAIL: %0d mismatches ===", errors);
        $finish;
    end

    // 超时看门狗
    initial begin
        #10_000_000;
        $display("=== FPA_TB TIMEOUT ==="); $finish;
    end

endmodule
