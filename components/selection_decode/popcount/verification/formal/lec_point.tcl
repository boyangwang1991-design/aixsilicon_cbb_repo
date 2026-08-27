# ============================================================================
# lec_point.tcl — 单点组合等价：reference=impl_tree ↔ implementation=<target>
# 用法: fm_shell -f lec_point.tcl -xvars {W <width> TARGET <mod> SRC <file>}
# （fm_shell 变量经环境变量注入以兼容版本差异）
# ============================================================================

set wr     $env(PC_W)
set target $env(PC_TARGET)
set srcf   $env(PC_SRC)

set root [file normalize [file join [file dirname [info script]] ../..]]
set rdir [file join $root rtl impl]

create_design ref_d
read_sverilog -r [list [file join $rdir impl_tree popcount.sv]]
set_top_module popcount_impl_tree
elaborate_reference -verify_only

create_design imp_d
read_sverilog -i [list [file join $rdir $srcf]]
set_top_module $target
elaborate_implementation

match_compare_points
verify

report_status
exit
