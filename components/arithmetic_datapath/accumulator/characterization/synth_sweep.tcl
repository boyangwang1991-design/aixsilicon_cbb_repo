# ============================================================================
# synth_sweep.tcl — accumulator G6 PPA 表征（参数 × 位宽 sweep）
# 库上下文：characterization/pdk.yaml（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz）；同步复位 rst_ni；A→A 反馈为关键路径
# 实现：accumulator（INPUT_WIDTH/ACC_WIDTH/SIGNED/OP_MODE/OVERFLOW_MODE 参数）
# 用法：IDE_CBB_ROOT=<cbb_root> IDE_RUN_ID=run-<id> dc_shell -f synth_sweep.tcl
# 产物：build/eda/ppa/<RUNID>/acc_<tag>_{area,timing,power}.rpt + *_summary.txt
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(IDE_RUN_ID)
set RTLDIR $env(IDE_RTL_DIR)
set CBBROOT $env(IDE_CBB_ROOT)
set OUT [file normalize "$CBBROOT/build/eda/ppa/$RUNID"]
file mkdir $OUT
file mkdir [file normalize "$CBBROOT/build/eda"]

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"

define_design_lib WORK -path $OUT/work
analyze -format sverilog [list [file join $RTLDIR accumulator.sv]] -define SYNTHESIS

# 代表点：位宽 × 运算 × 饱和 × 装载（PPA-01 native 基线）
set points {
  {iw 8   aw 16  sgn 1 op 0 ovf 0 ld 1 st 1 iso 0}
  {iw 16  aw 32  sgn 1 op 0 ovf 0 ld 1 st 1 iso 0}
  {iw 16  aw 32  sgn 1 op 2 ovf 0 ld 1 st 1 iso 0}
  {iw 16  aw 32  sgn 1 op 2 ovf 1 ld 1 st 1 iso 0}
  {iw 16  aw 32  sgn 0 op 0 ovf 0 ld 1 st 1 iso 0}
  {iw 16  aw 64  sgn 1 op 0 ovf 0 ld 1 st 1 iso 0}
  {iw 32  aw 64  sgn 1 op 0 ovf 0 ld 1 st 1 iso 0}
  {iw 32  aw 32  sgn 1 op 2 ovf 1 ld 1 st 1 iso 0}
  {iw 16  aw 32  sgn 1 op 0 ovf 0 ld 0 st 1 iso 0}
  {iw 16  aw 32  sgn 1 op 0 ovf 0 ld 1 st 0 iso 0}
  {iw 16  aw 32  sgn 1 op 2 ovf 0 ld 1 st 1 iso 1}
  {iw 16  aw 128 sgn 1 op 0 ovf 0 ld 1 st 1 iso 0}
}

foreach pt $points {
    array set p $pt
    set tag "iw${p(iw)}_aw${p(aw)}_sgn${p(sgn)}_op${p(op)}_ovf${p(ovf)}_ld${p(ld)}_st${p(st)}_iso${p(iso)}"
    remove_design -all
    elaborate accumulator \
        -parameters "INPUT_WIDTH=${p(iw)}, ACC_WIDTH=${p(aw)}, SIGNED=${p(sgn)}, OP_MODE=${p(op)}, OVERFLOW_MODE=${p(ovf)}, LOAD_EN=${p(ld)}, STATUS_EN=${p(st)}, OPERAND_ISOLATION=${p(iso)}"
    link

    create_clock -name vclk -period 2.5
    set_input_delay 0.5 -clock vclk [all_inputs]
    set_output_delay 0.5 -clock vclk [all_outputs]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
    set_load 0.01 [all_outputs]

    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"   { report_area }
    redirect -file "$OUT/${tag}_timing.rpt" { report_timing -max_paths 3 }
    redirect -file "$OUT/${tag}_power.rpt"  { report_power }

    set fh [open "$OUT/${tag}_summary.txt" w]
    puts $fh "tag=$tag iw=${p(iw)} aw=${p(aw)} sgn=${p(sgn)} op=${p(op)} ovf=${p(ovf)} ld=${p(ld)} st=${p(st)} iso=${p(iso)}"
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
        if {[regexp {Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+uW} $ln -> pw]} { puts $fh "dyn_power_uW=$pw" }
        if {[regexp {Cell Leakage Power\s+=\s+([0-9.eE+-]+)\s+nW} $ln -> pl]} { puts $fh "leak_power_nW=$pl" }
    }
    close $pr
    close $fh
    puts "PPA-DONE $tag"
    unset p
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
