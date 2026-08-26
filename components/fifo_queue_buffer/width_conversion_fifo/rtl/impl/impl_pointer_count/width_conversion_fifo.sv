// ============================================================
// width_conversion_fifo —— 单时钟同步 FIFO + 整数比宽度转换
// QUE-012，A2/A3，P1
// 实现：impl_pointer_count（窄字为基本存储单元，指针+计数）
//
// 端口语义（标准 ready/valid）：
//   NARROW_TO_WIDE: narrow_in 每拍写 1 窄字；凑满 RATIO 个后在 wide_out 输出宽字
//   WIDE_TO_NARROW: wide_in  每拍写 1 宽字（拆 RATIO 个窄字入 RAM）；narrow_out 每拍弹 1 窄字
//   RAM 深度 DEPTH 以窄字为单位；满/空以窄字槽计数判定
//   契约约束：DEPTH >= RATIO（PC-005，防死锁）；宽侧位宽 NARROW_WIDTH*RATIO<=4096（PC-004）
//
// 关键 SVA（就近放置，PROP-WC-*）见文件尾部
// ============================================================
// 注：width_conversion_fifo_pkg 由调用方（.core / 编译脚本）以文件方式提供，
//     模块内不重复 `include，避免 package 重复声明（VCS OPD 警告）。
module width_conversion_fifo #(
    parameter bit DIRECTION      = width_conversion_fifo_pkg::NARROW_TO_WIDE,
    parameter int  NARROW_WIDTH  = 8,
    parameter int  RATIO         = 4,
    parameter int  DEPTH         = 8
) (
    input  logic clk,
    input  logic rst_n,

    // ---- 输入侧 ----
    input  logic [NARROW_WIDTH-1:0] narrow_in_data,
    input  logic                    narrow_in_valid,
    output logic                    narrow_in_ready,
    input  logic [NARROW_WIDTH*RATIO-1:0] wide_in_data,
    input  logic                    wide_in_valid,
    output logic                    wide_in_ready,

    // ---- 输出侧 ----
    output logic [NARROW_WIDTH-1:0] narrow_out_data,
    output logic                    narrow_out_valid,
    input  logic                    narrow_out_ready,
    output logic [NARROW_WIDTH*RATIO-1:0] wide_out_data,
    output logic                    wide_out_valid,
    input  logic                    wide_out_ready
);

  import width_conversion_fifo_pkg::*;

  // ---------- 参数检查（elaboration 强制拦截，对应 PC-001..005） ----------
  // 用 generate 块内的 $error：generate 在 elaboration 期求值，非法参数在此即报错
  generate
    if (NARROW_WIDTH < 1)
      $error("width_conversion_fifo: NARROW_WIDTH=%0d < 1 非法（PC-001）", NARROW_WIDTH);
    if (RATIO < 2)
      $error("width_conversion_fifo: RATIO=%0d < 2 非法（PC-002）", RATIO);
    if (DEPTH < 2)
      $error("width_conversion_fifo: DEPTH=%0d < 2 非法（PC-003）", DEPTH);
    if (NARROW_WIDTH * RATIO > width_conversion_fifo_pkg::WIDE_WIDTH_MAX)
      $error("width_conversion_fifo: NARROW_WIDTH*RATIO=%0d > %0d 宽侧位宽超限（PC-004）",
             NARROW_WIDTH * RATIO, width_conversion_fifo_pkg::WIDE_WIDTH_MAX);
    if (DEPTH < RATIO)
      $error("width_conversion_fifo: DEPTH=%0d < RATIO=%0d 死锁风险（PC-005，需 DEPTH>=RATIO）",
             DEPTH, RATIO);
  endgenerate

  localparam int WIDE_WIDTH = NARROW_WIDTH * RATIO;

  // 指针/计数位宽（domain-rules §3.1.1：DEPTH 为 1 时 $clog2(DEPTH)=0 会使
  // 指针位宽 [−1:0] 非法，故用 PTR_W 保护；CNT_W 需表示 0..DEPTH）
  localparam int PTR_W   = (DEPTH > 1) ? $clog2(DEPTH) : 1;   // RAM 读写指针
  localparam int CNT_W   = $clog2(DEPTH + 1);                  // 计数（可表示 0..DEPTH）
  localparam int RATIO_W = (RATIO > 1) ? $clog2(RATIO) + 1 : 1;// 拆分/组装下标（0..RATIO）

  // ---------- 内部状态 ----------
  logic [NARROW_WIDTH-1:0] mem [DEPTH];          // 窄字存储
  logic [PTR_W-1:0]        wr_ptr, rd_ptr;
  logic [CNT_W-1:0]        count;                // 已存窄字数
  logic [RATIO_W-1:0]      beat_idx;             // N2W: 已收窄字数；W2N: 待输出窄字数

  // 满/空判定（以窄字槽为准）
  // N2W: 写窄字需 1 槽，且输出占 RATIO 槽但输出同拍释放；W2N: 写宽字需 RATIO 槽
  logic full, empty;

  generate
    if (DIRECTION == NARROW_TO_WIDE) begin : g_n2w
      // 满：count 已满（==DEPTH）。写入需 1 槽，但读侧同拍可释放（见状态机）。
      // 保守判定：count >= DEPTH 时满（不接收），避免组合路径过长且保证不溢出。
      assign full = (count >= DEPTH[CNT_W-1:0]);

      // 输出 valid：凑满 RATIO 个窄字
      assign wide_out_valid   = (count >= RATIO[CNT_W-1:0]) && (beat_idx >= RATIO[RATIO_W-1:0]);
      assign narrow_out_valid = 1'b0;

      assign narrow_in_ready = ~full;
      assign wide_in_ready   = 1'b0;

      // 宽字拼接：读 rd_ptr 起 RATIO 个窄字（小端：先入在低位）
      // 用 generate for 静态展开位选择，避免运行期循环
      logic [WIDE_WIDTH-1:0] wide_concat;
      for (genvar i = 0; i < RATIO; i++) begin : g_concat
        assign wide_concat[i*NARROW_WIDTH +: NARROW_WIDTH] =
            mem[rd_ptr + i[PTR_W-1:0]];
      end
      assign wide_out_data = wide_concat;

      // 空（W2N 分支用）
      assign empty = (count == {CNT_W{1'b0}});
    end else begin : g_w2n
      // 满：写宽字需 RATIO 槽
      assign full = (count + RATIO[CNT_W-1:0]) > DEPTH[CNT_W-1:0];

      // 输出 valid：非空即输出窄字
      assign wide_out_valid   = 1'b0;
      assign narrow_out_valid = ~empty;

      assign wide_in_ready   = ~full;
      assign narrow_in_ready = 1'b0;

      // 输出窄字：RAM 读 rd_ptr（当前最老窄字）
      assign narrow_out_data = mem[rd_ptr];
      assign wide_out_data   = '0;

      assign empty = (count == {CNT_W{1'b0}});
    end
  endgenerate

  // ---------- 状态更新 ----------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr   <= '0;
      rd_ptr   <= '0;
      count    <= '0;
      beat_idx <= '0;
    end else begin
      if (DIRECTION == NARROW_TO_WIDE) begin : n2w_state
        logic push;
        logic pop;
        logic [CNT_W-1:0] pop_slots;
        push      = narrow_in_valid && narrow_in_ready;
        pop       = wide_out_valid && wide_out_ready;
        pop_slots = pop ? RATIO[CNT_W-1:0] : {CNT_W{1'b0}};

        if (push) begin
          mem[wr_ptr] <= narrow_in_data;
          wr_ptr      <= wr_ptr + 1'b1;
        end
        if (pop) begin
          rd_ptr <= rd_ptr + RATIO[PTR_W-1:0];
        end
        // beat_idx 单一赋值（避免同拍多次 NBA 冲突，W415a 修复）：
        //   pop 清零进入新一轮；否则 push 则 +1；否则保持
        if (pop)
          beat_idx <= '0;
        else if (push)
          beat_idx <= beat_idx + 1'b1;
        // 净计数变化（同拍 push+pop 正确合并）
        count <= count + {{(CNT_W-1){1'b0}}, push} - pop_slots;
      end else begin : w2n_state
        logic push;
        logic [CNT_W-1:0] push_slots;
        push       = wide_in_valid && wide_in_ready;
        push_slots = push ? RATIO[CNT_W-1:0] : {CNT_W{1'b0}};

        if (push) begin
          for (int i = 0; i < RATIO; i++) begin
            mem[wr_ptr + i[PTR_W-1:0]] <= wide_in_data[i*NARROW_WIDTH +: NARROW_WIDTH];
          end
          wr_ptr <= wr_ptr + RATIO[PTR_W-1:0];
        end
        if (narrow_out_valid && narrow_out_ready) begin
          rd_ptr <= rd_ptr + 1'b1;
        end
        // 净计数变化
        count <= count + push_slots - {{(CNT_W-1){1'b0}}, (narrow_out_valid && narrow_out_ready)};
      end
    end
  end

  // ============================================================
  // SVA —— 关键不变量（PROP-WC-*）
  // ============================================================
  `ifndef SYNTHESIS
  // PROP-WC_FULLEMPTY-001: 满时不接受新写（输入 ready 与 full 互斥）
  if (DIRECTION == NARROW_TO_WIDE) begin : g_ap_full_n2w
    assert property (@(posedge clk) disable iff (!rst_n)
      (full |-> ~narrow_in_ready));
  end else begin : g_ap_full_w2n
    assert property (@(posedge clk) disable iff (!rst_n)
      (full |-> ~wide_in_ready));
  end

  // PROP-WC_FULLEMPTY-002: 空时输出侧 valid 拉低（W2N 输出窄字）
  if (DIRECTION == WIDE_TO_NARROW) begin : g_ap_empty_w2n
    assert property (@(posedge clk) disable iff (!rst_n)
      (empty |-> ~narrow_out_valid));
  end

  // PROP-WC_ORD-001: N2W 组装期间 beat_idx 不超过 RATIO
  if (DIRECTION == NARROW_TO_WIDE) begin : g_ap_ord_n2w
    assert property (@(posedge clk) disable iff (!rst_n)
      (beat_idx <= RATIO[RATIO_W-1:0]));
  end

  // PROP-WC_CNTRL-001: 计数不越界（0 <= count <= DEPTH）
  assert property (@(posedge clk) disable iff (!rst_n)
    (count <= DEPTH[CNT_W-1:0]));
  `endif

endmodule
