# ============================================================================
# synth_sweep.tcl — popcount G6 PPA 表征（五实现 × 数据位宽）
# 库上下文：characterization/pdk.yaml（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz）；组合路径以 data arrival 度量
# 实现：wrapper popcount（DATA_W/PC_IMPL 参数选择，纯组合）
# 用法：PC_CBB_ROOT=<cbb_root> PC_RUN_ID=run-<id> dc_shell -f synth_sweep.tcl
# 产物：build/eda/ppa/<RUNID>/impl<k>_w<W>_{area,timing,power}.rpt + *_summary.txt
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

# rtl/gen/*.sv 经 `include 引入：analyze 需加 include 目录（=RTLDIR 自身）
define_design_lib WORK -path $OUT/work
analyze -format sverilog [list [file join $RTLDIR popcount.sv]] -define SYNTHESIS

# 五实现 × 数据位宽（direct/tree/wallace/comp4_2/lut）
foreach {impl} {0 1 2 3 4} {
    foreach w {8 16 32 64} {
        set tag "impl${impl}_w${w}"
        remove_design -all
        elaborate popcount \
            -parameters "DATA_W=$w, PC_IMPL=$impl"
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
        puts $fh "tag=$tag impl=$impl w=$w"
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
        # 功耗提取（2026-08-28 修复：早期版本 summary 漏抓 power 字段）
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
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
