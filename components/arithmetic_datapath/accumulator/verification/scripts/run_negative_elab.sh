#!/usr/bin/env bash
# ============================================================================
# run_negative_elab.sh — 负向参数 elaboration $error 拦截（REQ-006 / tc_negative_elab）
# 用法: bash verification/scripts/run_negative_elab.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/negative_elab.txt
# 纪律：每个非法 case 期望 vcs elaboration 非零退出且报错 ID（PC-xxx）；不以崩溃代替诊断。
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

RTL="$P/rtl/accumulator.sv"
TB="$P/verification/formal/negative_elab_tb.sv"

declare -A CASES=(
  [NEG_IW0]="INPUT_WIDTH=0 -> PC-001"
  [NEG_IW129]="INPUT_WIDTH=129 -> PC-007"
  [NEG_AW0]="ACC_WIDTH=0 -> PC-003"
  [NEG_AW257]="ACC_WIDTH=257 -> PC-008"
  [NEG_IWGT]="INPUT_WIDTH>ACC_WIDTH -> PC-002"
  [NEG_OP3]="OP_MODE=3 -> PC-004"
  [NEG_OVF2]="OVERFLOW_MODE=2 -> PC-005"
  [NEG_ISO2]="OPERAND_ISOLATION=2 -> PC-006"
)

: > "$EV/negative_elab.txt"
FAIL=0

if ! command -v vcs >/dev/null 2>&1; then
  echo "[BLOCKED] vcs not found" > "$EV/negative_elab.txt"
  echo "[BLOCKED] vcs not found"
  exit 0
fi

for name in "${!CASES[@]}"; do
  desc="${CASES[$name]}"
  set +e
  ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog +define+"$name" \
      "$RTL" "$TB" -top negative_elab_tb -o "/tmp/neg_$name" > "$EV/tmp_$name.log" 2>&1 )
  rc=$?
  set -e
  # 期望：elaboration 失败（非零），且日志含 PC- 报错；不允许运行到仿真阶段
  if [ $rc -eq 0 ]; then
    echo "[FAIL] $name ($desc): elaboration 未拒绝" | tee -a "$EV/negative_elab.txt"
    FAIL=1
  elif grep -q "PC-00" "$EV/tmp_$name.log"; then
    echo "[PASS] $name ($desc): elaboration 报错 PC-xxx 拦截" | tee -a "$EV/negative_elab.txt"
  else
    echo "[FAIL] $name ($desc): 非零退出但未见 PC-xxx 诊断" | tee -a "$EV/negative_elab.txt"
    FAIL=1
  fi
  rm -f "$EV/tmp_$name.log"
done

if [ $FAIL -eq 0 ]; then
  echo "[G3] negative elaboration PASS — 全部非法参数被 PC 报错拦截"
else
  echo "[G3] negative elaboration FAIL"
  exit 1
fi
echo "[G3] negative elab OK — evidence in $EV/"
