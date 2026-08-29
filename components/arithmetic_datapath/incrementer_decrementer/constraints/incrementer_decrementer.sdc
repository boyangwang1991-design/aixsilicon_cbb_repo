# SDC（综合约束）— incrementer_decrementer
# 本构件纯组合（无时钟/复位端口）；PPA 表征约束在 characterization/synth_sweep.tcl
# 内联定义（create_clock 2.5ns=400MHz 用于度量组合 data arrival）：
#   create_clock -name vclk -period 2.5
#   set_input_delay  0.5 -clock vclk [all_inputs]
#   set_output_delay 0.5 -clock vclk [all_outputs]
#   set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
#   set_load 0.01 [all_outputs]
# 注：无 clk 端口，故此处不 create_clock 于端口；若集成到有时钟上下文，
# 调用方负责定义上游时钟与 IO 约束。
