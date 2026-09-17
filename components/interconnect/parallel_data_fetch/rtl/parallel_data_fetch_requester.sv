// ============================================================================
// parallel_data_fetch_requester —— A 端端点（请求侧）
//
// 职责：请求发起（单 outstanding）、beat 重组、逐拍奇偶校验、超时计时、
//       错误码判定与优先级合并、完整结果输出。
// 时钟域：仅 A 域（异步模式下内部完成对端 alive 的同步与稳定判定）。
//
// 状态机：LINK_WAIT -> IDLE -> RECEIVE -> HOLD -> (IDLE | RECOVER -> IDLE)
//   * RECEIVE 的唯一终结条件：收齐 BEAT_COUNT 拍（成功）或致命错误/超时/last（失败）
//     → 结构上保证"不输出部分数据"。
//   * 失败终结后进入 RECOVER 静默窗口：返回链路无 ready，B 端仍在途输出，
//     必须消费并丢弃 QUIET_MAX 拍后才可接受新请求，避免旧 beat 污染与请求丢失。
//   * epoch（单 bit 代际）作为极端迟到数据的双保险过滤。
//
// 本文件含私有单元 pdf_alive_check（与 provider 同构，各自域内独立实现）。
// 参数合法性在 generate 内 $error（elaboration 期拦截）。
// ============================================================================

module parallel_data_fetch_requester #(
    parameter int DATA_WIDTH         = 256,
    parameter int LINK_WIDTH         = 32,
    parameter int LSB_FIRST          = 1,
    parameter int ASYNC_MODE         = 0,
    parameter int PARITY_EN          = 1,
    parameter int ODD_PARITY         = 0,
    parameter int TIMEOUT_EN         = 1,
    parameter int TIMEOUT_CYCLES     = 1024,
    parameter int REQ_SYNC_STAGES    = 2,
    parameter int LINK_PIPE_STAGES   = 0,     // 仅用于静默窗口大小（长线延迟）
    parameter int RESET_DEFAULT_DATA = 0
) (
    // A 域时钟与复位（低有效异步断言、同步释放）
    input  logic                  clk_i,
    input  logic                  rst_ni,
    // 链路存活
    input  logic                  link_b_alive_i,   // 对端(B)存活（异步时在 A 域同步后判稳）
    output logic                  link_a_alive_o,   // 本地存活
    output logic                  link_up_o,        // 两端 alive 均稳定
    // 请求方向（A 域；异步时为 toggle 编码）
    output logic                  link_req_o,
    // 返回方向（来自链路读端：ASYNC 为 async FIFO 读侧，SYNC 为 B 端直连）
    input  logic                  link_rsp_valid_i,
    input  logic [LINK_WIDTH-1:0] link_rsp_data_i,
    input  logic                  link_rsp_last_i,
    input  logic                  link_rsp_error_i,
    input  logic                  link_rsp_parity_i,
    input  logic                  link_rsp_epoch_i,
    output logic                  link_rsp_pop_o,   // 读使能（接收/排空窗口）
    // 业务接口
    input  logic                  req_valid_i,
    output logic                  req_ready_o,
    output logic                  rsp_valid_o,
    input  logic                  rsp_ready_i,
    output logic [DATA_WIDTH-1:0] rsp_data_o,
    output logic                  rsp_error_o,
    output logic [2:0]            rsp_error_code_o,
    output logic                  busy_o
);
  localparam int BEAT_COUNT = DATA_WIDTH / LINK_WIDTH;
  localparam int BEAT_CNT_W = (BEAT_COUNT <= 1) ? 1 : $clog2(BEAT_COUNT);
  localparam int TMO_W      = (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES + 1);
  localparam int TMO_MAX    = TIMEOUT_CYCLES - 1;
  // 错误后的静默窗口（避免在 B 端仍在途/未消费本次请求时复用请求 toggle）：
  //   同步模式：B 端与 A 端同钟，覆盖连续发送 + 长线流水即可。
  //   异步模式：A 端无法观测 B 端进度，契约 §14 要求"先完成 link recovery"；
  //     窗口按跨域往返量级保守放大——请求 toggle 同步 + B 端连续发送 + FIFO 指针回同步，
  //     并留出裕量。该窗口是保守等待而非精确握手：最坏情况是 A 端再次超时并报错
  //     （不会输出错误数据、不会死锁），见 docs/design.md §8.4。
  localparam int QUIET_MAX  = (ASYNC_MODE == 1)
                            ? (BEAT_COUNT * 2) + (REQ_SYNC_STAGES * 4) + 16
                            : BEAT_COUNT + LINK_PIPE_STAGES + REQ_SYNC_STAGES + 2;
  localparam int QUIET_W    = (QUIET_MAX <= 1) ? 1 : $clog2(QUIET_MAX + 1);

  localparam logic [2:0] ERR_NONE         = 3'd0;
  localparam logic [2:0] ERR_TIMEOUT      = 3'd1;
  localparam logic [2:0] ERR_PROVIDER     = 3'd2;
  localparam logic [2:0] ERR_PARITY       = 3'd3;
  localparam logic [2:0] ERR_PROTOCOL     = 3'd4;
  localparam logic [2:0] ERR_REMOTE_RESET = 3'd5;
  localparam logic [2:0] ERR_FIFO         = 3'd6;
  localparam logic [2:0] ERR_INTERNAL     = 3'd7;

  typedef enum logic [2:0] {
    ST_LINK_WAIT = 3'd0,
    ST_IDLE      = 3'd1,
    ST_RECEIVE   = 3'd2,
    ST_HOLD      = 3'd3,
    ST_RECOVER   = 3'd4
  } req_state_t;

  req_state_t            state_q, state_d;
  logic                  local_stable, remote_stable;
  logic                  remote_alive_sync;

  logic [DATA_WIDTH-1:0] assemble_q, assemble_d;
  logic [DATA_WIDTH-1:0] rsp_data_q;
  logic                  rsp_error_q;
  logic [2:0]            rsp_code_q;
  logic                  success_q;
  logic [BEAT_CNT_W-1:0] beat_cnt_q;
  logic [TMO_W-1:0]      tmo_cnt_q;
  logic [QUIET_W-1:0]    quiet_cnt_q;
  logic                  epoch_q;
  logic                  req_toggle_q;
  logic [2:0]            err_q, err_d;

  logic                  epoch_match, parity_bad, beat_accept;
  logic                  beat_finishes, beat_exceeds;
  logic                  fatal_remote_reset, timeout_hit;
  logic                  final_success, final_error;

  // ---- 参数合法性（elaboration 期）----
  generate
    if (DATA_WIDTH < 8 || DATA_WIDTH > 4096)
      $error("parallel_data_fetch_requester: DATA_WIDTH must be 8..4096 (PC-001)");
    if (LINK_WIDTH < 1 || LINK_WIDTH > 256)
      $error("parallel_data_fetch_requester: LINK_WIDTH must be 1..256 (PC-002)");
    if (DATA_WIDTH < LINK_WIDTH)
      $error("parallel_data_fetch_requester: DATA_WIDTH must be >= LINK_WIDTH (PC-003)");
    if (DATA_WIDTH % LINK_WIDTH != 0)
      $error("parallel_data_fetch_requester: DATA_WIDTH must be a multiple of LINK_WIDTH (PC-004)");
    if (TIMEOUT_CYCLES < 8 || TIMEOUT_CYCLES > 1048576)
      $error("parallel_data_fetch_requester: TIMEOUT_CYCLES must be 8..1048576 (PC-007a)");
    if (REQ_SYNC_STAGES < 2 || REQ_SYNC_STAGES > 4)
      $error("parallel_data_fetch_requester: REQ_SYNC_STAGES must be 2..4 (PC-008a)");
    if (TIMEOUT_EN == 1 && TIMEOUT_CYCLES <= BEAT_COUNT)
      $error("parallel_data_fetch_requester: TIMEOUT_CYCLES must exceed BEAT_COUNT (PC-007)");
  endgenerate

  // ---- 对端 alive：异步模式先同步到 A 域再判稳定 ----
  generate
    if (ASYNC_MODE == 0) begin : g_alive_direct
      assign remote_alive_sync = link_b_alive_i;
    end else begin : g_alive_sync
      pdf_sync_ff #(.STAGES(REQ_SYNC_STAGES)) u_alive_sync_b2a (
          .clk_i(clk_i), .rst_ni(rst_ni), .d_i(link_b_alive_i), .q_o(remote_alive_sync));
    end
  endgenerate

  pdf_alive_check #(.STAGES(REQ_SYNC_STAGES)) u_local_alive (
      .clk_i(clk_i), .rst_ni(rst_ni), .alive_i(1'b1), .stable_o(local_stable));
  pdf_alive_check #(.STAGES(REQ_SYNC_STAGES)) u_remote_alive (
      .clk_i(clk_i), .rst_ni(rst_ni), .alive_i(remote_alive_sync), .stable_o(remote_stable));

  assign link_a_alive_o = 1'b1;              // 本端脱离复位即存活
  assign link_up_o      = local_stable && remote_stable;

  // ---- 错误优先级合并（REMOTE_RESET > FIFO > INTERNAL > PROTOCOL > PARITY > PROVIDER > TIMEOUT）----
  function automatic int err_rank(input logic [2:0] code);
    case (code)
      ERR_REMOTE_RESET: err_rank = 0;
      ERR_FIFO:         err_rank = 1;
      ERR_INTERNAL:     err_rank = 2;
      ERR_PROTOCOL:     err_rank = 3;
      ERR_PARITY:       err_rank = 4;
      ERR_PROVIDER:     err_rank = 5;
      ERR_TIMEOUT:      err_rank = 6;
      default:          err_rank = 7;
    endcase
  endfunction

  function automatic logic [2:0] err_merge(input logic [2:0] a, input logic [2:0] b);
    err_merge = (err_rank(a) <= err_rank(b)) ? a : b;
  endfunction

  // ---- 接收判定 ----
  assign epoch_match = (link_rsp_epoch_i == epoch_q);
  assign parity_bad  = (PARITY_EN == 1) &&
                       (link_rsp_parity_i != ((ODD_PARITY == 1)
                        ? ~^(link_rsp_data_i ^ {link_rsp_last_i, link_rsp_error_i, link_rsp_epoch_i})
                        :  ^(link_rsp_data_i ^ {link_rsp_last_i, link_rsp_error_i, link_rsp_epoch_i})));
  assign beat_accept = (state_q == ST_RECEIVE) && link_rsp_valid_i && epoch_match;

  assign beat_finishes = (state_q == ST_RECEIVE) && link_rsp_valid_i && epoch_match &&
                         link_rsp_last_i &&
                         (beat_cnt_q == BEAT_COUNT[BEAT_CNT_W-1:0] - 1'b1);
  assign beat_exceeds  = (state_q == ST_RECEIVE) && link_rsp_valid_i && epoch_match &&
                         !link_rsp_last_i &&
                         (beat_cnt_q == BEAT_COUNT[BEAT_CNT_W-1:0] - 1'b1);
  assign fatal_remote_reset = (state_q == ST_RECEIVE) && !remote_alive_sync;
  assign timeout_hit        = (state_q == ST_RECEIVE) && (TIMEOUT_EN == 1) &&
                              (tmo_cnt_q >= TMO_MAX[TMO_W-1:0]);

  // 成功结束：收齐拍数且 last 且无累计错误；否则为失败结束
  assign final_success = beat_finishes && (err_d == ERR_NONE);

  // ---- 重组（indexed write；末拍显式合并当前 beat）----
  always_comb begin
    assemble_d = assemble_q;
    if (beat_accept) begin
      if (LSB_FIRST == 1)
        assemble_d[beat_cnt_q*LINK_WIDTH +: LINK_WIDTH] = link_rsp_data_i;
      else
        assemble_d[DATA_WIDTH-1-beat_cnt_q*LINK_WIDTH -: LINK_WIDTH] = link_rsp_data_i;
    end
  end

  // ---- 下一状态与累计错误 ----
  always_comb begin
    state_d  = state_q;
    err_d    = err_q;
    success_q = 1'b0;
    final_error = 1'b0;

    unique case (state_q)
      ST_LINK_WAIT: if (link_up_o) state_d = ST_IDLE;

      ST_IDLE: begin
        if (!link_up_o) state_d = ST_LINK_WAIT;
        else if (req_valid_i && req_ready_o) state_d = ST_RECEIVE;
      end

      ST_RECEIVE: begin
        if (parity_bad && beat_accept) err_d = err_merge(err_d, ERR_PARITY);
        if (beat_exceeds)              err_d = err_merge(err_d, ERR_PROTOCOL);
        if (beat_accept && link_rsp_error_i) err_d = err_merge(err_d, ERR_PROVIDER);
        if (fatal_remote_reset)        err_d = err_merge(err_d, ERR_REMOTE_RESET);
        if (timeout_hit)               err_d = err_merge(err_d, ERR_TIMEOUT);

        if (fatal_remote_reset || timeout_hit) begin
          state_d     = ST_HOLD;
          final_error = 1'b1;
        end else if (beat_accept && link_rsp_last_i) begin
          // 消费到 last 即终结：无错误为成功，否则失败（含单拍 error response）
          state_d     = ST_HOLD;
          success_q   = (err_d == ERR_NONE);
          final_error = (err_d != ERR_NONE);
        end
      end

      ST_HOLD: begin
        if (rsp_valid_o && rsp_ready_i)
          state_d = rsp_error_q ? ST_RECOVER : ST_IDLE;
      end

      ST_RECOVER: if (quiet_cnt_q == QUIET_MAX[QUIET_W-1:0] - 1'b1) state_d = ST_IDLE;

      default: state_d = ST_LINK_WAIT;
    endcase
  end

  // ---- 时序 ----
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= ST_LINK_WAIT;
      assemble_q   <= '0;
      rsp_data_q   <= {DATA_WIDTH{RESET_DEFAULT_DATA[0]}};
      rsp_error_q  <= 1'b0;
      rsp_code_q   <= ERR_NONE;
      beat_cnt_q   <= '0;
      tmo_cnt_q    <= '0;
      quiet_cnt_q  <= '0;
      epoch_q      <= 1'b0;
      req_toggle_q <= 1'b0;
      err_q        <= ERR_NONE;
    end else begin
      state_q <= state_d;

      if (state_q == ST_IDLE && req_valid_i && req_ready_o) begin
        req_toggle_q <= ~req_toggle_q;      // 单 outstanding：每次请求翻转一次
        epoch_q      <= ~epoch_q;           // transaction 代际
        beat_cnt_q   <= '0;
        tmo_cnt_q    <= '0;
        quiet_cnt_q  <= '0;
        err_q        <= ERR_NONE;
        assemble_q   <= '0;
      end

      if (state_q == ST_RECEIVE) begin
        if (beat_accept) begin
          assemble_q <= assemble_d;
          beat_cnt_q <= beat_cnt_q + 1'b1;
        end
        if (!(TIMEOUT_EN == 1 && timeout_hit)) tmo_cnt_q <= tmo_cnt_q + 1'b1;
      end

      if (state_q == ST_RECEIVE && state_d == ST_HOLD) begin
        rsp_data_q  <= success_q ? assemble_d : {DATA_WIDTH{RESET_DEFAULT_DATA[0]}};
        rsp_error_q <= !success_q;
        rsp_code_q  <= success_q ? ERR_NONE : ((err_d == ERR_NONE) ? ERR_INTERNAL : err_d);
        err_q       <= err_d;
      end else if (state_q == ST_RECEIVE) begin
        err_q <= err_d;
      end

      if (state_q == ST_RECOVER) begin
        quiet_cnt_q <= quiet_cnt_q + 1'b1;
      end else if (state_q != ST_IDLE) begin
        quiet_cnt_q <= '0;
      end
    end
  end

  // ---- 输出 ----
  // 请求方向：同步模式为请求事件，异步模式为 toggle 编码（每接受一次请求翻转一次）
  assign link_req_o       = req_toggle_q;
  assign req_ready_o      = (state_q == ST_IDLE) && link_up_o;
  assign rsp_valid_o      = (state_q == ST_HOLD);
  assign rsp_data_o       = rsp_data_q;
  assign rsp_error_o      = rsp_error_q;
  assign rsp_error_code_o = rsp_code_q;
  assign busy_o           = (state_q == ST_RECEIVE) || (state_q == ST_HOLD) || (state_q == ST_RECOVER);
  // 接收期间持续消费；失败后的静默窗口继续排空在途 beat
  assign link_rsp_pop_o   = ((state_q == ST_RECEIVE) || (state_q == ST_RECOVER)) && link_rsp_valid_i;

  // ==================================================================
  // 属性（SVA）：A 域可解释性质
  // ==================================================================
  // PROP-PDF_LINKUP-005：link_up=0 时不得接受请求
  ap_linkup_gates_req : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (!link_up_o) |-> (!req_ready_o));

  // PROP-PDF_HOLDSTABLE-004：响应未被接受期间输出稳定
  ap_rsp_hold_stable : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (rsp_valid_o && !rsp_ready_i) |=> ($stable(rsp_data_o) && $stable(rsp_error_o) &&
                                      $stable(rsp_error_code_o)));

  // PROP-PDF_ERROR-006：错误结果不输出损坏数据（为 RESET_VALUE 语义值）
  ap_error_no_payload : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (rsp_valid_o && rsp_error_o) |-> (rsp_data_o == {DATA_WIDTH{RESET_DEFAULT_DATA[0]}}));

  // PROP-PDF_CONSERVE-002：成功结果必然来自收齐 BEAT_COUNT 拍
  ap_success_needs_full_burst : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (rsp_valid_o && !rsp_error_o) |-> (rsp_error_code_o == ERR_NONE) &&
                                      (beat_cnt_q == BEAT_COUNT[BEAT_CNT_W-1:0]));

  // 单 outstanding：请求被接受后到响应被消费前不得再次接受
  ap_no_second_req : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == ST_IDLE && req_valid_i && req_ready_o) |=> (state_q != ST_IDLE)
      until_with (rsp_valid_o && rsp_ready_i));

  // 接收期间必须具备消费能力（返回链路无 ready）
  ap_receive_always_consumes : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == ST_RECEIVE && link_rsp_valid_i) |-> link_rsp_pop_o);

  // 无法识别的状态编码必须报错（FSM 安全）
  ap_legal_state : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q inside {ST_LINK_WAIT, ST_IDLE, ST_RECEIVE, ST_HOLD, ST_RECOVER}));
endmodule


// ============================================================================
// pdf_alive_check —— alive 连续稳定检测（稳定 STAGES 拍后置位；alive 掉则清零）
// ============================================================================
module pdf_alive_check #(
    parameter int STAGES = 2
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic alive_i,
    output logic stable_o
);
  localparam int CW = (STAGES < 2) ? 1 : $clog2(STAGES + 1);

  logic [CW-1:0] cnt_q;
  logic          sat_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cnt_q <= '0;
      sat_q <= 1'b0;
    end else if (!alive_i) begin
      cnt_q <= '0;
      sat_q <= 1'b0;
    end else if (!sat_q) begin
      if (cnt_q == STAGES[CW-1:0] - 1'b1) begin
        cnt_q <= '0;
        sat_q <= 1'b1;
      end else begin
        cnt_q <= cnt_q + 1'b1;
      end
    end
  end

  assign stable_o = sat_q;
endmodule