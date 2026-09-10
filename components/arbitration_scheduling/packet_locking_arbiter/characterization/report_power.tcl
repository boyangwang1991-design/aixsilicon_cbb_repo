# Replay total power reports from the saved mapped designs, without resynthesis.
set_app_var target_library [list $env(PLA_LIBRARY)]
set_app_var link_library [concat * $target_library]
foreach dir [lsort [glob -type d n*_m*_w*]] {
    remove_design -all
    read_ddc $dir/design.ddc
    current_design [get_designs packet_locking_arbiter*]
    link
    redirect -file $dir/power-total.txt {report_power}
}
puts PLA_POWER_DONE
exit
