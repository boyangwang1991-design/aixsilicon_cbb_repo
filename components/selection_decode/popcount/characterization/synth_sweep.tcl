# ============================================================================
# synth_sweep.tcl — G6 PPA 表征 (popcount 三实现 × 5 宽度)
# 库上下文：characterization/pdk.yaml 为唯一事实源（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：纯组合 → 虚拟时钟 create_clock 2.5ns（400MHz 起步）
# 实现选择：直接 elaborate 各 impl 子模块顶层——
#   dc_shell V-2023.12 对 wrapper generate-case 的 -parameters 覆盖不生效
#   （case 保持 default 分支 → impl1/2 数据与 impl0 混同），故子模块直证。
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(PC_RUN_ID)
set RTLDIR $env(PC_RTL_DIR)
set OUT [file normalize "../../build/eda/ppa/$RUNID"]
file mkdir $OUT
file mkdir [file normalize "../../build/eda"]

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"

analyze -format sverilog [list \
    [file join $RTLDIR popcount.sv] \
    [file join $RTLDIR popcount_compressed.sv] \
    [file join $RTLDIR popcount_compressed.sv]]

set IMPLS {tree popcount_impl_tree colcmp popcount_impl_colcmp dadda popcount_impl_dadda}

foreach {tagmod toplevel} $IMPLS {
    foreach w {8 16 32 64 128} {
        set tag "${tagmod}_w${w}"
        remove_design -all
        elaborate $toplevel -parameters "INPUT_WIDTH=$w"
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

        # 摘要行（供 Pareto 解析；宽字符匹配 report_area 多形态）
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
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
