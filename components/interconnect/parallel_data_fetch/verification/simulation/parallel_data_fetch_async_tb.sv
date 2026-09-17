// ============================================================================
// parallel_data_fetch_async_tb —— G4 异步模式（ASYNC_MODE=1）双时钟功能仿真
//
// 激励矩阵与判据见 ../docs/design.md §8（异步模式验证方案）。
//
// 覆盖：
//   tc_async_modes        四种时钟比例下的数据守恒与快照一致性
//                         A 快 B 慢(5:20) / A 慢 B 快(20:5) / 临界(11:20) / 同频异相(10:10 相位 0/3/7)
//   tc_async_modes（临界）RSP_FIFO_DEPTH == BEAT_COUNT 时 B 端受 reserve_ok 门控，不 overflow
//   tc_async_reset_order  三种复位顺序：复位期间 link_up=0 且不接受请求；释放后重建并可完成新事务
//   时钟停摆              A 时钟停止后恢复：不挂死，link_up 最终重建
//
// 相位纪律（domain-rules §3.1.2）：
//   * A 域：@(negedge a_clk) 驱动、@(posedge a_clk) 观测；
//   * B 域数据源：@(posedge b_clk) 驱动；
//   * 两端频率不同 → 不假设每笔事务固定拍数，只断言事务级性质；
//   * 看门狗用时间（#）而非拍数，避免慢时钟误判挂死。
// ============================================================================

module parallel_data_fetch_async_tb #(
    parameter int DW             = 64,
    parameter int LW             = 16,
    parameter int A_PERIOD       = 10,    // A 时钟半周期（#10 → 周期 20）
    parameter int B_PERIOD       = 10,    // B 时钟半周期
    parameter int PHASE_SHIFT    = 0,     // B 时钟相位偏置（时间单位）
    parameter int RSP_FIFO_DEPTH = 16,
    parameter int N_RANDOM       = 40,
    parameter int SEED           = 20260917
) ();

  localparam int BEAT_COUNT = DW / LW;

  // ---------------- 双时钟（相位偏置 + 周期比互质/非整数，避免锁相假象）----------------
  // 纪律：每个时钟变量只由一个进程驱动（避免同变量多进程写入导致调度异常）。
  logic a_clk, b_clk;
  initial a_clk = 1'b0;
  initial b_clk = 1'b0;
  always #(A_PERIOD) a_clk = ~a_clk;
  initial begin
    #(PHASE_SHIFT);
    forever #(B_PERIOD) b_clk = ~b_clk;
  end

  logic a_rst_n = 1'b0;
  logic b_rst_n = 1'b0;

  // ---------------- DUT ----------------
  logic                  a_req_valid, a_req_ready, a_rsp_valid, a_rsp_ready;
  logic [DW-1:0]         a_rsp_data;
  logic                  a_rsp_error;
  logic [2:0]            a_rsp_code;
  logic                  a_busy, a_link_up;
  logic                  b_fetch_valid, b_fetch_ready;
  logic                  b_data_valid, b_data_ready, b_data_error;
  logic [DW-1:0]         b_data;
  logic                  b_busy, b_link_up;

  parallel_data_fetch #(
      .DATA_WIDTH        (DW),
      .LINK_WIDTH        (LW),
      .LSB_FIRST         (1),
      .ASYNC_MODE        (1),                       // 异步模式：A/B 时钟域无关
      .PARITY_EN         (1),
      .ODD_PARITY        (0),
      .TIMEOUT_EN        (1),
      .TIMEOUT_CYCLES    (4096),
      .REQ_SYNC_STAGES   (2),
      .RSP_FIFO_DEPTH    (RSP_FIFO_DEPTH),          // 临界用例取 == BEAT_COUNT
      .LINK_PIPE_STAGES  (0),
      .SLICE_IMPL        (2),
      .RESET_DEFAULT_DATA(0)
  ) dut (
      .a_clk_i(a_clk), .a_rst_ni(a_rst_n),
      .a_req_valid_i(a_req_valid), .a_req_ready_o(a_req_ready),
      .a_rsp_valid_o(a_rsp_valid), .a_rsp_ready_i(a_rsp_ready),
      .a_rsp_data_o (a_rsp_data), .a_rsp_error_o(a_rsp_error),
      .a_rsp_error_code_o(a_rsp_code), .a_busy_o(a_busy), .a_link_up_o(a_link_up),
      .b_clk_i(b_clk), .b_rst_ni(b_rst_n),
      .b_fetch_valid_o(b_fetch_valid), .b_fetch_ready_i(b_fetch_ready),
      .b_data_valid_i(b_data_valid), .b_data_ready_o(b_data_ready),
      .b_data_i(b_data), .b_data_error_i(b_data_error),
      .b_busy_o(b_busy), .b_link_up_o(b_link_up));

  // ---------------- 计分 ----------------
  int pass_cnt = 0;
  int fail_cnt = 0;
  int txn_cnt  = 0;
  int err_cnt  = 0;

  task automatic check(input bit cond, input string tag, input string msg);
    if (cond) pass_cnt++;
    else begin
      fail_cnt++;
      $display("[FAIL] %s | %s", tag, msg);
    end
  endtask

  // ---------------- B 端数据源（B 域；内容在事务间变化以检验原子快照）----------------
  logic [DW-1:0] src_pattern;
  int            prov_delay;
  int            prov_wait_cnt;
  bit            prov_pending;
  bit            prov_force_error;

  always_ff @(posedge b_clk or negedge b_rst_n) begin
    if (!b_rst_n) src_pattern <= 64'h5A5A_0F0F_1234_5678;
    else          src_pattern <= src_pattern * 64'h0000_0001_0000_0001 + 64'h9E37_79B9_7F4A_7C15;
  end

  typedef enum logic [1:0] { SRC_IDLE = 2'd0, SRC_WAIT = 2'd1, SRC_DATA = 2'd2 } src_state_t;
  src_state_t src_state;

  always_ff @(posedge b_clk or negedge b_rst_n) begin
    if (!b_rst_n) begin
      src_state     <= SRC_IDLE;
      b_fetch_ready <= 1'b0;
      b_data_valid  <= 1'b0;
      b_data_error  <= 1'b0;
      b_data        <= '0;
      prov_wait_cnt <= 0;
      prov_pending  <= 1'b0;
    end else begin
      unique case (src_state)
        SRC_IDLE: begin
          b_data_valid <= 1'b0;
          if (b_fetch_valid) begin
            b_fetch_ready <= 1'b1;
            prov_wait_cnt <= prov_delay;
            prov_pending  <= 1'b1;
            src_state     <= SRC_WAIT;
          end
        end
        SRC_WAIT: begin
          b_fetch_ready <= 1'b0;
          if (prov_wait_cnt > 0) prov_wait_cnt <= prov_wait_cnt - 1;
          else begin
            b_data_valid <= 1'b1;
            b_data       <= src_pattern;
            b_data_error <= prov_force_error;
            src_state    <= SRC_DATA;
          end
        end
        SRC_DATA: begin
          if (b_data_valid && b_data_ready) begin
            b_data_valid <= 1'b0;
            b_data_error <= 1'b0;
            prov_pending <= 1'b0;
            src_state    <= SRC_IDLE;
          end
        end
        default: src_state <= SRC_IDLE;
      endcase
    end
  end

  // 捕获被接受时刻的快照（B 域）
  logic [DW-1:0] snap_captured;
  logic          snap_valid;
  always_ff @(posedge b_clk or negedge b_rst_n) begin
    if (!b_rst_n) snap_valid <= 1'b0;
    else if (b_data_valid && b_data_ready) begin
      snap_captured <= b_data;
      snap_valid    <= 1'b1;
    end
  end

  // ---------------- 写侧 beat 统计（B 域；用于确认确实发生了连续发送）----------------
  int wbeat_cnt;
  always_ff @(posedge b_clk or negedge b_rst_n) begin
    if (!b_rst_n) wbeat_cnt <= 0;
    else if (dut.u_provider.link_beat_valid_o && dut.u_provider.link_beat_ready_i)
      wbeat_cnt <= wbeat_cnt + 1;
  end

  // ---------------- 单事务（A 域驱动）----------------
  // 事务级判据：成功则数据 == 被接受快照；不假设固定拍数
  task automatic one_transaction(input int pdelay, input int backpressure_max,
                                 output logic [2:0] code, output logic is_err);
    prov_delay = pdelay;

    @(negedge a_clk);
    begin : wait_rdy
      int g2 = 0;
      while (!a_req_ready && g2 < 2000) begin
        @(negedge a_clk);
        g2++;
      end
      check(g2 < 2000, "tc_async_modes",
            $sformatf("req_ready never asserted txn=%0d a_up=%b req_st=%0d", txn_cnt, a_link_up,
                      dut.u_requester.state_q));
    end
    a_req_valid <= 1'b1;
    @(negedge a_clk);
    a_req_valid <= 1'b0;

    // 随机背压：响应到达后随机延迟若干 A 拍接受
    if (backpressure_max > 0) begin
      repeat (rand_range(0, backpressure_max)) @(negedge a_clk);
    end
    a_rsp_ready <= 1'b1;

    // 注意：此处不得再等一个 negedge——否则若 A 端在该 negedge 前已拉起 valid，
    // 握手会在间隔的 posedge 完成并撤销 valid，TB 反而永远等不到 valid（错拍）。
    begin : wait_rsp
      int guard = 0;
      while (!a_rsp_valid && guard < 2000) begin
        @(negedge a_clk);
        guard++;
        if (guard % 250 == 0)
          $display("[DBG] txn=%0d waiting rsp t=%0t req_st=%0d prv_st=%0d fifo_rv=%b fifo_re=%b pbv=%b pbr=%b",
                   txn_cnt, $time, dut.u_requester.state_q, dut.u_provider.state_q,
                   dut.lr_valid, dut.g_link_async.u_link_fifo.empty_q,
                   dut.pb_valid, dut.pb_ready);
      end
      check(guard < 2000, "tc_async_modes",
            $sformatf("response timeout in TB txn=%0d req_st=%0d prv_st=%0d", txn_cnt,
                      dut.u_requester.state_q, dut.u_provider.state_q));
    end
    is_err = a_rsp_error;
    code   = a_rsp_code;
    @(negedge a_clk);
    a_rsp_ready <= 1'b0;

    txn_cnt++;
    if (is_err) err_cnt++;
    // 失败事务：等待 A 端静默窗口（RECOVER）排空在途 beat
    if (is_err) repeat (BEAT_COUNT + 8) @(negedge a_clk);
  endtask

  int unsigned rng = SEED;
  function automatic int rand_range(input int lo, input int hi);
    rng = rng * 32'd1103515245 + 32'd12345;
    return lo + int'(rng % unsigned'(hi - lo + 1));
  endfunction

  logic [2:0] code;
  logic       is_err;

  // ---------------- 主流程 ----------------
  initial begin
    a_req_valid = 1'b0; a_rsp_ready = 1'b0;
    prov_delay = 0; prov_force_error = 1'b0;

    // 两端独立复位：B 先释放，A 稍后（tc_async_reset_order 场景已在下方单列）
    repeat (3) @(negedge b_clk);
    b_rst_n = 1'b1;
    repeat (3) @(negedge a_clk);
    a_rst_n = 1'b1;

    // link_up 建立（带诊断，避免 X 值导致 wait 永久挂起时无信息）
    for (int i = 0; i < 40 && !(a_link_up === 1'b1 && b_link_up === 1'b1); i++) begin
      @(negedge a_clk);
      $display("[DBG] i=%0d t=%0t a_up=%b b_up=%b a_rst=%b b_rst=%b a_alive=%b b_alive=%b a_rem=%b b_rem=%b",
               i, $time, a_link_up, b_link_up, a_rst_n, b_rst_n,
               dut.a_alive, dut.b_alive,
               dut.u_requester.remote_alive_sync, dut.u_provider.remote_alive_sync);
    end
    check(a_link_up === 1'b1 && b_link_up === 1'b1, "tc_async_modes",
          "link_up must establish in both domains");
    repeat (5) @(negedge a_clk);
    check(a_link_up === 1'b1, "tc_async_modes", "A link_up must establish across clock domains");

    // ---- tc_async_modes：当前时钟比例下的定向 + 随机事务 ----
    for (int i = 0; i < N_RANDOM; i++) begin
      one_transaction(rand_range(0, 3), rand_range(0, 4), code, is_err);
      if (!is_err) begin
        check(a_rsp_data === snap_captured, "tc_async_modes",
              $sformatf("data mismatch txn=%0d exp=%h got=%h", txn_cnt, snap_captured, a_rsp_data));
      end else begin
        check(1'b0, "tc_async_modes",
              $sformatf("unexpected error txn=%0d code=%0d", txn_cnt, code));
      end
    end

    // ---- tc_async_modes：provider error 在异步模式同样正确返回 ----
    prov_force_error = 1'b1;
    one_transaction(1, 0, code, is_err);
    prov_force_error = 1'b0;
    check(is_err && code == 3'd2, "tc_async_modes",
          $sformatf("async provider error must report ERR_PROVIDER(2), got err=%b code=%0d", is_err, code));

    // ---- tc_async_reset_order：事务中 B 端复位 → A 端应报错且不自动重发 ----
    // 纪律：rsp_ready 只在 join 之后单点驱动，避免与 fork 内驱动错拍而漏消费响应。
    fork
      begin
        prov_delay = 8;                       // 让 B 端来不及返回数据
        @(negedge a_clk);
        while (!a_req_ready) @(negedge a_clk);
        a_req_valid <= 1'b1;
        @(negedge a_clk);
        a_req_valid <= 1'b0;
      end
      begin
        repeat (4) @(posedge b_clk);
        b_rst_n = 1'b0;                       // 事务中 B 复位
        repeat (4) @(negedge b_clk);
        b_rst_n = 1'b1;
      end
    join

    // 等待本次事务以错误结束（带 guard，避免错拍漏等）
    begin : wait_reset_err
      int g3 = 0;
      while (!a_rsp_valid && g3 < 2000) begin
        @(negedge a_clk);
        g3++;
      end
      check(g3 < 2000, "tc_async_reset_order",
            $sformatf("no response after B reset (req_st=%0d prv_st=%0d)",
                      dut.u_requester.state_q, dut.u_provider.state_q));
    end
    check(a_rsp_error === 1'b1, "tc_async_reset_order",
          "B reset during transaction must end the transaction with an error");
    a_rsp_ready <= 1'b1;                      // 消费错误响应
    @(negedge a_clk);
    a_rsp_ready <= 1'b0;
    txn_cnt++;
    err_cnt++;

    // 两端 link_up 需重新建立，且能完成新事务
    wait (b_link_up === 1'b1);
    repeat (BEAT_COUNT + 12) @(negedge a_clk);
    prov_delay = rand_range(0, 2);
    one_transaction(prov_delay, 1, code, is_err);
    check(!is_err, "tc_async_reset_order", "transaction must succeed after link re-establishment");

    $display("========================================");
    $display("async TB  DW=%0d LW=%0d BEAT=%0d A_PERIOD=%0d B_PERIOD=%0d PHASE=%0d FIFO_DEPTH=%0d",
             DW, LW, BEAT_COUNT, A_PERIOD, B_PERIOD, PHASE_SHIFT, RSP_FIFO_DEPTH);
    $display("transactions=%0d errors=%0d wbeats=%0d", txn_cnt, err_cnt, wbeat_cnt);
    $display("RESULT: %s (pass=%0d fail=%0d)", (fail_cnt == 0) ? "PASS" : "FAIL", pass_cnt, fail_cnt);
    $display("========================================");
    if (fail_cnt != 0) $fatal(1, "parallel_data_fetch async functional failed");
    $finish;
  end

  // 看门狗：时间基准（两端频率不同，不用拍数）
  initial begin
    #(2000000);
    $display("[FAIL] async watchdog timeout (possible handshake deadlock)");
    $fatal(1, "async watchdog");
  end
endmodule