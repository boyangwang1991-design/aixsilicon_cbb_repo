# ============================================================================
# synth_quick.tcl — skid_buffer G6 PPA 综合（DATA_W ∈ {8,32,128}）
# 库上下文：characterization/pdk.yaml（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz）；时序模块（含寄存器）
# 方法论（2026-08-29）：一次综合记录**完整 PPA 报告集**（本 tcl 不内嵌解析），
#   关键指标由独立脚本 characterization/extract_ppa.py 抽取（避免电路未变时反复综合）。
#   时序判据：skid buffer 非纯组合 → **寄存到寄存（reg→reg）最差 setup slack** 为主判据
#   （timing_r2r.rpt：report_timing -from/-to all_registers）；
#   组合输出（reg→out）arrival 单独记录作 IO 参考；约束违规看 report_constraint 的
#   max_delay/setup（忽略 leakage power slack，非时序）。
# 用法：PC_CBB_ROOT=<cbb_root> PC_RTL_DIR=<rtl> PC_RUN_ID=run-<id> dc_shell -f synth_quick.tcl
# 产物：build/eda/ppa/<RUNID>/skid_w<W>_{area,timing_max,timing_r2r,constr,power,clock,regs}*
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
analyze -format sverilog [list [file join $RTLDIR skid_buffer.sv]] -define SYNTHESIS

foreach w {8 32 128} {
    set tag "skid_w${w}"
    remove_design -all
    elaborate skid_buffer -parameters "DATA_W=$w"
    link

    # 时序模块：create_clock 必须绑定 clk 端口（否则 vclk 为无源虚拟时钟，
    # FF 全部 unconstrained、无 reg→reg setup slack —— 2026-08-29 实测踩坑）
    create_clock -name vclk -period 2.5 [get_ports clk]
    set_input_delay  0.2 -clock vclk [get_ports {in_valid in_data}]
    set_output_delay 0.2 -clock vclk [get_ports {out_valid out_data in_ready}]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [get_ports {in_valid in_data out_ready}]
    set_load 0.01 [get_ports {out_valid out_data in_ready}]

    compile_ultra -no_autoungroup

    # ---- 完整报告集（供人查看；指标由 extract_ppa.py 抽取）----
    redirect -file "$OUT/${tag}_area.rpt"       { report_area }
    # 全 path group 最差路径（nworst 10，含 reg→reg setup slack 主判据）
    redirect -file "$OUT/${tag}_timing_max.rpt" { report_timing -delay_type max -nworst 10 -path_type full }
    # 组合输出 IO 参考（reg→out in_ready 的 arrival，非时序主判据）
    redirect -file "$OUT/${tag}_io.rpt" { report_timing -delay_type max -to [get_ports {in_ready}] -path_type full }
    # 约束 summary（setup/hold slack 主判据；含 max_delay/setup、min_delay/hold 各 slack）
    redirect -file "$OUT/${tag}_constr.rpt"     { report_constraint }
    # 违规明细（-all_violators；注意其中 leakage power slack 非时序，仅作参考）
    redirect -file "$OUT/${tag}_constr_viol.rpt" { report_constraint -all_violators }
    redirect -file "$OUT/${tag}_power.rpt"      { report_power }
    redirect -file "$OUT/${tag}_clock.rpt"      { report_clock -skew -attributes }
    redirect -file "$OUT/${tag}_regs.txt"       { puts [sizeof_collection [all_registers]] }

    puts "PPA-DONE $tag"
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
