# 环境与参数由本次运行的 context.tcl 固化。
source context.tcl
set_app_var target_library [list $TARGET_DB]
set_app_var link_library [concat * $target_library]
set_app_var compile_enable_register_merging false
set_svf synthesis.svf
if {![analyze -format sverilog -define SYNTHESIS dut.sv]} {error "LCL_ANALYZE_FAILED"}
if {![elaborate lockstep_comparator_logic -parameters $PARAMETERS]} {error "LCL_ELABORATE_FAILED"}
set top [current_design]
if {![link]} {error "LCL_LINK_FAILED"}
redirect -file elaborated_cells.rpt { foreach_in_collection c [get_cells -hierarchical *] {puts [get_object_name $c]} }
source preserve_redundancy.tcl
source constraints.sdc
set_operating_conditions $CORNER
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
# 禁止寄存器合并。映射后还必须检查两套存储与组合锥的实际独立性。
compile -map_effort medium
redirect -file check_design.rpt {check_design}
redirect -file area.rpt {report_area -hierarchy}
redirect -file timing.rpt {report_timing -delay_type max -max_paths 10 -nworst 10}
redirect -file reg_reg.rpt {report_timing -from [all_registers -output_pins] -to [all_registers -data_pins] -delay_type max -max_paths 10}
redirect -file power.rpt {report_power}
redirect -file power_hierarchy.rpt {report_power -hierarchy}
redirect -file clocks.rpt {report_clock}
redirect -file constraints.rpt {report_constraint -all_violators}
redirect -file registers.rpt {puts "REGISTERS [sizeof_collection [all_registers]]"; foreach_in_collection c [all_registers] {puts [get_object_name $c]}}
write -format verilog -hierarchy -output mapped.v
write -format ddc -hierarchy -output mapped.ddc
puts "LCL_SYNTH_PASS"
exit
