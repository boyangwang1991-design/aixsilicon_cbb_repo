# SDC（综合约束）— sync_fifo
# 依据 FuseSoC Core synth target 生成/维护；含时钟/IO delay/伪路径等
#
# 说明：G6 实测综合在本仓库无标准单元库/PDK 环境下不可行（OPTIONAL_UNAVAILABLE, E0）。
# 本文件为 dc synth target 引用所需的约束模板（占位），供有库环境填充实际值：
#   - create_clock -period 10 [get_ports clk]
#   - set_input_delay / set_output_delay
#   - 输出路径（OUTPUT_REG=0 时）为存储组合输出，可据频率目标选加寄存级。
create_clock -period 10.0 -name clk [get_ports clk]
