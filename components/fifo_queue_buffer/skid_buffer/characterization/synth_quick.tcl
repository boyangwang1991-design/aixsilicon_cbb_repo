# ============================================================================
# synth_quick.tcl — skid_buffer G6 PPA 快速综合（DATA_W ∈ {8,32,128}）
# 库上下文：characterization/pdk.yaml（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz）；时序模块（clk/rst_n）
# 用法：PC_CBB_ROOT=<cbb_root> PC_RTL_DIR=<rtl> PC_RUN_ID=run-<id> dc_shell -f synth_quick.tcl
# 产物：build/eda/ppa/<RUNID>/skid_w<W>_{area,timing,power}.rpt + *_summary.txt
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

    create_clock -name vclk -period 2.5
    set_input_delay  0.2 -clock vclk [get_ports {in_valid in_data}]
    set_output_delay 0.2 -clock vclk [get_ports {out_valid out_data in_ready}]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [get_ports {in_valid in_data out_ready}]
    set_load 0.01 [get_ports {out_valid out_data in_ready}]

    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"   { report_area }
    redirect -file "$OUT/${tag}_timing.rpt" { report_timing -max_paths 1 }
    redirect -file "$OUT/${tag}_power.rpt"  { report_power }

    set fh [open "$OUT/${tag}_summary.txt" w]
    puts $fh "tag=$tag data_w=$w"
    set ar [open "$OUT/${tag}_area.rpt" r]
    foreach ln [split [read $ar] "\n"] {
        if {[regexp {Total cell area:\s+([0-9.]+)} $ln -> a]} { puts $fh "area=$a" }
    }
    close $ar
    set tr [open "$OUT/${tag}_timing.rpt" r]
    foreach ln [split [read $tr] "\n"] {
        if {[regexp {data arrival time\s+([0-9.]+)} $ln -> a]} { puts $fh "arrival=$a" }
        if {[regexp {slack \((?:MET|VIOLATED)\)\s+(-?[0-9.]+)} $ln -> s]} { puts $fh "slack=$s" }
    }
    close $tr
    set pr [open "$OUT/${tag}_power.rpt" r]
    foreach ln [split [read $pr] "\n"] {
        if {[regexp {Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+uW} $ln -> p]} {
            puts $fh "dyn_power_uW=$p"
        }
        if {[regexp {Cell Leakage Power\s+=\s+([0-9.eE+-]+)\s+nW} $ln -> p]} {
            puts $fh "leak_power_nW=$p"
        }
    }
    close $pr
    close $fh
    puts "PPA-DONE $tag"
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
