// ============================================================================
// parallel_data_fetch —— 同层集成 / RTL 仿真便利封装（thin wrapper）
//
// 物理集成**不应**使用本封装：长距链路的集成单元是下面两个端点模块
//   parallel_data_fetch_requester   （放在 A 端区域，仅 A 域时钟/复位）
//   parallel_data_fetch_provider    （放在 B 端区域，仅 B 域时钟/复位）
// 以及链路边界单元（由集成方实例化）：
//   async 模式：pdf_async_fifo（写端口 B 域 / 读端口 A 域）
//   sync  模式：pdf_link_pipe（LINK_PIPE_STAGES 级同级 bundle 流水）
//
// 本封装只把上述模块在同一层连起来，用于 RTL 仿真、冒烟与同层级集成验证；
// 窄链路成为内部连线，其端口与端点契约见 docs/design.md §1 与 docs/cbb_spec.md §2。
// ============================================================================

module parallel_data_fetch #(
    parameter int DATA_WIDTH         = 256,
    parameter int LINK_WIDTH         = 32,
    parameter int LSB_FIRST          = 1,
    parameter int ASYNC_MODE         = 0,
    parameter int PARITY_EN          = 1,
    parameter int ODD_PARITY         = 0,
    parameter int TIMEOUT_EN         = 1,
    parameter int TIMEOUT_CYCLES     = 1024,
    parameter int REQ_SYNC_STAGES    = 2,
    parameter int RSP_FIFO_DEPTH     = 16,
    parameter int LINK_PIPE_STAGES   = 0,
    parameter int SLICE_IMPL         = 2,
    parameter int RESET_DEFAULT_DATA = 0
) (
    // ---------------- A 端业务接口（A 时钟域） ----------------
    input  logic                  a_clk_i,
    input  logic                  a_rst_ni,
    input  logic                  a_req_valid_i,
    output logic                  a_req_ready_o,
    output logic                  a_rsp_valid_o,
    input  logic                  a_rsp_ready_i,
    output logic [DATA_WIDTH-1:0] a_rsp_data_o,
    output logic                  a_rsp_error_o,
    output logic [2:0]            a_rsp_error_code_o,
    output logic                  a_busy_o,
    output logic                  a_link_up_o,
    // ---------------- B 端 Provider 接口（B 时钟域） ----------------
    input  logic                  b_clk_i,
    input  logic                  b_rst_ni,
    output logic                  b_fetch_valid_o,
    input  logic                  b_fetch_ready_i,
    input  logic                  b_data_valid_i,
    output logic                  b_data_ready_o,
    input  logic [DATA_WIDTH-1:0] b_data_i,
    input  logic                  b_data_error_i,
    output logic                  b_busy_o,
    output logic                  b_link_up_o
);
  localparam int BEAT_COUNT = DATA_WIDTH / LINK_WIDTH;
  localparam int PIPE_STAGES = (ASYNC_MODE == 0) ? LINK_PIPE_STAGES : 0;

  // ---- 链路内部信号 ----
  logic                  a_alive, b_alive;
  logic                  req_toggle;
  logic [LINK_WIDTH-1:0] pb_data;
  logic                  pb_valid, pb_last, pb_error, pb_parity, pb_epoch;
  logic                  pb_ready, reserve_ok;
  logic [LINK_WIDTH-1:0] lr_data;
  logic                  lr_valid, lr_last, lr_error, lr_parity, lr_epoch;
  logic                  lr_pop;

  // ---- 参数合法性（wrapper 层快速诊断；端点内亦有同等检查）----
  generate
    if (ASYNC_MODE == 1 && RSP_FIFO_DEPTH < BEAT_COUNT)
      $error("parallel_data_fetch: async mode requires RSP_FIFO_DEPTH >= BEAT_COUNT (PC-006)");
    if (ASYNC_MODE == 1 && LINK_PIPE_STAGES != 0)
      $error("parallel_data_fetch: LINK_PIPE_STAGES applies to sync mode only (PC-011)");
    if (RSP_FIFO_DEPTH != 2 && (RSP_FIFO_DEPTH % 8) != 0 && RSP_FIFO_DEPTH != 4)
      $error("parallel_data_fetch: RSP_FIFO_DEPTH must be a power of two (PC-009/PC-010)");
    if (RSP_FIFO_DEPTH > 1 && ((RSP_FIFO_DEPTH & (RSP_FIFO_DEPTH - 1)) != 0))
      $error("parallel_data_fetch: RSP_FIFO_DEPTH must be a power of two (PC-010b)");
  endgenerate

  // ---- B 端端点 ----
  parallel_data_fetch_provider #(
      .DATA_WIDTH      (DATA_WIDTH),
      .LINK_WIDTH      (LINK_WIDTH),
      .LSB_FIRST       (LSB_FIRST),
      .ASYNC_MODE      (ASYNC_MODE),
      .PARITY_EN       (PARITY_EN),
      .ODD_PARITY      (ODD_PARITY),
      .REQ_SYNC_STAGES (REQ_SYNC_STAGES),
      .LINK_PIPE_STAGES(LINK_PIPE_STAGES),
      .SLICE_IMPL      (SLICE_IMPL)
  ) u_provider (
      .clk_i              (b_clk_i),
      .rst_ni             (b_rst_ni),
      .link_a_alive_i     (a_alive),
      .link_b_alive_o     (b_alive),
      .link_up_o          (b_link_up_o),
      .link_req_i         (req_toggle),
      .link_beat_valid_o  (pb_valid),
      .link_beat_data_o   (pb_data),
      .link_beat_last_o   (pb_last),
      .link_beat_error_o  (pb_error),
      .link_beat_parity_o (pb_parity),
      .link_beat_epoch_o  (pb_epoch),
      .link_beat_ready_i  (pb_ready),
      .link_reserve_ok_i  (reserve_ok),
      .fetch_valid_o      (b_fetch_valid_o),
      .fetch_ready_i      (b_fetch_ready_i),
      .data_valid_i       (b_data_valid_i),
      .data_ready_o       (b_data_ready_o),
      .data_i             (b_data_i),
      .data_error_i       (b_data_error_i),
      .busy_o             (b_busy_o));

  // ---- 链路边界：同步 = 同级 bundle 流水；异步 = Gray 指针 async FIFO ----
  generate
    if (ASYNC_MODE == 0) begin : g_link_sync
      if (PIPE_STAGES == 0) begin : g_link_bypass
        assign lr_valid  = pb_valid;
        assign lr_data   = pb_data;
        assign lr_last   = pb_last;
        assign lr_error  = pb_error;
        assign lr_parity = pb_parity;
        assign lr_epoch  = pb_epoch;
      end else begin : g_link_pipe
        pdf_link_pipe #(.LINK_WIDTH(LINK_WIDTH), .STAGES(PIPE_STAGES)) u_link_pipe (
            .clk_i     (a_clk_i),
            .rst_ni    (a_rst_ni),
            .in_valid_i(pb_valid),
            .in_data_i (pb_data),
            .in_last_i (pb_last),
            .in_error_i(pb_error),
            .in_parity_i(pb_parity),
            .in_epoch_i(pb_epoch),
            .out_valid_o(lr_valid),
            .out_data_o (lr_data),
            .out_last_o (lr_last),
            .out_error_o(lr_error),
            .out_parity_o(lr_parity),
            .out_epoch_o(lr_epoch));
      end
      assign pb_ready    = 1'b1;         // 同步模式：接收端恒具备消费能力
      assign reserve_ok  = 1'b1;
    end else begin : g_link_async
      pdf_async_fifo #(.LINK_WIDTH(LINK_WIDTH), .DEPTH(RSP_FIFO_DEPTH),
                       .RESERVE_COUNT(BEAT_COUNT)) u_link_fifo (
          .w_clk_i      (b_clk_i),
          .w_rst_ni     (b_rst_ni),
          .w_valid_i    (pb_valid),
          .w_data_i     (pb_data),
          .w_last_i     (pb_last),
          .w_error_i    (pb_error),
          .w_parity_i   (pb_parity),
          .w_epoch_i    (pb_epoch),
          .w_full_o     (fifo_full),
          .w_reserve_ok_o(reserve_ok),
          .r_clk_i      (a_clk_i),
          .r_rst_ni     (a_rst_ni),
          .r_pop_i      (lr_pop),
          .r_valid_o    (lr_valid),
          .r_data_o     (lr_data),
          .r_last_o     (lr_last),
          .r_error_o    (lr_error),
          .r_parity_o   (lr_parity),
          .r_epoch_o    (lr_epoch));
      // reservation 语义（契约 §7）：provider 在启动发送**前**确认 FIFO 可容纳完整 transaction
      // （由 link_reserve_ok_i 在 WAIT_DATA 门控）。一旦开始发送，空间已被预留，
      // 发送期只应受"FIFO 是否已满"约束，**不得**逐拍用 reserve_ok 判定——
      // 否则当 RSP_FIFO_DEPTH 接近 BEAT_COUNT 时会在突发中途停顿、丢失 last（G5 复盘）。
      assign pb_ready = ~fifo_full;
    end
  endgenerate

  // ---- A 端端点 ----
  parallel_data_fetch_requester #(
      .DATA_WIDTH        (DATA_WIDTH),
      .LINK_WIDTH        (LINK_WIDTH),
      .LSB_FIRST         (LSB_FIRST),
      .ASYNC_MODE        (ASYNC_MODE),
      .PARITY_EN         (PARITY_EN),
      .ODD_PARITY        (ODD_PARITY),
      .TIMEOUT_EN        (TIMEOUT_EN),
      .TIMEOUT_CYCLES    (TIMEOUT_CYCLES),
      .REQ_SYNC_STAGES   (REQ_SYNC_STAGES),
      .LINK_PIPE_STAGES  (LINK_PIPE_STAGES),
      .RESET_DEFAULT_DATA(RESET_DEFAULT_DATA)
  ) u_requester (
      .clk_i           (a_clk_i),
      .rst_ni          (a_rst_ni),
      .link_b_alive_i  (b_alive),
      .link_a_alive_o  (a_alive),
      .link_up_o       (a_link_up_o),
      .link_req_o      (req_toggle),
      .link_rsp_valid_i(lr_valid),
      .link_rsp_data_i (lr_data),
      .link_rsp_last_i (lr_last),
      .link_rsp_error_i(lr_error),
      .link_rsp_parity_i(lr_parity),
      .link_rsp_epoch_i(lr_epoch),
      .link_rsp_pop_o  (lr_pop),
      .req_valid_i     (a_req_valid_i),
      .req_ready_o     (a_req_ready_o),
      .rsp_valid_o     (a_rsp_valid_o),
      .rsp_ready_i     (a_rsp_ready_i),
      .rsp_data_o      (a_rsp_data_o),
      .rsp_error_o     (a_rsp_error_o),
      .rsp_error_code_o(a_rsp_error_code_o),
      .busy_o          (a_busy_o));
endmodule
