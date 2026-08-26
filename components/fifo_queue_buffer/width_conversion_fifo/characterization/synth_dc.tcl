# ============================================================
# DC 综合脚本 —— QUE-012 width_conversion_fifo
# 用途：G6 PPA 代表点综合（面积/关键路径）
# 工艺：Synopsys lsi_10k 教学库（E0 探索级，无真实 PDK 上下文）
# 用法: dc_shell -f synth_dc.tcl  (需设置 RTL/OUT/参数)
# 参数通过环境/变量注入: set rtl_dir / set out / set p_direction ...
# ============================================================

# ---- 输入（由外层脚本注入）----
set rtl_dir   [file normalize $env(WCF_RTL_DIR)]
set out_dir   [file normalize $env(WCF_OUT_DIR)]
set p_direction $env(WCF_DIRECTION)
set p_nw      $env(WCF_NARROW_WIDTH)
set p_ratio   $env(WCF_RATIO)
set p_depth   $env(WCF_DEPTH)
set clk_period $env(WCF_CLK_NS)

set TARGET_LIB "/home/eda/app/synopsys/syn/V-2023.12-SP3/libraries/syn/lsi_10k.db"

# ---- 库设置 ----
set_app_var target_library $TARGET_LIB
set_app_var link_library "* $TARGET_LIB"
set_app_var search_path [list $rtl_dir/interface $rtl_dir/impl/impl_pointer_count]

# ---- 读 RTL ----
read_file -format sverilog [list \
  $rtl_dir/interface/width_conversion_fifo_pkg.svh \
  $rtl_dir/impl/impl_pointer_count/width_conversion_fifo.sv ]
current_design width_conversion_fifo

# ---- 参数化实例 ----
set p_direction_int [expr {$p_direction eq "WIDE_TO_NARROW" ? 1 : 0}]
current_design width_conversion_fifo
set verilogout_no_tri true
set RTL_PARAM {}
# 通过 elaborate 覆盖参数
elaborate width_conversion_fifo -parameters "DIRECTION=$p_direction_int, NARROW_WIDTH=$p_nw, RATIO=$p_ratio, DEPTH=$p_depth"

# ---- 约束 ----
create_clock -name clk -period $clk_period [get_ports clk]
set_input_delay  [expr {$clk_period * 0.3}] -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr {$clk_period * 0.3}] -clock clk [all_outputs]
set_driving_cell -lib_cell DFFSR [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.05 [all_outputs]

# ---- 综合 ----
compile_ultra -no_autoungroup

# ---- 报告 ----
report_area -hierarchy > $out_dir/area.rpt
report_timing -path full -delay max -nworst 1 > $out_dir/timing.rpt
report_qor > $out_dir/qor.rpt
report_power > $out_dir/power.rpt

# ---- 提取指标 ----
set area_total [get_attribute [current_design] area]
set wns [get_attribute [get_timing_paths -delay_type max] slack]
puts "PPA_RESULT cfg=$p_direction/$p_nw/$p_ratio/$p_depth clk=$clk_period area=$area_total slack=$wns"

exit
