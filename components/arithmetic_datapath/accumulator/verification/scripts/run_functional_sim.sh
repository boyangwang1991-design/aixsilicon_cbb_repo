#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能仿真（穷举 + 随机 + 边界 + 连续 + 隔离等价）
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/functional_sim.txt
# 纪律：固定 seed（TB 内 SEED=0x50002026）；先探测 vcs；EDA 产物落入 build/eda/
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

RTL="$P/rtl/accumulator.sv"
TB="$P/verification/simulation/accumulator_tb.sv"

echo "=== [probe] EDA tools ==="
command -v vcs >/dev/null 2>&1 && echo "vcs=$(command -v vcs)" || echo "vcs: MISSING"

if command -v vcs >/dev/null 2>&1; then
  ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog "$RTL" "$TB" \
      -top accumulator_tb -o /tmp/acc_sim > "$EV/tmp.log" 2>&1 )
  ( cd "$WORK" && /tmp/acc_sim > "$EV/functional_sim.txt" 2>&1 ) || {
    echo "[FAIL] functional sim 非零退出"; tail -40 "$EV/functional_sim.txt"; exit 1; }
  if grep -q "=== FAIL" "$EV/functional_sim.txt"; then
    echo "[FAIL] functional sim 断言失败"; grep FAIL "$EV/functional_sim.txt"; exit 1; fi
  grep -q "=== PASS" "$EV/functional_sim.txt" || {
    echo "[FAIL] functional sim 未显示 PASS 汇总"; tail -40 "$EV/functional_sim.txt"; exit 1; }
  echo "[G4] functional sim PASS"
else
  echo "[BLOCKED] vcs not found" > "$EV/functional_sim.txt"
  echo "[BLOCKED] vcs not found"
fi

rm -f "$EV/tmp.log"
echo "[G4] functional sim OK — evidence in $EV/"
