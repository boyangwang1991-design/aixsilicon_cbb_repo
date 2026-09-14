# ============================================================================
# accumulator.sdc — 累加器时序约束（PPA 综合基线）
# 单时钟、同步复位；核心 A→A 反馈路径是主要时序目标。
# 约束用于 G6 PPA 表征；不预设工艺/频率承诺，由目标库与实测决定。
# ============================================================================

# 单时钟域
create_clock -name clk_i -period 1.0 [get_ports clk_i]

# 输入延迟（默认；按实际消费者调整）
set_input_delay 0.1 -clock clk_i [get_ports {rst_ni ce_i clear_i load_i valid_i sub_i status_clear_i}]
set_input_delay 0.1 -clock clk_i [get_ports {data_i[*] load_data_i[*]}]

# 输出延迟
set_output_delay 0.1 -clock clk_i [get_ports {acc_o[*] update_o overflow_event_o overflow_sticky_o}]

# 异步复位释放（同步复位 rst_ni，无 async 约束需求）
# 反馈路径：acc_o -> 组合算术/饱和/选择 -> a_q（由综合器优化，不手动分组）
