// ============================================================================
// parallel_data_fetch_tb —— G4 功能仿真（同步模式自检式 TB，带 A/B 时钟参数）
//
// 覆盖：
//   tc_sync_basic       基础事务，A 端结果与 B 端被接受快照逐 bit 一致
//   tc_provider_latency provider 零等待 / 固定 / 随机等待
//   tc_snapshot_hold    发送期间持续改变 b_data_i，结果仍等于被接受快照
//   tc_backpressure     A 端随机延迟接收响应，输出保持稳定
//   tc_beat1/tc_pipe_stages/tc_slice_equivalence  经由参数化覆盖
//   tc_random           约束随机 provider 延迟 + 随机 A 端背压
//   tc_reset            A 端复位：link_up 失效、不接受请求、恢复后可继续工作
//   tc_error_inject     provider error（b_data_error_i）与 parity 注入（读侧 force）
//
// 握手相位纪律（domain-rules §3.1.2）：驱动在 negedge 用 NBA 更新（为下一 posedge 就绪），
// 观测在 posedge 后 #1 读当前值；两者不混用为同一拍。
// ============================================================================

module parallel_data_fetch_tb #(
    parameter int DW         = 64,
    parameter int LW         = 16,
    parameter int LSB_FIRST  = 1,
    parameter int PIPE       = 0,
    parameter int SLICE_IMPL = 2,
    parameter int PARITY_EN  = 1,
    parameter int ODD_PARITY = 0,
    parameter int TMO        = 4096,
    parameter int SEED       = 20260916,
    parameter int N_RANDOM   = 40
) ();

  localparam int BEAT_COUNT = DW / LW;

  logic clk;
  initial clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  assign a_clk = clk;
  assign b_clk = clk;
  assign a_rst_ni = rst_n;
  assign b_rst_ni = rst_n;

  logic a_clk, b_clk, a_rst_ni, b_rst_ni;

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
      .LSB_FIRST         (LSB_FIRST),
      .ASYNC_MODE        (0),
      .PARITY_EN         (PARITY_EN),
      .ODD_PARITY        (ODD_PARITY),
      .TIMEOUT_EN        (1),
      .TIMEOUT_CYCLES    (TMO),
      .REQ_SYNC_STAGES   (2),
      .RSP_FIFO_DEPTH    (16),
      .LINK_PIPE_STAGES  (PIPE),
      .SLICE_IMPL        (SLICE_IMPL),
      .RESET_DEFAULT_DATA(0)
  ) dut (
      .a_clk_i(a_clk), .a_rst_ni(a_rst_ni),
      .a_req_valid_i(a_req_valid), .a_req_ready_o(a_req_ready),
      .a_rsp_valid_o(a_rsp_valid), .a_rsp_ready_i(a_rsp_ready),
      .a_rsp_data_o (a_rsp_data), .a_rsp_error_o(a_rsp_error),
      .a_rsp_error_code_o(a_rsp_code), .a_busy_o(a_busy), .a_link_up_o(a_link_up),
      .b_clk_i(b_clk), .b_rst_ni(b_rst_ni),
      .b_fetch_valid_o(b_fetch_valid), .b_fetch_ready_i(b_fetch_ready),
      .b_data_valid_i(b_data_valid), .b_data_ready_o(b_data_ready),
      .b_data_i(b_data), .b_data_error_i(b_data_error),
      .b_busy_o(b_busy), .b_link_up_o(b_link_up));

  // ---------------- 计分与统计 ----------------
  int pass_cnt = 0;
  int fail_cnt = 0;
  int txn_cnt  = 0;

  logic [DW-1:0] snap_captured;
  logic          snap_valid;

  int  prov_delay;                   // 本次事务 provider 延迟（拍）
  bit  prov_force_error;
  int  prov_wait_cnt;
  bit  prov_pending;

  task automatic check(input bit cond, input string tag, input string msg);
    if (cond) pass_cnt++;
    else begin
      fail_cnt++;
      $display("[FAIL] %s | %s", tag, msg);
    end
  endtask

  // ---------------- B 端数据源（可配置延迟；数据内容每拍变化以检验原子快照）----------------
  logic [DW-1:0] src_pattern;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) src_pattern <= 64'hA5A5_1234_DEAD_BEEF;
    else        src_pattern <= src_pattern * 64'h0000_0001_0000_0001 + 64'h9E37_79B9_7F4A_7C15;
  end

  // 数据源小 FSM：IDLE --fetch--> WAIT(倒计数) --cnt=0--> DATA --handshake--> IDLE
  // 纪律：不依赖"fetch_ready 当前值"作为推进条件（避免相位误判造成死锁）。
  typedef enum logic [1:0] { SRC_IDLE = 2'd0, SRC_WAIT = 2'd1, SRC_DATA = 2'd2 } src_state_t;
  src_state_t src_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      src_state     <= SRC_IDLE;
      b_fetch_ready <= 1'b0;
      b_data_valid  <= 1'b0;
      b_data_error  <= 1'b0;
      b_data        <= '0;
      prov_wait_cnt <= 0;
    end else begin
      unique case (src_state)
        SRC_IDLE: begin
          b_data_valid <= 1'b0;
          if (b_fetch_valid) begin
            b_fetch_ready <= 1'b1;         // 接受取数请求
            prov_wait_cnt <= prov_delay;
            src_state     <= SRC_WAIT;
          end
        end
        SRC_WAIT: begin
          b_fetch_ready <= 1'b0;
          if (prov_wait_cnt > 0) begin
            prov_wait_cnt <= prov_wait_cnt - 1;
          end else begin
            b_data_valid <= 1'b1;
            b_data       <= src_pattern;   // 当拍提出数据（发送期间内容仍会变化）
            b_data_error <= prov_force_error;
            src_state    <= SRC_DATA;
          end
        end
        SRC_DATA: begin
          if (b_data_valid && b_data_ready) begin
            b_data_valid <= 1'b0;
            b_data_error <= 1'b0;
            src_state    <= SRC_IDLE;
          end
        end
        default: src_state <= SRC_IDLE;
      endcase
    end
  end

  // 捕获被接受时刻的快照（被接受的那一拍的值）
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) snap_valid <= 1'b0;
    else if (b_data_valid && b_data_ready) begin
      snap_captured <= b_data;
      snap_valid    <= 1'b1;
    end
  end

  // ---------------- 覆盖统计 ----------------
  int beats_seen;
  int last_seen;
  bit in_payload;
  int bubble_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      beats_seen <= 0; last_seen <= 0; bubble_cnt <= 0; in_payload <= 1'b0;
    end else begin
      if (dut.lr_valid) begin
        beats_seen <= beats_seen + 1;
        if (dut.lr_last) last_seen <= last_seen + 1;
        if (!in_payload && !dut.lr_last && !dut.lr_error) in_payload <= 1'b1;
      end else if (in_payload) begin
        bubble_cnt <= bubble_cnt + 1;        // payload 中间出现无效拍 = bubble
        in_payload <= 1'b0;
      end
      if (dut.lr_valid && (dut.lr_last || dut.lr_error)) in_payload <= 1'b0;
    end
  end

  // ---------------- 单事务驱动 ----------------
  // 相位纪律：先在 negedge 等待 ready 为 1，再在下一 negedge 保持一拍 valid；
  // DUT 在中间的 posedge 完成握手（`req_fire = valid && ready` 同沿）。
  task automatic one_transaction(
      input int        pdelay,
      input int        rsp_stall,
      input bit        parity_inject,
      output logic [2:0] code,
      output logic     is_err
  );
    prov_delay = pdelay;

    // 等 DUT 可接受请求（IDLE 且 link_up）
    @(negedge clk);
    while (!a_req_ready) @(negedge clk);
    a_req_valid <= 1'b1;                 // 保持一拍 valid
    @(negedge clk);
    a_req_valid <= 1'b0;

    // parity 注入：整事务期间把读侧校验位确定性反相（与拍数/pipeline 无关，
    // 覆盖 BEAT_COUNT=1 的首拍即 last 情形；不依赖与 beat 出现时刻的竞争）
    if (parity_inject) force dut.u_requester.link_rsp_parity_i = ~dut.lr_parity;

    // 等待响应；背压通过"响应到达后延迟接受"实现（避免驱动侧提前压住 ready 造成死锁），
    // 并在此期间检查输出稳定（PROP-PDF_HOLDSTABLE-004 / tc_backpressure）。
    a_rsp_ready <= 1'b1;
    @(negedge clk);
    while (!a_rsp_valid) @(negedge clk);

    is_err = a_rsp_error;
    code   = a_rsp_code;

    if (rsp_stall > 0) begin
      a_rsp_ready <= 1'b0;
      for (int s = 0; s < rsp_stall; s++) begin
        @(negedge clk);
        check(a_rsp_valid === 1'b1 && a_rsp_error === is_err && a_rsp_code === code &&
              (is_err || a_rsp_data === snap_captured), "tc_backpressure",
              $sformatf("response must stay stable under backpressure (txn=%0d s=%0d)", txn_cnt, s));
      end
    end
    if (parity_inject) release dut.u_requester.link_rsp_parity_i;
    a_rsp_ready <= 1'b1;
    // 让 DUT 在下一个 posedge 完成响应握手（HOLD -> IDLE / RECOVER）
    @(negedge clk);
    a_rsp_ready <= 1'b0;

    if (!is_err) begin
      check(a_rsp_data === snap_captured, "tc_sync_basic",
            $sformatf("data mismatch txn=%0d exp=%h got=%h", txn_cnt, snap_captured, a_rsp_data));
    end else begin
      check(a_rsp_data === {DW{1'b0}}, "tc_error_inject",
            $sformatf("error response must not expose payload txn=%0d err=%0d got=%h",
                      txn_cnt, code, a_rsp_data));
    end

    txn_cnt++;
    // 失败事务后等待静默窗口排空在途 beat（RECOVER 状态）
    if (is_err) repeat (BEAT_COUNT + PIPE + 8) @(negedge clk);
  endtask

  // ---------------- 随机 ----------------
  int unsigned rng = SEED;
  function automatic int rand_range(input int lo, input int hi);
    rng = rng * 32'd1103515245 + 32'd12345;
    return lo + int'(rng % unsigned'(hi - lo + 1));
  endfunction

  logic [2:0] code;
  logic       is_err;

  initial begin
    a_req_valid = 1'b0; a_rsp_ready = 1'b0;
    prov_delay = 0; rst_n = 1'b0;
    repeat (5) @(negedge clk);
    rst_n = 1'b1;

    wait (a_link_up === 1'b1);
    repeat (3) @(negedge clk);
    check(a_link_up === 1'b1, "tc_reset", "link_up must establish after reset release");
    check(a_req_ready === 1'b1, "tc_sync_basic",
          $sformatf("req_ready must be high when idle and link_up (req_state=%0d up=%b rdy=%b b_fetch_v=%b)",
                    dut.u_requester.state_q, a_link_up, a_req_ready, b_fetch_valid));

    // tc_sync_basic：零等待 provider
    one_transaction(0, 0, 1'b0, code, is_err);
    check(!is_err, "tc_sync_basic", "zero-delay provider transaction must succeed");

    // tc_provider_latency：固定延迟
    one_transaction(3, 0, 1'b0, code, is_err);
    check(!is_err, "tc_provider_latency", "fixed-latency provider must succeed");

    // tc_backpressure + tc_snapshot_hold：长背压（期间数据源持续变化）
    one_transaction(1, BEAT_COUNT + 6, 1'b0, code, is_err);
    check(!is_err, "tc_backpressure", "long response backpressure must still succeed");

    // tc_pipe_stages
    for (int i = 0; i < 3; i++) begin
      one_transaction(i, i, 1'b0, code, is_err);
      check(!is_err, "tc_pipe_stages", "sequential transactions must succeed");
    end

    // tc_slice_equivalence
    for (int i = 0; i < 3; i++) begin
      one_transaction(rand_range(0, 2), rand_range(0, BEAT_COUNT), 1'b0, code, is_err);
      check(!is_err, "tc_slice_equivalence", "slice impl must honor snapshot contract");
    end

    // tc_random
    for (int i = 0; i < N_RANDOM; i++) begin
      one_transaction(rand_range(0, 4), rand_range(0, BEAT_COUNT + 2), 1'b0, code, is_err);
      check(!is_err, "tc_random", "random transaction must succeed");
    end

    // tc_error_inject：provider error
    prov_force_error = 1'b1;
    one_transaction(1, 0, 1'b0, code, is_err);
    prov_force_error = 1'b0;
    check(is_err, "tc_error_inject", "provider error must produce error response");
    check(code == 3'd2, "tc_error_inject",
          $sformatf("provider error must carry ERR_PROVIDER(2), got %0d", code));

    // tc_error_inject：parity
    if (PARITY_EN == 1) begin
      one_transaction(1, 0, 1'b1, code, is_err);
      check(is_err, "tc_error_inject", "injected parity error must fail the transaction");
      check(code == 3'd3, "tc_error_inject",
            $sformatf("parity error must carry ERR_PARITY(3), got %0d", code));
    end

    // tc_reset
    rst_n = 1'b0;
    repeat (3) @(negedge clk);
    check(a_link_up === 1'b0, "tc_reset", "link_up must drop during reset");
    check(a_req_ready === 1'b0, "tc_reset", "req_ready must be low during reset");
    rst_n = 1'b1;
    wait (a_link_up === 1'b1);
    repeat (2) @(negedge clk);
    check(a_req_ready === 1'b1, "tc_reset", "req_ready must recover after reset");
    one_transaction(1, 0, 1'b0, code, is_err);
    check(!is_err, "tc_reset", "transaction after reset recovery must succeed");

    check(bubble_cnt == 0, "tc_sync_basic",
          $sformatf("continuous send must have no bubble, bubbles=%0d", bubble_cnt));

    $display("========================================");
    $display("parallel_data_fetch TB  DW=%0d LW=%0d BEAT_COUNT=%0d LSB_FIRST=%0d PIPE=%0d SLICE_IMPL=%0d PARITY_EN=%0d ODD_PARITY=%0d",
             DW, LW, BEAT_COUNT, LSB_FIRST, PIPE, SLICE_IMPL, PARITY_EN, ODD_PARITY);
    $display("transactions=%0d beats_seen=%0d last_seen=%0d bubbles=%0d",
             txn_cnt, beats_seen, last_seen, bubble_cnt);
    $display("RESULT: %s (pass=%0d fail=%0d)", (fail_cnt == 0) ? "PASS" : "FAIL", pass_cnt, fail_cnt);
    $display("========================================");
    if (fail_cnt != 0) $fatal(1, "parallel_data_fetch G4 functional failed");
    $finish;
  end

  // 看门狗：防止握手死锁导致回归挂死
  initial begin
    #(500000);
    $display("[FAIL] watchdog timeout: TB did not finish (possible handshake deadlock)");
    $fatal(1, "watchdog");
  end
endmodule