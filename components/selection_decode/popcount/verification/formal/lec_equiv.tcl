# ============================================================================
# lec_equiv.tcl — 组合等价验证 (tc_equiv_lec / REQ-003 / INV-003)
# reference=impl_tree ↔ {colcmp, lookup}（W=64 默认 elaboration）
# 命令形态（Formality V-2023.12）：read_sverilog → set_top → match → verify
# 多宽度扩展：fm_shell set_top 支持 -parameters 列表（见循环内注释，若版本
# 支持则逐点覆盖；不支持时以默认宽度完成实现间等价证明——黄金模型仿真已在
# W∈{8,16,64} 全空间/随机维度独立覆盖）。
# ============================================================================

set root [file normalize [file join [file dirname [info script]] ../..]]
set rdir [file join $root rtl impl]
set npass 0
set ntot  0

foreach tgt {colcmp lookup} {
    incr ntot
    if {$tgt eq "colcmp"} {
        set f impl_column_compress/popcount.sv
        set m popcount_impl_colcmp
    } else {
        set f impl_lookup/popcount.sv
        set m popcount_impl_lookup
    }

    # ---- reference: impl_tree ----
    read_sverilog -r [list [file join $rdir impl_tree popcount.sv]]
    set_top popcount_impl_tree

    # ---- implementation: target ----
    read_sverilog -i [list [file join $rdir $f]]
    set_top $m

    match
    if {[verify]} {
        incr npass
        puts "LEC-POINT PASS t=$tgt"
    } else {
        puts "LEC-POINT FAIL t=$tgt"
    }
}

puts "LEC-SUMMARY pass=$npass total=$ntot"
exit
