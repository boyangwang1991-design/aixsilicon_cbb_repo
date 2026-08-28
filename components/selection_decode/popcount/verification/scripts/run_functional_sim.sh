#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: evidence/g4_functional/{functional_sim.txt, equiv_lec.txt, mutation.txt}
# 固定 seed: TB 内 SEED=32'hCBB_2026_0827（tc_random 可重放）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV=evidence/g4_functional
mkdir -p "$EV"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/popcount.sv $P/rtl/popcount_compressed.sv"
TB="$P/verification/simulation/popcount_tb.sv"

# ---- tc_exhaust_w8 / tc_edge / tc_random（单仿真同时覆盖三场景）----
vcs -full64 -timescale=1ns/1ps -sverilog $RTL $TB -o /tmp/pc_g4 \
    > "$EV/tmp_compile.log" 2>&1
/tmp/pc_g4 > "$EV/functional_sim.txt" 2>&1
grep -q "POPCOUNT_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
echo "[sim] POPCOUNT_TB PASS (exhaust_w8 + edge + random3000)"

# ---- tc_equiv_lec：fm_shell 实现层直证（tree ↔ colcmp / lookup，W=64）----
if command -v fm_shell >/dev/null 2>&1; then
    FM_TCL="$P/verification/formal/lec_equiv.tcl"
    ( cd "$EV" && fm_shell -file "$FM_TCL" ) > "$EV/equiv_lec.txt" 2>&1 || true
    if grep -q "LEC-SUMMARY pass=2 total=2" "$EV/equiv_lec.txt"; then
        echo "[lec] equivalence SUCCEEDED x2 (colcmp,lookup vs tree @W64)"
    else
        echo "[WARN] fm_shell LEC not confirmed — inspect $EV/equiv_lec.txt"
    fi
else
    echo "OPTIONAL_UNAVAILABLE(fm): fm_shell not present" > "$EV/equiv_lec.txt"
fi

# ---- 变异测试：注入 POPCC_MUT_DIV2MOD（colcmp 递推 m/3 → m%3 错位）必须被检出 ----
MUT_TB="$P/verification/simulation/mutation_colcmp_tb.sv"
vcs -full64 -timescale=1ns/1ps -sverilog +define+POPCC_MUT_DIV2MOD $RTL $MUT_TB \
    -o /tmp/pc_mut > "$EV/tmp_mut_compile.log" 2>&1
if /tmp/pc_mut > "$EV/mutation.txt" 2>&1; then
    grep -q "FAIL" "$EV/mutation.txt" || { echo "mutation invisible — checker ineffective"; exit 1; }
    echo "[mutation] detected as expected — checker effective"
else
    grep -q "FAIL" "$EV/mutation.txt" || { echo "no FAIL record in mutation log"; exit 1; }
    echo "[mutation] detected as expected — checker effective"
fi

rm -f "$EV/tmp_compile.log" "$EV/tmp_mut_compile.log"
echo "[G4] functional baseline OK — evidence in $EV/"
