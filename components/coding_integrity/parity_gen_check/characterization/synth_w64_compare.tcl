# ============================================================================
# synth_w64_compare.tcl — parity_gen_check W64 双实现综合对比（tree / linear）
# 库上下文：characterization/pdk.yaml 为唯一事实源（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：纯组合 → 虚拟时钟 create_clock 2.5ns（400MHz 起步）——与 G6 基线一致
# 实现：子模块直证（parity_impl_tree / parity_impl_linear，DATA_WIDTH 参数化）
# 用法：PC_RTL_DIR=<cbb>/rtl PC_RUN_ID=run-<id> dc_shell -f synth_w64_compare.tcl
# 产物：build/eda/ppa/<RUNID>/{tree,linear}_w64_{area,timing,power}.rpt + *_summary.txt
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(PC_RUN_ID)
set RTLDIR $env(PC_RTL_DIR)
set OUT [file normalize "../../build/eda/ppa/$RUNID"]
file mkdir $OUT
file mkdir [file normalize "../../build/eda"]

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"

analyze -format sverilog [file join $RTLDIR parity_gen_check.sv]

set IMPLS {tree parity_impl_tree linear parity_impl_linear}
set W 64

foreach {tagmod toplevel} $IMPLS {
    set tag "${tagmod}_w${W}"
    remove_design -all
    elaborate $toplevel -parameters "DATA_WIDTH=$W"
    link

    create_clock -name vclk -period 2.5
    set_input_delay 0.5 -clock vclk [all_inputs]
    set_output_delay 0.5 -clock vclk [all_outputs]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
    set_load 0.01 [all_outputs]

    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"   { report_area }
    redirect -file "$OUT/${tag}_timing.rpt" { report_timing -max_paths 1 }
    redirect -file "$OUT/${tag}_power.rpt"  { report_power }

    set fh [open "$OUT/${tag}_summary.txt" w]
    puts $fh "tag=$tag"
    set ar [open "$OUT/${tag}_area.rpt" r]
    foreach ln [split [read $ar] "\n"] {
        if {[regexp {Total cell area:\s+([0-9.]+)} $ln -> a]} { puts $fh "area=$a" }
        if {[regexp {Combinational area:\s+([0-9.]+)} $ln -> a]} { puts $fh "comb=$a" }
    }
    close $ar
    set tr [open "$OUT/${tag}_timing.rpt" r]
    foreach ln [split [read $tr] "\n"] {
        if {[regexp {slack \((?:MET|VIOLATED)\)\s+(-?[0-9.]+)} $ln -> s]} { puts $fh "slack=$s" }
    }
    close $tr
    close $fh
    puts "PPA-DONE $tag"
}

puts "W64-COMPARE-COMPLETE runid=$RUNID"
exit
