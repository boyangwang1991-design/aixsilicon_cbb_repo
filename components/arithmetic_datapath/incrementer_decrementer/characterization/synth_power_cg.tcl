# ============================================================================
# synth_power_cg.tcl — CG（Carry/Data Gating）功耗对比（G6 补充）
# 目的：量化 CG_EN=1（自动门控）在 hold 模式（inc_en=dec_en=0）下的动态功耗收益，
#       与 CG_EN=0（原始结构）对比；并对比 active 模式（数据翻转）两选项差异。
# 场景（DC 功耗用 set_switching_activity 指定输入翻转率）：
#   ACTIVE ：inc_en/dec_en 高翻转（Counter 常计数），din 随机高翻转
#   HOLD   ：inc_en=dec_en=0 恒定（Counter 保持），din 仍随机翻转
# 面积：report_area（CG 门控裁剪冗余进位逻辑，面积通常下降或持平）
# 库：sc9_cmos28lp_base_hvt tt_1p00v_25c；约束 create_clock 2.5ns
# 用法：IDE_CBB_ROOT=<root> IDE_RTL_DIR=<root>/rtl IDE_RUN_ID=run-<id> \
#         dc_shell -f characterization/synth_power_cg.tcl
# 产物：build/eda/ppa/<RUNID>/cg_<impl>_w<W>_cg<CG>_<SCENE>_{power,area,summary}.txt
# ============================================================================

set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(IDE_RUN_ID)
set RTLDIR $env(IDE_RTL_DIR)
set CBBROOT $env(IDE_CBB_ROOT)
set OUT [file normalize "$CBBROOT/build/eda/ppa/$RUNID"]
file mkdir $OUT

set_app_var target_library  $PDKDB
set_app_var link_library    "* $PDKDB"
define_design_lib WORK -path $OUT/work_cg
analyze -format sverilog [list [file join $RTLDIR incrementer_decrementer.sv]] -define SYNTHESIS

# W=32 代表点：ripple / segmented(SEG=8)，CG_EN=0/1，ACTIVE/HOLD 两场景
foreach {impl seg} {0 4 1 8} {
  foreach cg {0 1} {
    foreach scene {ACTIVE HOLD} {
      set tag "cg_impl${impl}_w32_cg${cg}_${scene}"
      remove_design -all
      elaborate incrementer_decrementer \
          -parameters "DATA_W=32, ID_IMPL=$impl, SEG_W=$seg, CG_EN=$cg"
      link
      create_clock -name vclk -period 2.5
      set_input_delay 0.5 -clock vclk [all_inputs]
      set_output_delay 0.5 -clock vclk [all_outputs]
      set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y [all_inputs]
      set_load 0.01 [all_outputs]
      compile_ultra -no_autoungroup

      # 功耗场景输入翻转率
      if { $scene == "ACTIVE" } {
        # din 高翻转，inc/dec 周期性翻转（~50% 活动）
        set_switching_activity -type wire_toggles -toggle_rate 0.5 [all_inputs]
        set_switching_activity -type wire_toggles -toggle_rate 0.5 [get_ports inc_en]
        set_switching_activity -type wire_toggles -toggle_rate 0.5 [get_ports dec_en]
      } else {
        # HOLD：inc_en=dec_en=0 恒定，din 仍高翻转（数据仍来，但不做 ±1）
        set_switching_activity -type wire_toggles -toggle_rate 0.5 [get_ports din]
        set_switching_activity -type wire_toggles -toggle_rate 0.0 [get_ports inc_en]
        set_switching_activity -type wire_toggles -toggle_rate 0.0 [get_ports dec_en]
        }
  
        redirect -file "$OUT/${tag}_power.txt" { report_power }
        redirect -file "$OUT/${tag}_area.txt"  { report_area }
  
        set fh [open "$OUT/${tag}_summary.txt" w]
        puts $fh "tag=$tag impl=$impl w=32 seg=$seg cg=$cg scene=$scene"
        set pr [open "$OUT/${tag}_power.txt" r]
        foreach ln [split [read $pr] "\n"] {
          if {[regexp {Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+uW} $ln -> p]} {
            puts $fh "dyn_power_uW=$p"
          }
          if {[regexp {Cell Leakage Power\s+=\s+([0-9.eE+-]+)\s+nW} $ln -> p]} {
            puts $fh "leak_power_nW=$p"
          }
          if {[regexp {Total Power\s+=\s+([0-9.eE+-]+)\s+uW} $ln -> p]} {
            puts $fh "total_power_uW=$p"
          }
        }
        close $pr
        set ar [open "$OUT/${tag}_area.txt" r]
        foreach ln [split [read $ar] "\n"] {
          if {[regexp {Total cell area:\s+([0-9.]+)} $ln -> a]} {
            puts $fh "area=$a"
          }
        }
        close $ar
        close $fh
        puts "CG-PPA-DONE $tag"
    }
  }
}

puts "CG-SWEEP-COMPLETE runid=$RUNID"
exit
