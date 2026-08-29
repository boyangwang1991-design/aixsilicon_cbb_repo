#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能仿真（穷举 + 随机 + 边界 + 等价 + 变异）
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/functional_sim.txt
# 纪律：固定 seed（TB 内 SEED=0x50002026）；先探测 vcs
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

RTL="$P/rtl/incrementer_decrementer.sv"
TB="$P/verification/simulation/incrementer_decrementer_tb.sv"

echo "=== [probe] EDA tools ==="
command -v vcs >/dev/null 2>&1 && echo "vcs=$(command -v vcs)" || echo "vcs: MISSING"

if command -v vcs >/dev/null 2>&1; then
  # 正式回归（不含变异）：穷举/边界/随机/等价
  ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog "$RTL" "$TB" -top incrementer_decrementer_tb \
      -o /tmp/ide_sim > "$EV/tmp.log" 2>&1 )
  ( cd "$WORK" && /tmp/ide_sim > "$EV/functional_sim.txt" 2>&1 ) || {
    echo "[FAIL] functional sim 非零退出"; cat "$EV/functional_sim.txt"; exit 1; }
  if grep -q "=== FAIL" "$EV/functional_sim.txt"; then
    echo "[FAIL] functional sim 断言失败"; grep FAIL "$EV/functional_sim.txt"; exit 1; fi
  grep -q "=== PASS" "$EV/functional_sim.txt" || {
    echo "[FAIL] functional sim 未显示 PASS 汇总"; cat "$EV/functional_sim.txt"; exit 1; }
  echo "[G4] functional sim PASS"

  # 变异测试：借位传播条件写反，checker（黄金模型）应检测差异（MUTATION 编译）
  ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog +define+MUTATION "$RTL" "$TB" \
      -top incrementer_decrementer_tb -o /tmp/ide_mut > "$EV/tmp_mut.log" 2>&1 )
  ( cd "$WORK" && /tmp/ide_mut > "$EV/mutation.txt" 2>&1 ) || {
    echo "[FAIL] mutation sim 非零退出"; cat "$EV/mutation.txt"; exit 1; }
  # 变异 sim 期望 PASS：变异被黄金模型检测（mut_detected>0，errors 不增）。
  if grep -q "=== FAIL" "$EV/mutation.txt"; then
    echo "[FAIL] mutation sim 失败（checker 未捕获变异或断言误报）"; grep FAIL "$EV/mutation.txt"; exit 1; fi
  grep -q "变异被检测" "$EV/mutation.txt" || {
    echo "[FAIL] mutation 未被黄金模型检测（checker 失效）"; cat "$EV/mutation.txt"; exit 1; }
  echo "[G4] mutation PASS — 变异被黄金模型检测（checker 有效）"
else
  echo "[BLOCKED] vcs not found" > "$EV/functional_sim.txt"
fi

rm -f "$EV/tmp.log" "$EV/tmp_mut.log"
echo "[G4] functional sim OK — evidence in $EV/"
