# ============================================================================
# synth_sweep.tcl — fixed_priority_arbiter G6 PPA 表征（三实现 × 请求数）
# 库上下文：characterization/pdk.yaml 为唯一事实源（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz 起步，PDK README 建议）；组合路径以 data arrival 度量
# 实现：wrapper fixed_priority_arbiter（PC_IMPL/NUM_REQ 参数选择；FAST_GRANT=0/REQ_TYPE=0 纯组合）
# 用法：PC_RTL_DIR=<cbb>/rtl PC_RUN_ID=run-<id> dc_shell -f synth_sweep.tcl
# 产物：build/eda/ppa/<RUNID>/impl<k>_n<N>_{area,timing,power}.rpt + *_summary.txt
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(PC_RUN_ID)
set RTLDIR $env(PC_RTL_DIR)
# 输出到 CBB 根 build/eda/ppa/<RUNID>（脚本从 CBB 根 execution 目录运行：
#   cd <cbb_root>/characterization && PC_RTL_DIR=<cbb>/rtl ... → ../../ 即 <cbb_root>/.. 层级；
# 统一约定：脚本由 <cbb_root> 下 run 脚本调用时以绝对路径锚定 CBB 根）
set CBBROOT $env(PC_CBB_ROOT)
set OUT [file normalize "$CBBROOT/build/eda/ppa/$RUNID"]
file mkdir $OUT
file mkdir [file normalize "$CBBROOT/build/eda"]

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"

analyze -format sverilog [file join $RTLDIR fixed_priority_arbiter.sv]

# 三实现 × 请求数（linear/tree/grouped PPA 形态对比）
foreach {impl} {0 1 2} {
    foreach n {4 8 16 32 64} {
        set tag "impl${impl}_n${n}"
        remove_design -all
        elaborate fixed_priority_arbiter \
            -parameters "NUM_REQ=$n, PRIORITY=0, REQ_TYPE=0, FAST_GRANT=0, PC_IMPL=$impl"
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
        puts $fh "tag=$tag impl=$impl n=$n"
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
        close $fh
        puts "PPA-DONE $tag"
    }
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
