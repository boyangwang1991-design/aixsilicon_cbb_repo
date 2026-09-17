# ============================================================================
# synth_sweep.tcl — parallel_data_fetch G6 PPA 表征（参数 × 微架构 sweep）
#
# 库上下文：characterization/pdk.yaml（sc9_cmos28lp_base_hvt tt_nominal_max_1p00v_25c）
# 约束：create_clock 2.5ns（400MHz，同步模式单钟；异步模式两域分别约束）
# 时钟：同步模式 A/B 同一时钟（1 域）；异步模式 A/B 各自时钟（2 域，跨域结构为
#       toggle 同步器 + Gray 指针 async FIFO，CDC 例外由后端约束处理，不在此处伪造 slack）
#
# 用法：IDE_CBB_ROOT=<cbb_root> IDE_RUN_ID=run-<id> dc_shell -f synth_sweep.tcl
# 产物：build/eda/ppa/<RUNID>/pdf_<tag>_{area,timing,power}.rpt + *_summary.txt
#
# 关注点（对齐 docs/design.md §6 的 PPA 推理）：
#   * 快照 + 重组寄存器面积（∝ DATA_WIDTH）
#   * 切片三实现（shift / indexed / banked）的面积-时序取舍
#   * LINK_PIPE_STAGES 级数对时序/面积的影响
#   * async FIFO 的增量成本（深度 × LINK_WIDTH）
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID   $env(IDE_RUN_ID)
set RTLDIR  $env(IDE_RTL_DIR)
set CBBROOT $env(IDE_CBB_ROOT)
set OUT [file normalize "$CBBROOT/build/eda/ppa/$RUNID"]
file mkdir $OUT
file mkdir [file normalize "$CBBROOT/build/eda"]

set_app_var target_library $PDKDB
set_app_var link_library   "* $PDKDB"

# 读入三个模块（端点 + 链路单元都在 provider 文件内；wrapper 做同层集成）
analyze -format sverilog [list \
  [file join $RTLDIR parallel_data_fetch_requester.sv] \
  [file join $RTLDIR parallel_data_fetch_provider.sv] \
  [file join $RTLDIR parallel_data_fetch.sv] ] -define SYNTHESIS

# ---------------------------------------------------------------------------
# 代表点（同时声明在 characterization/plan.yaml 的 points 中）
#   dw/lw   : DATA_WIDTH / LINK_WIDTH
#   pipe    : 同步模式长线 pipeline 级数
#   slice   : 0=shift 1=indexed 2=banked
#   amode   : 0=sync 1=async（async 时 fifo 深度生效）
#   fifo    : RSP_FIFO_DEPTH（async 模式需 >= dw/lw）
# ---------------------------------------------------------------------------
set points {
  {tag dw256_lw32_slice2        dw 256  lw 32  pipe 0 slice 2 amode 0 fifo 16}
  {tag dw256_lw32_slice0        dw 256  lw 32  pipe 0 slice 0 amode 0 fifo 16}
  {tag dw256_lw32_slice1        dw 256  lw 32  pipe 0 slice 1 amode 0 fifo 16}
  {tag dw256_lw32_pipe1         dw 256  lw 32  pipe 1 slice 2 amode 0 fifo 16}
  {tag dw256_lw32_pipe8         dw 256  lw 32  pipe 8 slice 2 amode 0 fifo 16}
  {tag dw512_lw64_slice2        dw 512  lw 64  pipe 0 slice 2 amode 0 fifo 16}
  {tag dw1024_lw128_slice2      dw 1024 lw 128 pipe 0 slice 2 amode 0 fifo 16}
  {tag dw64_lw32_slice2         dw 64   lw 32  pipe 0 slice 2 amode 0 fifo 16}
  {tag dw256_lw32_async         dw 256  lw 32  pipe 0 slice 2 amode 1 fifo 16}
  {tag dw256_lw32_async_fifo8   dw 256  lw 32  pipe 0 slice 2 amode 1 fifo 8}
}

foreach pt $points {
    array set p $pt
    set tag $p(tag)
    set beats [expr {$p(dw) / $p(lw)}]

    # 异步模式约束检查（与契约 PC-006 一致，避免不合法点进入表征）
    if {$p(amode) == 1 && $p(fifo) < $beats} {
        puts "PPA-SKIP $tag (fifo depth < beat_count; illegal per PC-006)"
        unset p
        continue
    }

    remove_design -all
    elaborate parallel_data_fetch \
        -parameters "DATA_WIDTH=$p(dw), LINK_WIDTH=$p(lw), LSB_FIRST=1, ASYNC_MODE=$p(amode), PARITY_EN=1, ODD_PARITY=0, TIMEOUT_EN=1, TIMEOUT_CYCLES=1024, REQ_SYNC_STAGES=2, RSP_FIFO_DEPTH=$p(fifo), LINK_PIPE_STAGES=$p(pipe), SLICE_IMPL=$p(slice), RESET_DEFAULT_DATA=0"
    link

    # 时钟约束：同步 1 域；异步 2 域（A/B 各 400MHz，跨域路径由 CDC 例外处理）
    create_clock -name a_clk -period 2.5 [get_ports a_clk_i]
    if {$p(amode) == 1} {
        create_clock -name b_clk -period 2.5 [get_ports b_clk_i]
        # 跨域结构（toggle 同步器 / async FIFO 指针）按标准 CDC 例外处理，
        # 不在综合阶段伪造 setup slack（见 ppa-evidence §3b）
        set_clock_groups -asynchronous -group {a_clk} -group {b_clk}
    }
    # 同步模式只有 a_clk（A/B 同一时钟），无需 set_clock_groups（空组会报 CMD-036）
    set_input_delay  0.5 -clock a_clk [remove_from_collection [all_inputs] [get_ports a_clk_i]]
    set_output_delay 0.5 -clock a_clk [all_outputs]
    set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [remove_from_collection [all_inputs] [get_ports a_clk_i]]
    set_load 0.01 [all_outputs]
    set_operating_conditions tt_nominal_max_1p00v_25c

    compile_ultra -no_autoungroup
    redirect -file "$OUT/pdf_${tag}_area.rpt"   { report_area }
    redirect -file "$OUT/pdf_${tag}_timing.rpt" { report_timing -max_paths 3 }
    redirect -file "$OUT/pdf_${tag}_power.rpt"  { report_power }

    set fh [open "$OUT/pdf_${tag}_summary.txt" w]
    puts $fh "tag=$tag dw=$p(dw) lw=$p(lw) beat_count=$beats pipe=$p(pipe) slice=$p(slice) async=$p(amode) fifo=$p(fifo)"
    set ar [open "$OUT/pdf_${tag}_area.rpt" r]
    foreach ln [split [read $ar] "\n"] {
        if {[regexp {Total cell area:\s+([0-9.]+)} $ln -> a]} { puts $fh "area=$a" }
        if {[regexp {Number of ports:\s+([0-9]+)} $ln -> np]} { puts $fh "ports=$np" }
    }
    close $ar
    set tr [open "$OUT/pdf_${tag}_timing.rpt" r]
    foreach ln [split [read $tr] "\n"] {
        if {[regexp {data arrival time\s+([0-9.]+)} $ln -> a]} { puts $fh "arrival=$a" }
        if {[regexp {slack \((?:MET|VIOLATED)\)\s+(-?[0-9.]+)} $ln -> s]} { puts $fh "slack=$s" }
    }
    close $tr
    set pr [open "$OUT/pdf_${tag}_power.rpt" r]
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