# Exploratory 400MHz baseline. Reset release synchronization is external.
create_clock -name clk -period 2.5 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_input_delay 0.5 -clock clk [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_output_delay 0.5 -clock clk [all_outputs]
set_false_path -from [get_ports rst_n]
set_load 0.01 [all_outputs]
