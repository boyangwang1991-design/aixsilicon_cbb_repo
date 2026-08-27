set PDKDB /home/eda/pdk/CMOS28NM/extracted/GF21LB004-FB-00000-r5p0-03rel0/arm/cp/cmos28lp/sc9_base_hvt/r5p0/db/sc9_cmos28lp_base_hvt_tt_nominal_max_1p00v_25c.db
set RUNID $env(PC_RUN_ID)
set RTLDIR $env(PC_RTL_DIR)
set OUT [file normalize "../evidence/ppa/$RUNID"]
set_app_var target_library $PDKDB
set_app_var link_library "* $PDKDB"
analyze -format sverilog [list [file join $RTLDIR impl impl_dadda popcount.sv]]
foreach w {16 32 64 128} {
    set tag "dadda_w${w}"
    remove_design -all
    elaborate popcount_impl_dadda -parameters "INPUT_WIDTH=$w"
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
        if {[regexp {Combinational area:\s+([0-9.]+)} $ln -> a2]} { puts $fh "comb=$a2" }
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
puts "REST-COMPLETE"
exit
