# ============================================================================
# synth_sweep.tcl — parity_gen_check G6 PPA 表征（双实现 × 6 宽度）
# 库上下文：characterization/pdk.yaml 为唯一事实源（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：纯组合 → 虚拟时钟 create_clock 2.5ns（400MHz 起步）——与 G6 基线一致
# 实现：子模块直证（parity_impl_tree / parity_impl_linear）
# 用法：PC_RTL_DIR=<cbb>/rtl PC_RUN_ID=run-<id> dc_shell -f synth_sweep.tcl
# 产物：build/eda/ppa/<RUNID>/{tree,linear}_w<W>_{area,timing,power}.rpt + *_summary.txt
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

foreach {tagmod toplevel} $IMPLS {
    foreach w {8 16 32 64 128 256} {
        set tag "${tagmod}_w${w}"
        remove_design -all
        elaborate $toplevel -parameters "DATA_WIDTH=$w"
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
        }
        close $ar
        set tr [open "$OUT/${tag}_timing.rpt" r]
        foreach ln [split [read $tr] "\n"] {
            if {[regexp {slack \((?:MET|VIOLATED)\)\s+(-?[0-9.]+)} $ln -> s]} { puts $fh "slack=$s" }
            # 纯组合构件时序主指标 = data arrival time（输入→输出传播延迟，
            # 独立于虚拟时钟周期；slack 依赖时钟设定仅作参考）
            if {[regexp {data arrival time\s+([0-9.]+)} $ln -> a]} { puts $fh "arrival=$a" }
        }
        close $tr
        close $fh
        puts "PPA-DONE $tag"
    }
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
