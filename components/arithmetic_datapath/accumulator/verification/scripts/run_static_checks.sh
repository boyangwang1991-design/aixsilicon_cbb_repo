#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线（Compile / Elaboration / 负向参数）
# 用法: bash verification/scripts/run_static_checks.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/compile.txt + negative_elab.txt
# 纪律：先探测原生工具（command -v vcs）；VCS 在 build/eda/ 下运行
#       （csrc 等产物进 build/）；证据以 *.txt 落盘 build/eda/evidence/g3_static/。
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

RTL="$P/rtl/accumulator.sv"

echo "=== [probe] EDA tools ==="
command -v vcs >/dev/null 2>&1 && echo "vcs=$(command -v vcs)" || echo "vcs: MISSING"

if ! command -v vcs >/dev/null 2>&1; then
  echo "[BLOCKED] vcs not found" > "$EV/compile.txt"
  echo "[BLOCKED] vcs not found"
  exit 0
fi

# 1) 默认配置 Compile + Elaboration（合法参数基线）
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog "$RTL" -top accumulator \
    -o /tmp/acc_static > "$EV/compile.txt" 2>&1 ) || {
  echo "[FAIL] compile/elaboration 非零退出"; tail -20 "$EV/compile.txt"; exit 1; }
echo "[G3] compile+elaboration PASS（默认配置）"

# 2) 负向参数 elaboration $error 拦截（REQ-006 / tc_negative_elab）
bash "$P/verification/scripts/run_negative_elab.sh"

echo "[G3] static checks OK — evidence in $EV/"
