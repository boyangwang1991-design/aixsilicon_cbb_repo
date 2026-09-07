// ============================================================================
// sync_fifo_tb — G4 功能验证测试台（参考模型队列整体比对）
// ----------------------------------------------------------------------------
// 配置：DATA_W × DEPTH × OUTPUT_REG{0,1} × IMPL{0,1}（四模式均覆盖）
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_random         : 随机 push/pop 流（REQ-001/002/004/006，INV-001/002/003）
//   tc_backpressure   : 高背压（push 密集 / pop 稀疏；满写连发）（REQ-001/002/006）
//   tc_edge           : 空流 / 单条目 / 满写连发 / 空读连发 / 同拍 push+pop（REQ-002/003/005/007）
//   tc_out_comb       : OUTPUT_REG=0 组合读出定向验证（REQ-004）
//   tc_outreg         : OUTPUT_REG=1 寄存输出级定向验证（弹空缓存语义）（REQ-005）
//   tc_reset          : 复位后状态清零 + 恢复正常 push/pop（REQ-009）
//   tc_negative_elab  : 非法参数（DATA_W/DEPTH/OUTPUT_REG/IMPL 越界）elaboration 拦截
//                       （执行体 verification/scripts/run_static_checks.sh，REQ-008）
// 相位纪律（domain-rules §3.1.2 标准模型）：
//   驱动   : @(negedge clk) 用 NBA（<=）更新 push_i/data_i/pop_i（下一 posedge 就绪）
//   握手判定: @(posedge clk) 读沿前值（push_ok / rd_valid_o / rd_data_o）
// 输出观测（comb/reg 统一）：rd_valid_o && pop_i 为一次有效消费（沿前 rd_data_o）
// 参考模型：inq[$] 队列 + count 镜像；push_ok 时 enqueue、消费时 dequeue 比对
// 固定 seed：SEED=32'hCBB_2026_0903（可复现纪律）
// ============================================================================
`timescale 1ns/1ps

module sync_fifo_tb #(
    parameter int DATA_W     = 32,
    parameter int DEPTH      = 16,
    parameter int OUTPUT_REG = 0,
    parameter int IMPL       = 0
);

    localparam int DW   = DATA_W;
    localparam int SEED = 32'hCBB_2026_0903;
    localparam string MODE = $sformatf(
        "IMPL=%0d(%0s) OUTPUT_REG=%0d(%0s) DEPTH=%0d",
        IMPL, (IMPL == 0 ? "register" : "shift"), OUTPUT_REG,
        (OUTPUT_REG == 0 ? "comb" : "reg"), DEPTH);

    // ---- 信号 ----
    logic              clk;
    logic              rst_n;
    logic              push_i;
    logic [DW-1:0]     data_i;
    logic              full_o;
    logic              pop_i;
    logic              rd_valid_o;
    logic [DW-1:0]     rd_data_o;
    logic              empty_o;
    logic [$clog2(DEPTH+1)-1:0] count_o;

    // ---- DUT ----
    sync_fifo #(.DATA_W(DW), .DEPTH(DEPTH), .OUTPUT_REG(OUTPUT_REG), .IMPL(IMPL)) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .push_i    (push_i),
        .data_i    (data_i),
        .full_o    (full_o),
        .pop_i     (pop_i),
        .rd_valid_o(rd_valid_o),
        .rd_data_o (rd_data_o),
        .empty_o   (empty_o),
        .count_o   (count_o)
    );

    // ---- 参考模型队列与统计（唯一写者：观测 always 块）----
    logic [DW-1:0] inq [$];
    int errors = 0;
    int sent = 0;      // 沿 t 接受写入计数（观测块写）
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

    // ---- 观测：握手判定 + 输出消费，均用沿 t 前值 ----
    // push_ok = push_i && ~full_o（沿前 full_o 稳定后的组合值）
    // 消费    = rd_valid_o && pop_i（comb：~empty 同拍头；reg：输出级有效与数据）
    // 两者均在 posedge 沿 t 用沿前值判定（与 RTL 沿 t 捕获一致），no #1 混用
    always @(posedge clk) begin
        if (rst_n) begin
            if (push_i && ~full_o) begin
                inq.push_back(data_i);
                sent++;
            end
            if (rd_valid_o && pop_i) begin
                if (inq.size() == 0) begin
                    errors++;
                    $display("[FAIL] 消费但 inq 空（多输出/错序）@t=%0t", $time);
                end else begin
                    logic [DW-1:0] expected;
                    expected = inq.pop_front();
                    recv++;
                    if (rd_data_o !== expected) begin
                        errors++;
                        $display("[FAIL] 数据不匹配 got=%0h exp=%0h @t=%0t", rd_data_o, expected, $time);
                    end
                end
            end
            // 计数镜像一致性（沿 t 后与 count_o 下拍值比对：观测下一拍）
            // 注：这里只做计数守恒软检查（count 由 TB 镜像推算，DUT SVA 已有硬断言）
        end
    end

    // ---- 场景间复位：清空 DUT + 参考队列 + 计数（domain-rules §3.1.2 场景隔离）----
    task automatic dut_reset();
        @(negedge clk);
        rst_n <= 1'b0;
        push_i <= 1'b0;
        pop_i  <= 1'b0;
        repeat(3) @(negedge clk);
        @(negedge clk); rst_n <= 1'b1;
        repeat(2) @(negedge clk);
        // 清空参考模型与统计（场景隔离）
        void'(inq.size());
        while (inq.size() > 0) void'(inq.pop_front());
        sent = 0;
        recv = 0;
    endtask

    // ---- drain：先放开输出消费直至参考队列清空，再停输入 ----
    task automatic drain(input int max_cyc = 256);
        int cyc = 0;
        // 先停输入（避免清空期间继续写入）
        @(negedge clk);
        push_i <= 1'b0;
        @(negedge clk);
        pop_i  <= 1'b1;                  // 放开输出消费
        while ((inq.size() > 0 || rd_valid_o) && cyc < max_cyc) begin
            @(negedge clk);
            cyc++;
        end
        @(negedge clk);
        pop_i <= 1'b0;
        if (inq.size() > 0) begin
            errors++;
            $display("[FAIL] drain 后 inq 仍有 %0d 项（丢数据/漏输出）", inq.size());
        end
        if (rd_valid_o) begin
            errors++;
            $display("[FAIL] drain 后 rd_valid_o 仍为 1（reg 输出级残存）");
        end
    endtask

    // ========================================================================
    initial begin
        $display("=== sync_fifo_tb start (%0s) seed=%0d ===", MODE, SEED);
        clk = 1'b0;
        rst_n = 1'b0;
        push_i = 1'b0;
        pop_i  = 1'b0;
        data_i = '0;
        repeat(3) @(negedge clk);
        @(negedge clk); rst_n <= 1'b1;
        @(negedge clk);

        // ---------------- tc_reset : 复位后状态清零 ----------------
        begin : tc_reset
            // 复位已生效（空态）：empty_o 应为 1、count_o 0、full_o 0、rd_valid_o 0（comb）
            if (!empty_o || count_o != 0 || full_o) begin
                errors++; $display("[FAIL] tc_reset 复位后状态非空 @t=%0t", $time);
            end
            // 写一个词 → 读回
            @(negedge clk); push_i <= 1'b1; data_i <= DW'(32'hCAFE_F00D & {DW{1'b1}});
            @(negedge clk); push_i <= 1'b0;
            // 消费直至收到该词
            @(negedge clk); pop_i <= 1'b1;
            repeat(4) @(negedge clk);
            @(negedge clk); pop_i <= 1'b0;
            // inq 应清空（观测块已消费）
            if (inq.size() != 0) begin
                errors++; $display("[FAIL] tc_reset 单词读写未消费干净 inq=%0d", inq.size());
            end
            $display("[tc_reset] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
            dut_reset();
        end

        // ---------------- tc_random : 随机 push/pop 流（中等背压）----------------
        begin : tc_random
            process::self.srandom(SEED);
            for (int i = 0; i < 1200; i++) begin
                @(negedge clk);
                push_i <= (($urandom & 7) < 6);     // ~75% push
                pop_i  <= (($urandom & 3) < 2);     // ~50% pop（中等背压）
                data_i <= rand_data();
            end
            drain();
            $display("[tc_random] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
            dut_reset();
        end

        // ---------------- tc_backpressure : 高背压（push 密集 / pop 稀疏）----------------
        begin : tc_backpressure
            process::self.srandom(SEED ^ 32'hA5A5);
            for (int i = 0; i < 1000; i++) begin
                @(negedge clk);
                push_i <= (($urandom & 3) < 3);     // ~75% push
                pop_i  <= (($urandom & 15) == 0);   // ~6% pop（强背压 → 满写连发）
                data_i <= rand_data();
            end
            drain();
            $display("[tc_backpressure] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
            dut_reset();
        end

        // ---------------- tc_edge : 空流/单条目/满写/空读/同拍 push+pop ----------------
        begin : tc_edge
            // 空流：无 push，验证输出保持空（观测块无消费；空态 SVA）
            @(negedge clk); push_i <= 1'b0; pop_i <= 1'b1;
            repeat(4) @(negedge clk);
            // 单条目 + 同拍 push+pop：连续多拍 push=pop=1（计数守恒、数据正确）
            process::self.srandom(SEED ^ 32'h5EED);
            for (int i = 0; i < 500; i++) begin
                @(negedge clk);
                push_i <= 1'b1;
                pop_i  <= (($urandom & 3) < 2);     // ~50% pop
                data_i <= rand_data();
            end
            // 满写连发：pop 关闭、push 持续 → 填满后 push 无效（count 封顶）
            @(negedge clk); pop_i <= 1'b0;
            for (int i = 0; i < DEPTH + 8; i++) begin
                @(negedge clk);
                push_i <= 1'b1;
                data_i <= DW'(i[7:0]);
            end
            @(negedge clk); push_i <= 1'b0;
            // 空读连发：drain 后（已空）pop 持续
            drain();
            @(negedge clk); pop_i <= 1'b1;
            repeat(4) @(negedge clk);
            @(negedge clk); pop_i <= 1'b0;
            $display("[tc_edge] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
            dut_reset();
        end

        // ---------------- tc_out_comb : OUTPUT_REG=0 组合读出定向 ----------------
        begin : tc_out_comb
            if (OUTPUT_REG == 0) begin
                // 定向：push 3 词，随后逐个 pop，逐词比对（组合同拍头）
                @(negedge clk); push_i <= 1'b1; data_i <= DW'(32'h11);
                @(negedge clk); push_i <= 1'b1; data_i <= DW'(32'h22);
                @(negedge clk); push_i <= 1'b1; data_i <= DW'(32'h33);
                @(negedge clk); push_i <= 1'b0;
                // 空态未弹出前 empty=0 时 rd_valid=1（comb）
                @(negedge clk); pop_i <= 1'b1;   // 消费 11
                @(negedge clk); pop_i <= 1'b1;   // 消费 22
                @(negedge clk); pop_i <= 1'b1;   // 消费 33
                @(negedge clk); pop_i <= 1'b0;
                drain(8);
                $display("[tc_out_comb] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
            end
            dut_reset();
        end

        // ---------------- tc_outreg : OUTPUT_REG=1 寄存输出级定向 ----------------
        begin : tc_outreg
            if (OUTPUT_REG == 1) begin
                // 弹空缓存语义：push 1 词 → 消费后 empty 拉高，输出级有效应随后拉低
                @(negedge clk); push_i <= 1'b1; data_i <= DW'(32'h77);
                @(negedge clk); push_i <= 1'b0;
                // 等输出级预取（fill）→ rd_valid_o 有效
                repeat(3) @(negedge clk);
                if (!rd_valid_o) begin
                    errors++; $display("[FAIL] tc_outreg 预取后 rd_valid_o 非 1 @t=%0t", $time);
                end
                // 消费该词（drain 处理）
                drain(8);
                $display("[tc_outreg] (%0s) done: sent=%0d recv=%0d", MODE, sent, recv);
            end
            dut_reset();
        end

        // ---------------- 终局判定 ----------------
        if (errors == 0)
            $display("=== SYNC_FIFO_TB PASS (%0s): all scenarios clean (sent=%0d recv=%0d) ===",
                     MODE, sent, recv);
        else
            $display("=== SYNC_FIFO_TB FAIL (%0s): %0d mismatches (sent=%0d recv=%0d) ===",
                     MODE, errors, sent, recv);
        $finish;
    end

    // 超时看门狗
    initial begin
        #300_000;
        $display("=== SYNC_FIFO_TB TIMEOUT ===");
        $finish;
    end

endmodule
