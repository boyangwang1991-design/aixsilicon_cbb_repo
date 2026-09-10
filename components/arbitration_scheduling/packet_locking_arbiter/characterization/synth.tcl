# SPDX-License-Identifier: Apache-2.0
# Runner starts DC inside an isolated build/eda/ppa/run directory.
set_app_var target_library [list $env(PLA_LIBRARY)]
set_app_var link_library [concat * $target_library]
set_svf design.svf
analyze -format sverilog [list $env(PLA_DEP) $env(PLA_RTL)]
elaborate packet_locking_arbiter -parameters "NUM_REQ=$env(PLA_N),LOCK_MODE=$env(PLA_MODE),LEN_W=$env(PLA_W)"
# elaborate selects the parameter-specialized current design automatically.
link
source $env(PLA_SDC)
set inputs [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_driving_cell -lib_cell BUFH_X4M_A9TH -pin Y $inputs
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 $inputs
compile_ultra -no_autoungroup
redirect -file area.txt {report_area -hierarchy}
redirect -file timing.txt {report_timing -delay_type max -max_paths 10 -nworst 1}
redirect -file reg_timing.txt {report_timing -from [all_registers -output_pins] -to [all_registers -data_pins] -delay_type max -max_paths 10}
redirect -file output_timing.txt {report_timing -to [all_outputs] -delay_type max -max_paths 10}
redirect -file power.txt {report_power -hierarchy}
redirect -file clock.txt {report_clock}
redirect -file check.txt {check_design}
redirect -file constraints.txt {report_constraint -all_violators}
set f [open registers.txt w]
puts $f [sizeof_collection [all_registers]]
close $f
write -format verilog -hierarchy -output netlist.v
write -format ddc -hierarchy -output design.ddc
write_sdc mapped.sdc
set_svf -off
puts PLA_SYNTH_DONE
exit
