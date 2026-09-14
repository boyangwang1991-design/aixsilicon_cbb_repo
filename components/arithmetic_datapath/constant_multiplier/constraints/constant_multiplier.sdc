# Representative experiment constraints; set CM_LATENCY and CM_PERIOD before sourcing.
# Values match characterization/plan.yaml. This is not a chip timing signoff target.
if {![info exists CM_LATENCY]} {set CM_LATENCY 0}
if {![info exists CM_PERIOD]} {set CM_PERIOD 2.5}
if {$CM_LATENCY > 0} {
  create_clock -name clk -period $CM_PERIOD [get_ports clk_i]
} else {
  create_clock -name clk -period $CM_PERIOD
  set_false_path -from [get_ports {clk_i rst_ni ce_i}]
}
set_input_delay 0.25 -clock clk [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay 0.25 -clock clk [all_outputs]
set_input_transition 0.05 [all_inputs]
set_load 0.01 [all_outputs]
set_clock_uncertainty 0.05 [get_clocks clk]
