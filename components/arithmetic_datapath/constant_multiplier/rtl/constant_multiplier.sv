// ============================================================
// constant_multiplier —— RTL 极简单文件（CBB 强制默认，对齐 sync_fifo）
// 不引入 package/interface；参数上限用 localparam、参数检查用 generate $error。
// 例外：需使用 HWIF 标准接口文件（AXI/AHB/APB/Stream）时仅引用 HWIF 文件，仍不新建 CBB package。
// 多实现时才拆分 rtl/impl/<impl>/constant_multiplier.sv（每个实现保持极简单风格）。
// ============================================================

module constant_multiplier #(
    // 参数（与 cbb.yaml parameters 对齐）
) (
    input  logic clk,
    input  logic rst_n
    // 端口（ready/valid 或契约接口，见 behavior.yaml）
);

  // 参数上限 localparam（与 cbb.yaml constraints 对齐）
  // localparam int <PARAM>_MAX = ...;

  // 参数检查（generate 块内 $error，elaboration 期拦截）
  generate
    // $error("... 非法");
  endgenerate

  // 实现（含就近 SVA，PROP-*）

endmodule
