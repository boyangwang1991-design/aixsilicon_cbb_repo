#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/{functional_sim.txt}
# 固定 seed: TB 内 SEED=32'hCBB_2026_0828（tc_random/tc_backpressure 可重放）
# 覆盖：DATA_W=32（默认）+ DATA_W=1（边界，tc_edge 位宽特化）
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/skid_buffer.sv"
TB="$P/verification/simulation/skid_buffer_tb.sv"
: > "$EV/functional_sim.txt"

for w in 32 1; do
    echo "===== DATA_W=$w =====" | tee -a "$EV/functional_sim.txt"
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL $TB \
        -pvalue+skid_buffer_tb.DATA_W=$w -o /tmp/skid_g4_${w} \
        > "$EV/tmp_compile_${w}.log" 2>&1 ) || {
        echo "compile DATA_W=$w FAILED"; cat "$EV/tmp_compile_${w}.log"; exit 1; }
    /tmp/skid_g4_${w} >> "$EV/functional_sim.txt" 2>&1
    rm -f "$EV/tmp_compile_${w}.log"
done

grep -q "SKID_BUFFER_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
echo "[sim] SKID_BUFFER_TB PASS (tc_random + tc_backpressure + tc_edge, DATA_W∈{32,1})"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
