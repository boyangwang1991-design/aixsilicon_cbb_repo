# wallace W64 单点综合（同 G6 基线上下文：SC9 HVT tt / vclk 2.5ns）
set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RTLDIR $env(PC_RTL_DIR)
set OUT [file normalize "../../build/eda/wallace64_run"]
file mkdir $OUT
set_app_var target_library $PDKDB
set_app_var link_library "* $PDKDB"
analyze -format sverilog [list [file join $RTLDIR popcount_compressed.sv]]
elaborate popcount_impl_wallace
link
create_clock -name vclk -period 2.5
set_input_delay 0.5 -clock vclk [all_inputs]
set_output_delay 0.5 -clock vclk [all_outputs]
set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
set_load 0.01 [all_outputs]
compile_ultra -no_autoungroup
redirect -file "$OUT/area.rpt"   { report_area }
redirect -file "$OUT/timing.rpt" { report_timing -max_paths 1 }
redirect -file "$OUT/power.rpt"  { report_power }
puts "W64-WALLACE-DONE"
exit
