# SDC（综合约束）— skid_buffer (QUE-007)
# 依据 FuseSoC Core synth target 生成/维护
# 典型主频 300–600MHz；建议从 400MHz（period 2.5ns）起步（对齐本地 PDK README §7）
create_clock -period 2.5 -name clk [get_ports clk]

# 输入/输出接口默认（集成层可覆盖）
set_input_delay  -clock clk 0.2 [get_ports {in_valid in_data in_ready}]
set_output_delay -clock clk 0.2 [get_ports {out_valid out_data out_ready}]

# 复位路径（异步置位/复位，不设 false path 之外的特殊约束）
set_driving_cell -lib_cell INV_X1 [get_ports rst_n]
