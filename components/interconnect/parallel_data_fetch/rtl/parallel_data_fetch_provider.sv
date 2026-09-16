// ============================================================================
// parallel_data_fetch_provider —— B 端端点（数据侧）
//
// 职责：远端请求边沿检测、向本地数据源发起取数、原子锁存整份快照、
//       按 LINK_WIDTH 连续发送 BEAT_COUNT 拍（单 outstanding）。
// 时钟域：仅 B 域（异步模式下内部完成对端 alive 的同步与稳定判定）。
//
// 状态机：LINK_WAIT -> IDLE -> FETCH -> WAIT_DATA -> SEND | SEND_ERROR -> IDLE
//   * 快照只在 data_fire 当拍锁存；发送期间只读 snapshot_q，结构上不访问实时输入。
//   * b_data_ready_o 需要 link_reserve_ok_i（异步为 FIFO 剩余 ≥ BEAT_COUNT），
//     使"发送开始后不受 A 端反压影响"成为可满足性质而非假设。
//
// 本文件含私有单元 pdf_alive_check / pdf_sync_ff / pdf_link_pipe / pdf_async_fifo。
// 参数合法性在 generate 内 $error（elaboration 期拦截）。
// ============================================================================

module parallel_data_fetch_provider #(
    parameter int DATA_WIDTH       = 256,
    parameter int LINK_WIDTH       = 32,
    parameter int LSB_FIRST        = 1,
    parameter int ASYNC_MODE       = 0,
    parameter int PARITY_EN        = 1,
    parameter int ODD_PARITY       = 0,
    parameter int REQ_SYNC_STAGES  = 2,
    parameter int LINK_PIPE_STAGES = 0,      // 仅同步模式；长线 bundle 流水（见 wrapper）
    parameter int SLICE_IMPL       = 2
) (
    // B 域时钟与复位
    input  logic                  clk_i,
    input  logic                  rst_ni,
    // 链路存活
    input  logic                  link_a_alive_i,   // 对端(A)存活
    output logic                  link_b_alive_o,   // 本地存活
    output logic                  link_up_o,
    // 请求方向（B 域；异步时为同步后的 toggle）
    input  logic                  link_req_i,
    // 返回方向（直连链路写端：ASYNC 为 async FIFO 写侧，SYNC 为长线 pipeline）
    output logic                  link_beat_valid_o,
    output logic [LINK_WIDTH-1:0] link_beat_data_o,
    output logic                  link_beat_last_o,
    output logic                  link_beat_error_o,
    output logic                  link_beat_parity_o,
    output logic                  link_beat_epoch_o,
    input  logic                  link_beat_ready_i,   // 下游可接受 beat（FIFO 未满 / 同步恒 1）
    input  logic                  link_reserve_ok_i,   // 空间 ≥ BEAT_COUNT（reservation）
    // 业务接口（B 端数据源）
    output logic                  fetch_valid_o,
    input  logic                  fetch_ready_i,
    input  logic                  data_valid_i,
    output logic                  data_ready_o,
    input  logic [DATA_WIDTH-1:0] data_i,
    input  logic                  data_error_i,
    output logic                  busy_o
);
  localparam int BEAT_COUNT = DATA_WIDTH / LINK_WIDTH;
  localparam int BEAT_CNT_W = (BEAT_COUNT <= 1) ? 1 : $clog2(BEAT_COUNT);

  typedef enum logic [2:0] {
    PV_LINK_WAIT  = 3'd0,
    PV_IDLE       = 3'd1,
    PV_FETCH      = 3'd2,
    PV_WAIT_DATA  = 3'd3,
    PV_SEND       = 3'd4,
    PV_SEND_ERROR = 3'd5
  } prov_state_t;

  prov_state_t           state_q, state_d;
  logic                  local_stable, remote_stable;
  logic                  remote_alive_sync;
  logic                  req_toggle_sync;
  logic                  req_seen_q;
  logic                  new_req;

  logic [DATA_WIDTH-1:0] snapshot_q;                  // 原子快照（发送期间的唯一数据源）
  logic [DATA_WIDTH-1:0] sh_q;                        // SLICE_IMPL=0 移位副本
  logic [LINK_WIDTH-1:0] bank_q [BEAT_COUNT];         // SLICE_IMPL=2 静态 bank
  logic [BEAT_CNT_W-1:0] beat_cnt_q;
  logic                  epoch_q;
  logic [LINK_WIDTH-1:0] slice_d;
  logic                  data_fire, error_fire;
  logic                  last_beat;

  // ---- 参数合法性（elaboration 期）----
  generate
    if (DATA_WIDTH < 8 || DATA_WIDTH > 4096)
      $error("parallel_data_fetch_provider: DATA_WIDTH must be 8..4096 (PC-001)");
    if (LINK_WIDTH < 1 || LINK_WIDTH > 256)
      $error("parallel_data_fetch_provider: LINK_WIDTH must be 1..256 (PC-002)");
    if (DATA_WIDTH < LINK_WIDTH)
      $error("parallel_data_fetch_provider: DATA_WIDTH must be >= LINK_WIDTH (PC-003)");
    if (DATA_WIDTH % LINK_WIDTH != 0)
      $error("parallel_data_fetch_provider: DATA_WIDTH must be a multiple of LINK_WIDTH (PC-004)");
    if (REQ_SYNC_STAGES < 2 || REQ_SYNC_STAGES > 4)
      $error("parallel_data_fetch_provider: REQ_SYNC_STAGES must be 2..4 (PC-008a)");
    if (LINK_PIPE_STAGES < 0 || LINK_PIPE_STAGES > 8)
      $error("parallel_data_fetch_provider: LINK_PIPE_STAGES must be 0..8 (PC-012)");
    if (SLICE_IMPL < 0 || SLICE_IMPL > 2)
      $error("parallel_data_fetch_provider: SLICE_IMPL must be 0..2 (PC-013)");
  endgenerate

  // ---- 请求方向：同步直连 / 异步同步后异或检测边沿 ----
  generate
    if (ASYNC_MODE == 0) begin : g_req_direct
      assign req_toggle_sync = link_req_i;
    end else begin : g_req_sync
      pdf_sync_ff #(.STAGES(REQ_SYNC_STAGES)) u_req_sync_a2b (
          .clk_i(clk_i), .rst_ni(rst_ni), .d_i(link_req_i), .q_o(req_toggle_sync));
    end
  endgenerate

  assign new_req = req_toggle_sync ^ req_seen_q;

  // ---- 对端 alive ----
  generate
    if (ASYNC_MODE == 0) begin : g_alive_direct
      assign remote_alive_sync = link_a_alive_i;
    end else begin : g_alive_sync
      pdf_sync_ff #(.STAGES(REQ_SYNC_STAGES)) u_alive_sync_a2b (
          .clk_i(clk_i), .rst_ni(rst_ni), .d_i(link_a_alive_i), .q_o(remote_alive_sync));
    end
  endgenerate

  pdf_alive_check #(.STAGES(REQ_SYNC_STAGES)) u_local_alive (
      .clk_i(clk_i), .rst_ni(rst_ni), .alive_i(1'b1), .stable_o(local_stable));
  pdf_alive_check #(.STAGES(REQ_SYNC_STAGES)) u_remote_alive (
      .clk_i(clk_i), .rst_ni(rst_ni), .alive_i(remote_alive_sync), .stable_o(remote_stable));

  assign link_b_alive_o = 1'b1;
  assign link_up_o      = local_stable && remote_stable;

  // ---- 切片选择（三实现共享同一可观察契约）----
  always_comb begin
    unique case (SLICE_IMPL)
      0:       slice_d = (LSB_FIRST == 1) ? sh_q[LINK_WIDTH-1:0]
                                          : sh_q[DATA_WIDTH-1:DATA_WIDTH-LINK_WIDTH];
      1:       slice_d = (LSB_FIRST == 1)
                       ? snapshot_q[beat_cnt_q*LINK_WIDTH +: LINK_WIDTH]
                       : snapshot_q[DATA_WIDTH-1-beat_cnt_q*LINK_WIDTH -: LINK_WIDTH];
      default: slice_d = bank_q[beat_cnt_q];            // banked：静态数组 + 小位宽索引
    endcase
  end

  assign last_beat = (beat_cnt_q == BEAT_COUNT[BEAT_CNT_W-1:0] - 1'b1);

  // ---- 握手 ----
  assign data_ready_o = (state_q == PV_WAIT_DATA) && link_reserve_ok_i;
  assign data_fire    = data_valid_i && data_ready_o && !data_error_i;
  assign error_fire   = data_valid_i && data_ready_o &&  data_error_i;

  // ---- 下一状态 ----
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      PV_LINK_WAIT: if (link_up_o) state_d = PV_IDLE;
      PV_IDLE: begin
        if (!link_up_o)        state_d = PV_LINK_WAIT;
        else if (new_req)      state_d = PV_FETCH;
      end
      PV_FETCH:     if (fetch_ready_i) state_d = PV_WAIT_DATA;
      PV_WAIT_DATA: begin
        if (error_fire)    state_d = PV_SEND_ERROR;
        else if (data_fire) state_d = PV_SEND;
      end
      PV_SEND:       if (link_beat_ready_i && last_beat) state_d = PV_IDLE;
      PV_SEND_ERROR: if (link_beat_ready_i)              state_d = PV_IDLE;
      default: state_d = PV_LINK_WAIT;
    endcase
  end

  // ---- 时序 ----
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q    <= PV_LINK_WAIT;
      req_seen_q <= 1'b0;
      epoch_q    <= 1'b0;
      beat_cnt_q <= '0;
      snapshot_q <= '0;
      sh_q       <= '0;
      for (int b = 0; b < BEAT_COUNT; b++) bank_q[b] <= '0;
    end else begin
      state_q <= state_d;

      if (state_q == PV_IDLE && new_req) begin
        req_seen_q <= req_toggle_sync;      // 仅在接受该事件后更新已见值
        epoch_q    <= ~epoch_q;
        beat_cnt_q <= '0;
      end

      if (data_fire) begin
        // 原子快照：只在数据被接受当拍锁存整份数据
        snapshot_q <= data_i;
        if (SLICE_IMPL == 0) sh_q <= data_i;
        if (SLICE_IMPL == 2) begin
          for (int b = 0; b < BEAT_COUNT; b++) begin
            if (LSB_FIRST == 1) bank_q[b] <= data_i[b*LINK_WIDTH +: LINK_WIDTH];
            else                bank_q[b] <= data_i[DATA_WIDTH-1-b*LINK_WIDTH -: LINK_WIDTH];
          end
        end
      end else if (state_q == PV_SEND && link_beat_ready_i && !last_beat) begin
        // shift 实现在发送期间逐拍移位（内容来源仍是锁存值）
        if (SLICE_IMPL == 0) begin
          if (LSB_FIRST == 1) sh_q <= sh_q >> LINK_WIDTH;
          else                sh_q <= sh_q << LINK_WIDTH;
        end
      end

      if (state_q == PV_SEND && link_beat_ready_i && !last_beat)
        beat_cnt_q <= beat_cnt_q + 1'b1;
      else if (state_q == PV_SEND_ERROR && link_beat_ready_i)
        beat_cnt_q <= '0;
    end
  end

  // ---- 输出 ----
  assign link_beat_valid_o  = (state_q == PV_SEND) || (state_q == PV_SEND_ERROR);
  assign link_beat_data_o   = (state_q == PV_SEND_ERROR) ? {LINK_WIDTH{1'b0}} : slice_d;
  assign link_beat_last_o   = (state_q == PV_SEND_ERROR) ? 1'b1
                            : ((state_q == PV_SEND) && last_beat);
  assign link_beat_error_o  = (state_q == PV_SEND_ERROR);
  assign link_beat_epoch_o  = epoch_q;
  assign link_beat_parity_o = (PARITY_EN == 0) ? 1'b0
                            : ((ODD_PARITY == 1)
                               ? ~^(link_beat_data_o ^ {link_beat_last_o,
                                                        link_beat_error_o, epoch_q})
                               :  ^(link_beat_data_o ^ {link_beat_last_o,
                                                        link_beat_error_o, epoch_q}));
  assign fetch_valid_o      = (state_q == PV_FETCH);
  assign busy_o             = (state_q != PV_IDLE) && (state_q != PV_LINK_WAIT);

  // ==================================================================
  // 属性（SVA）：B 域可解释性质
  // ==================================================================
  // PROP-PDF_SNAPSHOT-001：发送期间快照保持稳定
  ap_snapshot_stable : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == PV_SEND && beat_cnt_q != '0) |-> $stable(snapshot_q));

  // PROP-PDF_SNAPSHOT-001（数据侧）：每拍数据恒等于快照的对应切片
  ap_slice_matches_snapshot : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == PV_SEND) |-> (link_beat_data_o == ((LSB_FIRST == 1)
      ? snapshot_q[beat_cnt_q*LINK_WIDTH +: LINK_WIDTH]
      : snapshot_q[DATA_WIDTH-1-beat_cnt_q*LINK_WIDTH -: LINK_WIDTH])));

  // PROP-PDF_BEATSEQ-003：payload 连续发送（不停拍），last 仅在末拍
  ap_send_continuous : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == PV_SEND && link_beat_ready_i && !last_beat) |=> (state_q == PV_SEND));

  ap_last_only_at_end : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == PV_SEND) |-> (link_beat_last_o == last_beat));

  // error response 为单拍（valid=1,error=1,last=1）
  ap_error_single_beat : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == PV_SEND_ERROR) |-> (link_beat_error_o && link_beat_last_o));

  // 发送只在链路可用时发生
  ap_send_only_when_up : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == PV_SEND) |-> link_up_o);

  // FSM 编码合法
  ap_legal_state : assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q inside {PV_LINK_WAIT, PV_IDLE, PV_FETCH, PV_WAIT_DATA, PV_SEND, PV_SEND_ERROR}));
endmodule


// ============================================================================
// pdf_sync_ff —— 多级同步器（单 bit；ASYNC_REG 供 CDC 工具识别）
// ============================================================================
module pdf_sync_ff #(
    parameter int STAGES = 2
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic d_i,
    output logic q_o
);
  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sync_q <= '0;
    else         sync_q <= {sync_q[STAGES-2:0], d_i};
  end

  assign q_o = sync_q[STAGES-1];
endmodule


// ============================================================================
// pdf_link_pipe —— 同步模式长线 bundle 流水（data/valid/last/error/parity/epoch 同级）
// 返回链路无 ready：按 valid 逐级透传，各级延迟严格一致。
// ============================================================================
module pdf_link_pipe #(
    parameter int LINK_WIDTH = 32,
    parameter int STAGES     = 1
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  in_valid_i,
    input  logic [LINK_WIDTH-1:0] in_data_i,
    input  logic                  in_last_i,
    input  logic                  in_error_i,
    input  logic                  in_parity_i,
    input  logic                  in_epoch_i,
    output logic                  out_valid_o,
    output logic [LINK_WIDTH-1:0] out_data_o,
    output logic                  out_last_o,
    output logic                  out_error_o,
    output logic                  out_parity_o,
    output logic                  out_epoch_o
);
  typedef struct packed {
    logic [LINK_WIDTH-1:0] data;
    logic                  last;
    logic                  error;
    logic                  parity;
    logic                  epoch;
  } pdf_pipe_bundle_t;

  pdf_pipe_bundle_t [STAGES-1:0] stage_q;
  logic             [STAGES-1:0] valid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < STAGES; i++) begin
        stage_q[i] <= '0;
        valid_q[i] <= 1'b0;
      end
    end else begin
      stage_q[0] <= '{data: in_data_i, last: in_last_i, error: in_error_i,
                      parity: in_parity_i, epoch: in_epoch_i};
      valid_q[0] <= in_valid_i;
      for (int i = 1; i < STAGES; i++) begin
        stage_q[i] <= stage_q[i-1];
        valid_q[i] <= valid_q[i-1];
      end
    end
  end

  assign out_valid_o  = valid_q[STAGES-1];
  assign out_data_o   = stage_q[STAGES-1].data;
  assign out_last_o   = stage_q[STAGES-1].last;
  assign out_error_o  = stage_q[STAGES-1].error;
  assign out_parity_o = stage_q[STAGES-1].parity;
  assign out_epoch_o  = stage_q[STAGES-1].epoch;
endmodule


// ============================================================================
// pdf_async_fifo —— Gray 指针异步 FIFO（返回 beat bundle 整体跨域）
// 写端口在 B 域、读端口在 A 域；提供 reservation 判据（free >= RESERVE_COUNT）。
// 只同步 Gray 指针，不对数据逐 bit 同步；指针同步器带 ASYNC_REG。
// 深度为 2 的幂（PC-009 保证），容量计算用二进制还原。
// ============================================================================
module pdf_async_fifo #(
    parameter int LINK_WIDTH    = 32,
    parameter int DEPTH         = 16,
    parameter int RESERVE_COUNT = 1
) (
    input  logic                  w_clk_i,
    input  logic                  w_rst_ni,
    input  logic                  w_valid_i,
    input  logic [LINK_WIDTH-1:0] w_data_i,
    input  logic                  w_last_i,
    input  logic                  w_error_i,
    input  logic                  w_parity_i,
    input  logic                  w_epoch_i,
    output logic                  w_full_o,
    output logic                  w_reserve_ok_o,
    input  logic                  r_clk_i,
    input  logic                  r_rst_ni,
    input  logic                  r_pop_i,
    output logic                  r_valid_o,
    output logic [LINK_WIDTH-1:0] r_data_o,
    output logic                  r_last_o,
    output logic                  r_error_o,
    output logic                  r_parity_o,
    output logic                  r_epoch_o
);
  localparam int AW = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int PW = AW + 1;                        // 指针附加一位用于满判据
  localparam int DW = (LINK_WIDTH < 4) ? 4 : LINK_WIDTH;

  logic [DW-1:0] mem_data  [DEPTH];
  logic          mem_last  [DEPTH];
  logic          mem_error [DEPTH];
  logic          mem_parity[DEPTH];
  logic          mem_epoch [DEPTH];

  logic [PW-1:0] wbin_q, wgray_q, rbin_q, rgray_q;
  logic [PW-1:0] wbin_d, wgray_d, rbin_d, rgray_d;
  (* ASYNC_REG = "TRUE" *) logic [PW-1:0] rgray_sync_w0, rgray_sync_w1;
  (* ASYNC_REG = "TRUE" *) logic [PW-1:0] wgray_sync_r0, wgray_sync_r1;

  logic          full_q, empty_q;
  logic [PW-1:0] used_q, free_q;
  logic [PW-1:0] rbin_sync_w;

  // ---------------- 写域 ----------------
  always_comb begin
    wbin_d  = wbin_q + ((w_valid_i && !full_q) ? 1'b1 : 1'b0);
    wgray_d = (wbin_d >> 1) ^ wbin_d;
  end

  always_ff @(posedge w_clk_i or negedge w_rst_ni) begin
    if (!w_rst_ni) begin
      wbin_q  <= '0;
      wgray_q <= '0;
      for (int i = 0; i < DEPTH; i++) begin
        mem_data[i]   <= '0;
        mem_last[i]   <= 1'b0;
        mem_error[i]  <= 1'b0;
        mem_parity[i] <= 1'b0;
        mem_epoch[i]  <= 1'b0;
      end
    end else begin
      wbin_q  <= wbin_d;
      wgray_q <= wgray_d;
      if (w_valid_i && !full_q) begin
        mem_data  [wbin_q[AW-1:0]] <= w_data_i;
        mem_last  [wbin_q[AW-1:0]] <= w_last_i;
        mem_error [wbin_q[AW-1:0]] <= w_error_i;
        mem_parity[wbin_q[AW-1:0]] <= w_parity_i;
        mem_epoch [wbin_q[AW-1:0]] <= w_epoch_i;
      end
    end
  end

  always_ff @(posedge w_clk_i or negedge w_rst_ni) begin
    if (!w_rst_ni) begin
      rgray_sync_w0 <= '0;
      rgray_sync_w1 <= '0;
    end else begin
      rgray_sync_w0 <= rgray_q;          // 读指针灰度跨到写域
      rgray_sync_w1 <= rgray_sync_w0;
    end
  end

  always_comb rbin_sync_w = gray_to_bin(rgray_sync_w1, PW);

  always_comb begin
    // 满：二进制写指针 - 同步后的读指针 == DEPTH
    full_q = ((wbin_q - rbin_sync_w) == DEPTH[PW-1:0]);
    used_q = wbin_q - rbin_sync_w;
    free_q = DEPTH[PW-1:0] - used_q;
  end

  assign w_full_o       = full_q;
  assign w_reserve_ok_o = (free_q >= RESERVE_COUNT[PW-1:0]);

  // ---------------- 读域 ----------------
  always_comb begin
    rbin_d  = rbin_q + ((r_pop_i && !empty_q) ? 1'b1 : 1'b0);
    rgray_d = (rbin_d >> 1) ^ rbin_d;
  end

  always_ff @(posedge r_clk_i or negedge r_rst_ni) begin
    if (!r_rst_ni) begin
      rbin_q  <= '0;
      rgray_q <= '0;
    end else begin
      rbin_q  <= rbin_d;
      rgray_q <= rgray_d;
    end
  end

  always_ff @(posedge r_clk_i or negedge r_rst_ni) begin
    if (!r_rst_ni) begin
      wgray_sync_r0 <= '0;
      wgray_sync_r1 <= '0;
    end else begin
      wgray_sync_r0 <= wgray_q;          // 写指针灰度跨到读域
      wgray_sync_r1 <= wgray_sync_r0;
    end
  end

  always_comb empty_q = (rgray_q == wgray_sync_r1);

  assign r_valid_o  = !empty_q;
  assign r_data_o   = mem_data  [rbin_q[AW-1:0]];
  assign r_last_o   = mem_last  [rbin_q[AW-1:0]];
  assign r_error_o  = mem_error [rbin_q[AW-1:0]];
  assign r_parity_o = mem_parity[rbin_q[AW-1:0]];
  assign r_epoch_o  = mem_epoch [rbin_q[AW-1:0]];

  // Gray -> binary（指针同步后还原二进制用于容量计算）
  function automatic logic [PW-1:0] gray_to_bin(input logic [PW-1:0] gray, input int w);
    logic [PW-1:0] bin;
    bin = gray;
    for (int i = 1; i < w; i++) begin
      bin = bin ^ (bin >> i);
    end
    return bin;
  endfunction
endmodule