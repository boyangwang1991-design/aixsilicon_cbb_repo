# ============================================================================
# popcount.sdc — 综合/STA 约束基线（SEL-014）
# 纯组合：仅约束虚拟时钟与输入/输出延时（G6 PPA 表征用）。
# 用法：由 characterization/synth_sweep.tcl 统一设置（本文件为接口契约参考）。
# ============================================================================

# 虚拟时钟 400MHz（PDK README 建议起步频率；实测路径以 data arrival 度量）
create_clock -name vclk -period 2.5

# 组合输入输出延时（保守 0.5ns 端口模型）
set_input_delay  0.5 -clock vclk [all_inputs]
set_output_delay 0.5 -clock vclk [all_outputs]

# 输入驱动/输出负载（标准单元库 BUFH 驱动 + 轻负载）
set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
set_load 0.01 [all_outputs]
