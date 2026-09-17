// ============================================================================
// config_matrix_tb —— G5 配置空间验证（逐配置 RTL 仿真）
//
// 目的：对 config-gen 生成的代表配置逐点编译/仿真，验证
//   (1) 该参数组合可 elaboration；
//   (2) 在固定 seed 下完成一笔端到端事务且数据守恒（A 端结果 == B 端被接受快照）；
//   (3) 同步模式下连续发送无 bubble、last 唯一。
//
// 与 G4 TB 的关系：G4 是深度功能矩阵（同族多激励）；本 TB 是**广度**矩阵——
// 只用一笔确定性事务换取"每个代表配置都能正确工作"，失败打印 CONFIG_FAIL 供脚本判定。
//
// 编译期参数（由 run_config_matrix_sim.sh 以 +define+ 注入）：
//   DW, LW, LSB_FIRST, ASYNC_MODE, PARITY_EN, ODD_PARITY, TIMEOUT_EN, TIMEOUT_CYCLES,
//   REQ_SYNC_STAGES, RSP_FIFO_DEPTH, LINK_PIPE_STAGES, SLICE_IMPL, RESET_DEFAULT_DATA
// 异步模式（ASYNC_MODE=1）下 A/B 使用不同半周期（CLK_A/CLK_B）。
// ============================================================================

`ifndef DW
  `define DW 64
`endif
`ifndef LW
  `define LW 16
`endif
`ifndef LSB_FIRST
  `define LSB_FIRST 1
`endif
`ifndef ASYNC_MODE
  `define ASYNC_MODE 0
`endif
`ifndef PARITY_EN
  `define PARITY_EN 1
`endif
`ifndef ODD_PARITY
  `define ODD_PARITY 0
`endif
`ifndef TIMEOUT_EN
  `define TIMEOUT_EN 1
`endif
`ifndef TIMEOUT_CYCLES
  `define TIMEOUT_CYCLES 4096
`endif
`ifndef REQ_SYNC_STAGES
  `define REQ_SYNC_STAGES 2
`endif
`ifndef RSP_FIFO_DEPTH
  `define RSP_FIFO_DEPTH 16
`endif
`ifndef LINK_PIPE_STAGES
  `define LINK_PIPE_STAGES 0
`endif
`ifndef SLICE_IMPL
  `define SLICE_IMPL 2
`endif
`ifndef RESET_DEFAULT_DATA
  `define RESET_DEFAULT_DATA 0
`endif
`ifndef CLK_A
  `define CLK_A 5
`endif
`ifndef CLK_B
  `define CLK_B 5
`endif

module config_matrix_tb ();
  localparam int DW          = `DW;
  localparam int LW          = `LW;
  localparam int BEAT_COUNT  = DW / LW;
  localparam bit ASYNC       = (`ASYNC_MODE == 1);

  // ---------------- 时钟（异步时使用不同半周期，避免锁相假象）----------------
  logic a_clk, b_clk;
  initial a_clk = 1'b0;
  initial b_clk = 1'b0;
  always #(`CLK_A) a_clk = ~a_clk;
  always #(`CLK_B) b_clk = ~b_clk;

  logic a_rst_n = 1'b0;
  logic b_rst_n = 1'b0;

  // ---------------- DUT ----------------
  logic                    a_req_valid, a_req_ready, a_rsp_valid, a_rsp_ready;
  logic [DW-1:0]           a_rsp_data;
  logic                    a_rsp_error;
  logic [2:0]              a_rsp_code;
  logic                    a_busy, a_link_up;
  logic                    b_fetch_valid, b_fetch_ready;
  logic                    b_data_valid, b_data_ready, b_data_error;
  logic [DW-1:0]           b_data;
  logic                    b_busy, b_link_up;

  parallel_data_fetch #(
      .DATA_WIDTH        (DW),
      .LINK_WIDTH        (LW),
      .LSB_FIRST         (`LSB_FIRST),
      .ASYNC_MODE        (`ASYNC_MODE),
      .PARITY_EN         (`PARITY_EN),
      .ODD_PARITY        (`ODD_PARITY),
      .TIMEOUT_EN        (`TIMEOUT_EN),
      .TIMEOUT_CYCLES    (`TIMEOUT_CYCLES),
      .REQ_SYNC_STAGES   (`REQ_SYNC_STAGES),
      .RSP_FIFO_DEPTH    (`RSP_FIFO_DEPTH),
      .LINK_PIPE_STAGES  (`LINK_PIPE_STAGES),
      .SLICE_IMPL        (`SLICE_IMPL),
      .RESET_DEFAULT_DATA(`RESET_DEFAULT_DATA)
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

  // ---------------- 自检 ----------------
  int  fail_cnt = 0;
  task automatic ck(input bit cond, input string msg);
    if (!cond) begin
      fail_cnt++;
      $display("[FAIL] %s", msg);
    end
  endtask

  // ---------------- B 端数据源（B 域；固定图案，含交替位以便检出 bit 置换）----------------
  logic [DW-1:0] src_data;
  int   prov_delay;
  int   prov_cnt;
  bit   prov_pend;
  typedef enum logic [1:0] { S_IDLE = 2'd0, S_WAIT = 2'd1, S_DATA = 2'd2 } st_t;
  st_t  st;

  initial begin
    prov_delay = 1;
    src_data   = {DW{1'b0}} | DW'(64'hA5A5_5A5A_0F0F_F0F0);
  end

  always_ff @(posedge b_clk or negedge b_rst_n) begin
    if (!b_rst_n) begin
      st            <= S_IDLE;
      b_fetch_ready <= 1'b0;
      b_data_valid  <= 1'b0;
      b_data_error  <= 1'b0;
      b_data        <= '0;
      prov_cnt      <= 0;
      prov_pend     <= 1'b0;
    end else begin
      unique case (st)
        S_IDLE: begin
          b_data_valid <= 1'b0;
          if (b_fetch_valid) begin
            b_fetch_ready <= 1'b1;
            prov_cnt      <= prov_delay;
            prov_pend     <= 1'b1;
            st            <= S_WAIT;
          end
        end
        S_WAIT: begin
          b_fetch_ready <= 1'b0;
          if (prov_cnt > 0) prov_cnt <= prov_cnt - 1;
          else begin
            b_data_valid <= 1'b1;
            b_data       <= src_data;
            b_data_error <= 1'b0;
            st           <= S_DATA;
          end
        end
        S_DATA: begin
          if (b_data_valid && b_data_ready) begin
            b_data_valid <= 1'b0;
            prov_pend    <= 1'b0;
            st           <= S_IDLE;
          end
        end
        default: st <= S_IDLE;
      endcase
    end
  end

  // 捕获被接受时刻快照
  logic [DW-1:0] snap;
  always_ff @(posedge b_clk or negedge b_rst_n) begin
    if (!b_rst_n) ;
    else if (b_data_valid && b_data_ready) snap <= b_data;
  end

  // 同步模式无 bubble / last 唯一自检
  int  beats, lasts, bubbles;
  bit  in_pay;
  always_ff @(posedge a_clk or negedge a_rst_n) begin
    if (!a_rst_n) begin
      beats <= 0; lasts <= 0; bubbles <= 0; in_pay <= 1'b0;
    end else begin
      if (dut.lr_valid) begin
        beats <= beats + 1;
        if (dut.lr_last) lasts <= lasts + 1;
        if (!in_pay && !dut.lr_last && !dut.lr_error) in_pay <= 1'b1;
      end else if (in_pay) begin
        bubbles <= bubbles + 1;
        in_pay  <= 1'b0;
      end
      if (dut.lr_valid && (dut.lr_last || dut.lr_error)) in_pay <= 1'b0;
    end
  end

  // ---------------- 主流程：一笔事务 ----------------
  logic [2:0] code;
  initial begin
    a_req_valid = 1'b0; a_rsp_ready = 1'b0;

    repeat (3) @(negedge b_clk);
    b_rst_n = 1'b1;
    repeat (3) @(negedge a_clk);
    a_rst_n = 1'b1;

    // link_up 建立
    begin : wait_up
      int g = 0;
      while (!(a_link_up === 1'b1 && b_link_up === 1'b1) && g < 200) begin
        @(negedge a_clk); g++;
      end
      ck(a_link_up === 1'b1 && b_link_up === 1'b1, "link_up not established");
    end

    // link_up 置位后状态机还需一拍进入 IDLE，req_ready 才为高（组合依赖 state）
    begin : wait_idle
      int g = 0;
      while (!a_req_ready && g < 200) begin @(negedge a_clk); g++; end
      ck(g < 200, "req_ready never asserted after link_up");
    end

    // 发起事务（此刻 req_ready 已为高，保持一拍 valid 即可完成握手）
    a_req_valid <= 1'b1;
    @(negedge a_clk);
    a_req_valid <= 1'b0;
    a_rsp_ready <= 1'b1;

    // 等响应
    begin : wait_rsp
      int g = 0;
      while (!a_rsp_valid && g < 5000) begin @(negedge a_clk); g++; end
      ck(g < 5000, "response never returned");
    end

    ck(a_rsp_error === 1'b0, $sformatf("transaction must succeed, got code=%0d", a_rsp_code));
    ck(a_rsp_data === snap, $sformatf("data mismatch: exp=%h got=%h", snap, a_rsp_data));

    @(negedge a_clk);
    a_rsp_ready <= 1'b0;
    repeat (BEAT_COUNT + 4) @(negedge a_clk);

    if (!ASYNC) begin
      ck(bubbles == 0, $sformatf("payload must have no bubble, bubbles=%0d", bubbles));
      ck(lasts == 1,   $sformatf("exactly one last expected, got %0d", lasts));
      ck(beats == BEAT_COUNT, $sformatf("expected %0d beats, got %0d", BEAT_COUNT, beats));
    end

    if (fail_cnt == 0) $display("CONFIG_PASS");
    else begin
      $display("CONFIG_FAIL");
      $fatal(1, "config_matrix_tb failed");
    end
    $finish;
  end

  // 看门狗（时间基准，兼容两端不同频率）
  initial begin
    #(5000000);
    $display("CONFIG_FAIL (watchdog)");
    $fatal(1, "watchdog");
  end
endmodule