// ============================================================================
// skid_buffer_tb — G4 功能验证测试台（多实现：full / forward / BYPASS）
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_random         : 随机 valid/ready 流（full, IMPL=1, REQ-001/INV-001,003）
//   tc_backpressure   : 高背压（full, REQ-002/INV-002）
//   tc_edge           : 空流/单拍/连续背压边界（full, REQ-003/INV-002）
//   tc_fwd_random     : 随机流（forward, IMPL=0, REQ-005/INV-005）
//   tc_fwd_backpressure: 高背压（forward, IMPL=0, REQ-005/INV-005）
//   tc_bypass         : 组合直通（BYPASS=1, REQ-006/INV-006）
//   tc_negative_elab  : 非法参数（DATA_W/IMPL/BYPASS 越界）elaboration 拦截
//                       （执行体 verification/scripts/run_static_checks.sh，REQ-004）
// 参考模型：TB 内独立队列 inq[$]（push=接受事件、pop=输出消费事件，整体比对保序）
// 相位纪律（domain-rules §3.1.2 标准模型）：
//   驱动   : @(negedge clk) 用 NBA（<=）更新 in_valid/in_data/out_ready（下一 posedge 就绪）
//   握手判定: @(posedge clk) 沿前值（in_valid/in_ready/in_data），与 RTL 沿 t 捕获一致
//   输出观测: @(posedge clk) 沿前值（out_valid/out_data = 输出寄存级本拍可见值）
// 固定 seed: SEED=32'hCBB_2026_0828（可复现纪律）
// ============================================================================
`timescale 1ns/1ps

module skid_buffer_tb #(
    parameter int DATA_W = 32,
    parameter int IMPL   = 1,     // 0=forward / 1=full
    parameter int BYPASS = 0
);

    localparam int DW = DATA_W;
    localparam int SEED = 32'hCBB_2026_0828;
    localparam string MODE = BYPASS ? "BYPASS" : (IMPL == 0 ? "FORWARD" : "FULL");

    // ---- 信号 ----
    logic              clk;
    logic              rst_n;
    logic              in_valid;
    logic [DW-1:0]     in_data;
    logic              in_ready;
    logic              out_valid;
    logic [DW-1:0]     out_data;
    logic              out_ready;

    // ---- DUT（多实现 wrapper）----
    skid_buffer #(.DATA_W(DW), .IMPL(IMPL), .BYPASS(BYPASS)) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_data   (in_data),
        .in_ready  (in_ready),
        .out_valid (out_valid),
        .out_data  (out_data),
        .out_ready (out_ready)
    );

    // ---- 参考模型队列与统计（唯一写者：观测 always 块）----
    logic [DW-1:0] inq [$];
    int errors = 0;
    int sent = 0;      // 沿 t 接受计数（观测块写）
    int recv = 0;      // 沿 t 输出消费计数（观测块写）

    // ---- 时钟 ----
    initial clk = 1'b0;
    always #5 clk = ~clk;   // 10ns 周期

    // ---- 随机数据生成（DW 位宽截断）----
    function automatic logic [DW-1:0] rand_data();
        logic [127:0] r;
        r = { $urandom, $urandom, $urandom, $urandom };
        return DW'(r);
    endfunction

    // ---- 观测：握手判定 + 输出消费，均在 active region 用沿 t 前值 ----
    // （out_valid/out_data 为输出寄存 FF 的沿 t-1 更新值（full/forward）或组合值（BYPASS），
    //   即本拍下游可见值；相位纪律勿用 #1 读沿 t 更新后的新值造成消费错位一拍）
    always @(posedge clk) begin
        if (rst_n) begin
            // 沿 t：输入被接受（in_valid/in_ready/in_data 为沿 t 前值，与 RTL 沿 t 捕获一致）
            if (in_valid && in_ready) begin
                inq.push_back(in_data);
                sent++;
            end
            // 沿 t：输出消费（out_valid/out_data 为沿 t 前值 = 输出级本拍可见值）
            if (out_valid && out_ready) begin
                if (inq.size() == 0) begin
                    errors++;
                    $display("[FAIL] out 消费但 inq 空（多输出）@t=%0t", $time);
                end else begin
                    logic [DW-1:0] expected;
                    expected = inq.pop_front();
                    recv++;
                    if (out_data !== expected) begin
                        errors++;
                        $display("[FAIL] 保序/数据不匹配 got=%0h exp=%0h @t=%0t", out_data, expected, $time);
                    end
                end
            end
        end
    end

    // ---- drain：停输入、out_ready=1，等队列清空 ----
    task automatic drain(input int max_cyc = 96);
        int cyc = 0;
        @(negedge clk);
        in_valid <= 1'b0;
        out_ready <= 1'b1;
        while (inq.size() > 0 && cyc < max_cyc) begin
            @(negedge clk);
            cyc++;
        end
        if (inq.size() > 0) begin
            errors++;
            $display("[FAIL] drain 后 inq 仍有 %0d 项（丢数据/漏输出）", inq.size());
        end
    endtask

    // ========================================================================
    initial begin
        $display("=== skid_buffer_tb start (DATA_W=%0d IMPL=%0d BYPASS=%0d MODE=%0s, seed=%0d) ===",
                 DW, IMPL, BYPASS, MODE, SEED);

        clk = 1'b0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        out_ready = 1'b0;
        in_data = '0;
        repeat(3) @(negedge clk);          // 复位稳定
        @(negedge clk); rst_n <= 1'b1;
        @(negedge clk);

        // ---------------- tc_random / tc_fwd_random : 随机 valid/ready 流 ----------------
        begin : tc_random
            process::self.srandom(SEED);
            for (int i = 0; i < 1000; i++) begin
                @(negedge clk);
                in_valid <= (($urandom & 7) < 7);     // ~87.5% valid
                out_ready <= (($urandom & 1) == 0);   // ~50% ready（中等背压）
                in_data <= rand_data();
            end
            drain();
            $display("[tc_random] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
        end

        // ---------------- tc_backpressure / tc_fwd_backpressure : 高背压 ----------------
        begin : tc_backpressure
            process::self.srandom(SEED ^ 32'hA5A5);
            for (int i = 0; i < 800; i++) begin
                @(negedge clk);
                in_valid <= (($urandom & 7) < 7);     // ~87.5% valid
                out_ready <= (($urandom & 15) == 0);  // ~6.25% ready（强背压）
                in_data <= rand_data();
            end
            drain();
            $display("[tc_backpressure] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
        end

        // ---------------- tc_edge : 空流 / 单拍 / 连续背压 ----------------
        begin : tc_edge
            // 空流：in_valid=0 持续，输出级保持空（full/forward 输出寄存）
            @(negedge clk); in_valid <= 1'b0; out_ready <= 1'b1;
            repeat(4) @(negedge clk);
            if (!BYPASS && out_valid !== 1'b0) begin
                errors++; $display("[FAIL] 空流时 out_valid 非 0 @t=%0t", $time);
            end
            // 单拍：一个输入 → 下一拍 out_valid=1 并被消费
            @(negedge clk); in_valid <= 1'b1; in_data <= DW'(32'hDEAD_BEEF & {DW{1'b1}}); out_ready <= 1'b1;
            @(negedge clk); in_valid <= 1'b0;
            repeat(2) @(negedge clk);
            // 连续背压：out_ready=0 持续多拍，输入连续有效 → 槽吸收（full）/ready 传导（forward），恢复后按序输出
            @(negedge clk); out_ready <= 1'b0;
            for (int i = 0; i < 6; i++) begin
                @(negedge clk);
                in_valid <= 1'b1;
                in_data <= DW'(i[7:0]);
            end
            @(negedge clk); in_valid <= 1'b0;
            drain(128);
            $display("[tc_edge] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
        end

        // ---------------- tc_bypass : 组合直通（BYPASS=1 配置）----------------
        begin : tc_bypass
            // 直通：同拍 out_valid/in_valid、out_data/in_data（组合），参考模型 push/pop 同拍验证
            process::self.srandom(SEED ^ 32'hBEA7);
            for (int i = 0; i < 500; i++) begin
                @(negedge clk);
                in_valid <= (($urandom & 7) < 7);
                out_ready <= (($urandom & 3) == 0);   // ~25% ready
                in_data <= rand_data();
            end
            drain(32);
            $display("[tc_bypass] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
        end

        // ---------------- 终局判定 ----------------
        if (errors == 0)
            $display("=== SKID_BUFFER_TB PASS (%0s): all scenarios clean (sent=%0d recv=%0d) ===", MODE, sent, recv);
        else
            $display("=== SKID_BUFFER_TB FAIL (%0s): %0d mismatches (sent=%0d recv=%0d) ===", MODE, errors, sent, recv);
        $finish;
    end

    // 超时看门狗
    initial begin
        #200_000;
        $display("=== SKID_BUFFER_TB TIMEOUT ===");
        $finish;
    end

endmodule
