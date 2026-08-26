// ============================================================
// sync_fifo —— 通用单时钟同步 FIFO（指针+计数，标准 ready/valid 握手）
// QUE-001，A2，P0
//
// 轻量布局（简单 CBB 单一文件）：参数检查/类型/常量与微架构同文件，
// 不拆 rtl/interface（artifact-contract §2 轻量合并选项）。
//
// 端口语义（标准 ready/valid，非 FWFT）：
//   wr_ready = ~full：满时拒收（不覆盖）
//   rd_valid = ~empty：空时无输出
//   OUTPUT_REG=0：rd_data/rd_valid 直接从存储旁路（首拍延迟 1，组合输出）
//   OUTPUT_REG=1：rd_data/rd_valid 再寄存一拍（首拍延迟 2，输出路径切短）
//
// pop 判定与输出级分离（domain-rules §3.1.1/§3.2）：
//   pop_ev = ~empty && rd_ready（沿前 count 非空才弹，防空下溢回绕 DEPTH）
//   rd_data_q<=mem[rd_ptr]、rd_valid_q<=~empty（沿前状态捕获，相位一致）；
//   弹空拍允许消费最后缓存（valid 残存 1），空态稳定后 valid 拉低。
//
// 存储由综合工具推断为 RAM 或寄存器堆（AUTO 模式）；本模块不例化存储宏。
// ============================================================
module sync_fifo #(
    parameter int  DATA_WIDTH = 32,
    parameter int  DEPTH      = 16,
    parameter bit  OUTPUT_REG = 1'b1
) (
    input  logic clk,
    input  logic rst_n,

    // ---- 写侧（producer）----
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  wr_valid,
    output logic                  wr_ready,

    // ---- 读侧（consumer）----
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_valid,
    input  logic                  rd_ready
);

  // ---------- 参数上限（对应 cbb.yaml constraints PC-001..PC-004） ----------
  localparam int DATA_WIDTH_MAX = 1024;   // PC-004
  localparam int DEPTH_MAX      = 4096;   // PC-003

  // ---------- 参数检查（generate 块内 $error，elaboration 期强制拦截） ----------
  generate
    if (DATA_WIDTH < 1)
      $error("sync_fifo: DATA_WIDTH=%0d < 1 非法（PC-001）", DATA_WIDTH);
    if (DEPTH < 2)
      $error("sync_fifo: DEPTH=%0d < 2 非法（PC-002，需 DEPTH>=2）", DEPTH);
    if (DEPTH > DEPTH_MAX)
      $error("sync_fifo: DEPTH=%0d > %0d 深度超限（PC-003）", DEPTH, DEPTH_MAX);
    if (DATA_WIDTH > DATA_WIDTH_MAX)
      $error("sync_fifo: DATA_WIDTH=%0d > %0d 位宽超限（PC-004）", DATA_WIDTH, DATA_WIDTH_MAX);
  endgenerate

  // ---------- 位宽（domain-rules §3.1.1：DEPTH 非 2 幂时避免零宽/越界） ----------
  localparam int PTR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;  // 指针位宽（DEPTH>=2，均 >=1）
  localparam int CNT_W = $clog2(DEPTH + 1);                // 计数位宽（可表示 0..DEPTH）

  // ---------- 内部状态 ----------
  logic [DATA_WIDTH-1:0] mem [DEPTH];       // 存储（综合推断）
  logic [PTR_W-1:0] wr_ptr, rd_ptr;         // 环形读写指针
  logic [CNT_W-1:0] count;                  // 已存元素数（0..DEPTH）

  logic full, empty;
  logic push_ev, pop_ev;

  // 满/空判定（计数制；避免指针相等歧义）
  assign full  = (count == DEPTH[CNT_W-1:0]);
  assign empty = (count == {CNT_W{1'b0}});

  // 写侧：满时拒收
  assign wr_ready = ~full;

  // 握手事件（pop_ev 用沿前 count 非空判定，与输出级分离，防空下溢）
  assign push_ev = wr_valid && wr_ready;
  assign pop_ev  = ~empty && rd_ready;

  // ---------- 读侧输出（两种模式统一，生成分支） ----------
  generate
    if (OUTPUT_REG) begin : g_oreg
      // 标准寄存器输出（沿前状态捕获）：
      //   rd_data_q  <= mem[rd_ptr]  —— 沿前 rd_ptr 指向的头（当前可弹数据）
      //   rd_valid_q <= ~empty       —— 沿前 empty 取反（当前非空即有效）
      // 弹空拍允许消费最后缓存（valid 残存 1），空态稳定后 0。
      logic [DATA_WIDTH-1:0] rd_data_q;
      logic                  rd_valid_q;

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          rd_data_q  <= '0;
          rd_valid_q <= 1'b0;
        end else begin
          rd_data_q  <= mem[rd_ptr];
          rd_valid_q <= ~empty;
        end
      end

      assign rd_data  = rd_data_q;
      assign rd_valid = rd_valid_q;
    end else begin : g_no_oreg
      // 组合输出：直接旁路存储当前读指针内容 & 空标志
      // 先写后读同拍双端口语义由 count 更新（pop 拍后下一拍 rd_ptr 才推进）保证
      assign rd_data  = mem[rd_ptr];
      assign rd_valid = ~empty;
    end
  endgenerate

  // ---------- 状态更新（指针/计数共享） ----------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
    end else begin
      if (push_ev) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr      <= wr_ptr + 1'b1;
      end
      if (pop_ev) begin
        rd_ptr <= rd_ptr + 1'b1;
      end
      // 净计数变化（同拍 push+pop 正确合并，且不越界：pop_ev 由非空保证无下溢）
      count <= count + {{(CNT_W-1){1'b0}}, push_ev} - {{(CNT_W-1){1'b0}}, pop_ev};
    end
  end

  // ============================================================
  // SVA —— 关键不变量（PROP-SF-*）
  // ============================================================
  `ifndef SYNTHESIS

  // PROP-SF_FULLEMPTY-001: 满时不接受新写（wr_ready 与 full 互斥 -> 不覆盖）
  assert property (@(posedge clk) disable iff (!rst_n)
    (full |-> ~wr_ready));

  // PROP-SF_FULLEMPTY-002: 写入发生（被接受）时不满（与上互补，防溢出）
  assert property (@(posedge clk) disable iff (!rst_n)
    ((wr_valid && wr_ready) |-> ~full));

  // PROP-SF_CNTRL-001: 计数不越界（0 <= count <= DEPTH）
  assert property (@(posedge clk) disable iff (!rst_n)
    (count <= DEPTH[CNT_W-1:0]));

  // PROP-SF_EMPTY-001: 空且本拍无写入时，下一拍 valid 必须拉低
  //   （弹空拍允许消费最后缓存 valid 残存 1；空且无新写入时下拍必 0）
  assert property (@(posedge clk) disable iff (!rst_n)
    (empty && ~(wr_valid && wr_ready) |-> ##1 ~rd_valid));

  // PROP-SF_CNTRL-002: 满且同拍弹出的极端态计数仍保界（count 加 1 减 1 净保持）
  assert property (@(posedge clk) disable iff (!rst_n)
    ((full && rd_valid && rd_ready) |-> (count == DEPTH[CNT_W-1:0])));

  `endif

endmodule