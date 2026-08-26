// ============================================================
// width_conversion_fifo_pkg —— 公共参数/类型/检查（所有实现共享）
// QUE-012 width_conversion_fifo（A2/A3）
// 关键：非法参数在 elaboration 阶段由 $error 强制拦截（G1 负向依据）
// ============================================================
package width_conversion_fifo_pkg;

  // 转换方向
  typedef enum logic {
    NARROW_TO_WIDE = 1'b0,   // 窄->宽：输入窄字，输出宽字
    WIDE_TO_NARROW = 1'b1    // 宽->窄：输入宽字，输出窄字
  } wc_direction_t;

  // 宽侧位宽上限（bit）
  localparam int WIDE_WIDTH_MAX = 4096;

  // 参数合法性检查（elaboration 阶段强制拦截非法组合）
  // 覆盖 schema 约束 PC-001..PC-005 的精确形式（乘积上限 + 死锁防护）
  function automatic void wc_check_params(
      input int narrow_width,
      input int ratio,
      input int depth
  );
    if (narrow_width < 1)
      $error("width_conversion_fifo: NARROW_WIDTH=%0d < 1 非法（PC-001）", narrow_width);
    if (ratio < 2)
      $error("width_conversion_fifo: RATIO=%0d < 2 非法（PC-002）", ratio);
    if (depth < 2)
      $error("width_conversion_fifo: DEPTH=%0d < 2 非法（PC-003）", depth);
    if (narrow_width * ratio > WIDE_WIDTH_MAX)
      $error("width_conversion_fifo: NARROW_WIDTH*RATIO=%0d > %0d 宽侧位宽超限（PC-004）",
             narrow_width * ratio, WIDE_WIDTH_MAX);
    if (depth < ratio)
      $error("width_conversion_fifo: DEPTH=%0d < RATIO=%0d 死锁风险（PC-005，需 DEPTH>=RATIO）",
             depth, ratio);
  endfunction

endpackage
