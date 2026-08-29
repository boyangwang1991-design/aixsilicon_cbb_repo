# SDC（综合约束）— round_robin_arbiter
# 依据 FuseSoC Core synth target 生成/维护；含时钟/IO delay/伪路径等
create_clock -period 5.0 -name clk [get_ports clk]
