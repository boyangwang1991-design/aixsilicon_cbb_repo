# ============================================================================
# synth_quick.tcl — skid_buffer G6 PPA 多实现对比综合
# 配置矩阵：
#   forward: skid_w<W>_i0  (IMPL=0, BYPASS=0)  简单打拍，ready 透传
#   full   : skid_w<W>_i1  (IMPL=1, BYPASS=0)  OUT 寄存 + SKID 槽（默认）
#   bypass : skid_byp_w<W> (IMPL=1, BYPASS=1)  组合直通（零延迟参考）
# 库上下文：characterization/pdk.yaml（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz）绑定 clk 端口（时序模块必须）
# 方法论：一次综合记录完整报告集（本 tcl 不内嵌解析），指标由 extract_ppa.py 抽取。
# 时序判据：reg→reg 最差 setup slack 主判据（timing_max.rpt）；组合输出 arrival 作 IO 参考；
#           BYPASS 为组合直通（无 reg→reg），以组合 arrival 为时序结论。
# 用法：PC_CBB_ROOT=<cbb_root> PC_RTL_DIR=<rtl> PC_RUN_ID=run-<id> dc_shell -f synth_quick.tcl
# 抽取：uv run python characterization/extract_ppa.py <cbb_root> <RUNID>
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(PC_RUN_ID)
set RTLDIR $env(PC_RTL_DIR)
set CBBROOT $env(PC_CBB_ROOT)
set OUT [file normalize "$CBBROOT/build/eda/ppa/$RUNID"]
file mkdir $OUT
file mkdir [file normalize "$CBBROOT/build/eda"]

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"

define_design_lib WORK -path $OUT/work
analyze -format sverilog [list \
    [file join $RTLDIR skid_buffer.sv] \
    [file join $RTLDIR impl/forward/skid_buffer.sv] \
    [file join $RTLDIR impl/full/skid_buffer.sv] \
] -define SYNTHESIS

# ---- forward（IMPL=0）----
foreach w {8 32 128} {
    set tag "skid_w${w}_i0"
    remove_design -all
    elaborate skid_buffer -parameters "DATA_W=$w, IMPL=0, BYPASS=0"
    link
    create_clock -name vclk -period 2.5 [get_ports clk]
    set_input_delay  0.2 -clock vclk [get_ports {in_valid in_data}]
    set_output_delay 0.2 -clock vclk [get_ports {out_valid out_data in_ready}]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [get_ports {in_valid in_data out_ready}]
    set_load 0.01 [get_ports {out_valid out_data in_ready}]
    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"       { report_area }
    redirect -file "$OUT/${tag}_timing_max.rpt" { report_timing -delay_type max -nworst 10 -path_type full }
    redirect -file "$OUT/${tag}_io.rpt"         { report_timing -delay_type max -to [get_ports {in_ready}] -path_type full }
    redirect -file "$OUT/${tag}_power.rpt"      { report_power }
    redirect -file "$OUT/${tag}_regs.txt"       { puts [sizeof_collection [all_registers]] }
    puts "PPA-DONE $tag"
}

# ---- full（IMPL=1，默认）----
foreach w {8 32 128} {
    set tag "skid_w${w}_i1"
    remove_design -all
    elaborate skid_buffer -parameters "DATA_W=$w, IMPL=1, BYPASS=0"
    link
    create_clock -name vclk -period 2.5 [get_ports clk]
    set_input_delay  0.2 -clock vclk [get_ports {in_valid in_data}]
    set_output_delay 0.2 -clock vclk [get_ports {out_valid out_data in_ready}]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [get_ports {in_valid in_data out_ready}]
    set_load 0.01 [get_ports {out_valid out_data in_ready}]
    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"       { report_area }
    redirect -file "$OUT/${tag}_timing_max.rpt" { report_timing -delay_type max -nworst 10 -path_type full }
    redirect -file "$OUT/${tag}_io.rpt"         { report_timing -delay_type max -to [get_ports {in_ready}] -path_type full }
    redirect -file "$OUT/${tag}_power.rpt"      { report_power }
    redirect -file "$OUT/${tag}_regs.txt"       { puts [sizeof_collection [all_registers]] }
    puts "PPA-DONE $tag"
}

# ---- bypass（BYPASS=1，组合直通参考）----
foreach w {32} {
    set tag "skid_byp_w${w}"
    remove_design -all
    elaborate skid_buffer -parameters "DATA_W=$w, IMPL=1, BYPASS=1"
    link
    create_clock -name vclk -period 2.5 [get_ports clk]
    set_input_delay  0.2 -clock vclk [get_ports {in_valid in_data}]
    set_output_delay 0.2 -clock vclk [get_ports {out_valid out_data in_ready}]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [get_ports {in_valid in_data out_ready}]
    set_load 0.01 [get_ports {out_valid out_data in_ready}]
    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"       { report_area }
    redirect -file "$OUT/${tag}_timing_max.rpt" { report_timing -delay_type max -nworst 10 -path_type full }
    redirect -file "$OUT/${tag}_io.rpt"         { report_timing -delay_type max -to [get_ports {in_ready}] -path_type full }
    redirect -file "$OUT/${tag}_power.rpt"      { report_power }
    redirect -file "$OUT/${tag}_regs.txt"       { puts [sizeof_collection [all_registers]] }
    puts "PPA-DONE $tag"
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
