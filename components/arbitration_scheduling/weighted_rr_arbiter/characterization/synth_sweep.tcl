# ============================================================================
# synth_sweep.tcl — weighted_rr_arbiter G6 PPA 表征（双实现 × 请求数 × WMODE）
# 库上下文：characterization/pdk.yaml 为唯一事实源（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz 起步，PDK README 建议）；时序模块主指标为 reg→reg slack
# 实现：wrapper weighted_rr_arbiter（PC_IMPL/NUM_REQ 参数选择）
# 用法（EDA 产物纪律：从 build/eda/ppa 目录启动 dc_shell，使 DC 工作文件
#       command.log/default.svf/alib-*/*.mr/*.pvl/*.syn 全部落在 build/ 下，不泄漏 CBB 根）：
#   cd <cbb>/build/eda/ppa
#   dc_shell -f <cbb>/characterization/synth_sweep.tcl
# 产物：build/eda/ppa/<RUNID>/impl<k>_n<N>_{area,timing,power}.rpt + *_summary.txt
#       （RUNID 由脚本内 PC_RUN_ID 设定；WMODE=1 平滑扫描见 run-…-02，本脚本默认 WMODE=0）
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
# 从 build/eda/ppa 启动：CBB 根 = 上 3 级（build/eda/ppa -> build -> eda -> <cbb>）
set CBBROOT [file normalize ../../../]
set RTLDIR [file join $CBBROOT rtl weighted_rr_arbiter.sv]
set RUNID run-20260829-01
set OUT [file normalize [pwd]/$RUNID]
file mkdir $OUT

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"

cd $OUT
analyze -format sverilog $RTLDIR

# 双实现 × 请求数（quota_counter / deficit_rotate PPA 形态对比；WMODE=0 quota 公平语义）
foreach {impl} {0 1} {
    foreach n {4 8 16} {
        set tag "impl${impl}_n${n}"
        remove_design -all
        elaborate weighted_rr_arbiter \
            -parameters "NUM_REQ=$n, WEIGHT_WIDTH=4, WMODE=0, FAST_GRANT=0, GRANT_ACK_EN=0, PC_IMPL=$impl"
        link

        # 绑定时钟源端口（PPA 子 skill：create_clock 须绑定 clk 端口，否则 FF 未约束、无 reg→reg slack）
        create_clock -name vclk -period 2.5 [get_ports clk]
        set_input_delay 0.5 -clock vclk [all_inputs]
        set_output_delay 0.5 -clock vclk [all_outputs]
        set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
        set_load 0.01 [all_outputs]

        compile_ultra -no_autoungroup
        redirect -file "$OUT/${tag}_area.rpt"   { report_area }
        redirect -file "$OUT/${tag}_timing.rpt" { report_timing -delay_type max -nworst 1 }
        redirect -file "$OUT/${tag}_power.rpt"  { report_power }

        set fh [open "$OUT/${tag}_summary.txt" w]
        puts $fh "tag=$tag impl=$impl n=$n wwidth=4 wmode=0 fast=0 ack=0"
        set ar [open "$OUT/${tag}_area.rpt" r]
        foreach ln [split [read $ar] "\n"] {
            if {[regexp {Total cell area:\s+([0-9.]+)} $ln -> a]} { puts $fh "area=$a" }
            if {[regexp {Number of registers:\s+([0-9]+)} $ln -> r]} { puts $fh "regs=$r" }
        }
        close $ar
        set tr [open "$OUT/${tag}_timing.rpt" r]
        set got 0
        foreach ln [split [read $tr] "\n"] {
            if {[regexp {data arrival time\s+([0-9.]+)} $ln -> a] && $got==0} { puts $fh "arrival=$a"; set got 1 }
            if {[regexp {slack \((?:MET|VIOLATED)\)\s+(-?[0-9.]+)} $ln -> s] && $got==0} { puts $fh "slack=$s" }
        }
        close $tr
        set pr [open "$OUT/${tag}_power.rpt" r]
        foreach ln [split [read $pr] "\n"] {
            if {[regexp {Total Dynamic Power\s+=\s+([0-9.]+)} $ln -> p]} { puts $fh "dyn_power_uW=$p" }
            if {[regexp {Total Leakage Power\s+=\s+([0-9.]+)} $ln -> p]} { puts $fh "leak_power_nW=$p" }
        }
        close $pr
        close $fh
        puts "PPA-DONE $tag"
    }
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
