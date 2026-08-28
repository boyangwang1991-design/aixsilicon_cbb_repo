#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/{functional_sim.txt}
# 固定 seed: TB 内 SEED=32'hCBB_2026_0828（tc_random 可重放）
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/parity_gen_check.sv"
TB="$P/verification/simulation/parity_tb.sv"

# ---- tc_exhaust_w8 / tc_edge / tc_random / tc_equiv（单仿真四场景）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL $TB -o /tmp/pg_g4 \
    > "$EV/tmp_compile.log" 2>&1 )
/tmp/pg_g4 > "$EV/functional_sim.txt" 2>&1
grep -q "PARITY_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
echo "[sim] PARITY_TB PASS (exhaust_w8 + edge + random3000 + tree≡linear)"

rm -f "$EV/tmp_compile.log"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
