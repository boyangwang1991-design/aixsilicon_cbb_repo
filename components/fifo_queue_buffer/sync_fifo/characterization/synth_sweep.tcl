# ============================================================================
# synth_sweep.tcl — sync_fifo G6 PPA 多实现对比综合
# 库上下文：characterization/pdk.yaml 为唯一事实源（sc9_cmos28lp_base_hvt tt_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz，PDK README 建议）绑定 clk 端口（时序模块必须）
# 配置矩阵（IMPL × OUTPUT_REG × DEPTH，DATA_W=32 固定）：
#   register×comb  : sync_rc_d<DEPTH>  (IMPL=0, OUTPUT_REG=0) 读写指针+寄存器堆，组合读出
#   register×reg   : sync_rr_d<DEPTH>  (IMPL=0, OUTPUT_REG=1) 读写指针+寄存器堆，寄存输出级
#   shift×comb     : sync_sc_d<DEPTH>  (IMPL=1, OUTPUT_REG=0) 移位存储，组合读出（无读 mux）
#   shift×reg      : sync_sr_d<DEPTH>  (IMPL=1, OUTPUT_REG=1) 移位存储，寄存输出级
# 方法论：一次综合记录完整报告集（area/timing_max/io/power/regs），不内嵌解析，
#         指标由 extract_ppa.py 独立抽取（避免电路未变时反复综合）。
# 时序判据：reg→reg 最差 setup slack 主判据（timing_max.rpt vclk group）；
#          comb 输出（reg→out/组合 out）arrival 作 IO 参考，不作时序结论。
# 用法：PC_CBB_ROOT=<cbb_root> PC_RTL_DIR=<rtl> PC_RUN_ID=run-<id> dc_shell -f synth_sweep.tcl
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
analyze -format sverilog [list [file join $RTLDIR sync_fifo.sv]]

set SYN_OPTS {compile_ultra -no_autoungroup}
set CLK_PORT {clk}
set IN_PORTS  {push_i data_i pop_i}
set OUT_PORTS {full_o rd_valid_o rd_data_o empty_o count_o}

# 通用综合/报告过程
proc run_one {tag impl outreg depth} {
    upvar OUT OUT
    global RTLDIR
    remove_design -all
    elaborate sync_fifo -parameters "DATA_W=32, DEPTH=$depth, OUTPUT_REG=$outreg, IMPL=$impl"
    link
    create_clock -name vclk -period 2.5 [get_ports clk]
    set_input_delay  0.2 -clock vclk [get_ports {push_i data_i pop_i}]
    set_output_delay 0.2 -clock vclk [get_ports {full_o rd_valid_o rd_data_o empty_o count_o}]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [get_ports {push_i data_i pop_i}]
    set_load 0.01 [get_ports {full_o rd_valid_o rd_data_o empty_o count_o}]
    compile_ultra -no_autoungroup
    redirect -file "$OUT/${tag}_area.rpt"       { report_area }
    redirect -file "$OUT/${tag}_timing_max.rpt" { report_timing -delay_type max -nworst 10 -path_type full }
    redirect -file "$OUT/${tag}_io.rpt"         { report_timing -delay_type max -to [get_ports {rd_data_o full_o empty_o}] -path_type full }
    redirect -file "$OUT/${tag}_power.rpt"      { report_power }
    redirect -file "$OUT/${tag}_regs.txt"       { puts [sizeof_collection [all_registers]] }
    puts "PPA-DONE $tag"
}

# ---- register×comb / register×reg（DEPTH 8/32：读侧 mux 随深度增长）----
foreach {impl outreg pre} {0 0 rc  0 1 rr} {
    foreach depth {8 32} {
        run_one "sync_${pre}_d${depth}" $impl $outreg $depth
    }
}

# ---- shift×comb / shift×reg（DEPTH 8/32：移位链随深度增长）----
foreach {impl outreg pre} {1 0 sc  1 1 sr} {
    foreach depth {8 32} {
        run_one "sync_${pre}_d${depth}" $impl $outreg $depth
    }
}

puts "SWEEP-COMPLETE runid=$RUNID"
exit
