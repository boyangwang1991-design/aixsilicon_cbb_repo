# 400 MHz 探索性综合，输入/输出延迟各 0.25 ns；本地复位为异步控制。
create_clock -name clk -period 2.5 [get_ports clk_i]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay 0.25 -clock clk [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
set_input_transition 0.05 [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay 0.25 -clock clk [all_outputs]
set_load 0.01 [all_outputs]
set_false_path -from [get_ports rst_ni]
