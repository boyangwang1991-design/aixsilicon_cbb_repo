#!/usr/bin/env bash
# ============================================================================
# run_config_matrix_sim.sh — G5 配置空间验证（RTL 功能仿真 × 配置矩阵）
# 对 config-gen 生成的 boundary/pairwise 关键配置逐点跑 VCS 功能仿真，
# 验证各参数组合可编译、可运行且基本数值语义正确（加/减/回绕/饱和）。
# 用法: bash verification/scripts/run_config_matrix_sim.sh （从 CBB 根目录）
# 产出: build/eda/evidence/g5_config/config_matrix_sim.txt
# 纪律：固定 seed；每个配置独立编译；证据落盘 build/eda/evidence/g5_config/。
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g5_config"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

RTL="$P/rtl/accumulator.sv"
MATRIX_TB="$P/verification/simulation/config_matrix_tb.sv"

if ! command -v vcs >/dev/null 2>&1; then
  echo "[BLOCKED] vcs not found" > "$EV/config_matrix_sim.txt"
  echo "[BLOCKED] vcs not found"
  exit 0
fi

# 配置矩阵：参数名=值;...  （覆盖 boundary/pairwise 关键组合）
CONFIGS=(
  "INPUT_WIDTH=1;ACC_WIDTH=32;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=8;ACC_WIDTH=32;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=16;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=64;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=32;ACC_WIDTH=32;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=32;SIGNED=0;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=32;SIGNED=1;OP_MODE=1;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=32;SIGNED=1;OP_MODE=2;OVERFLOW_MODE=1;LOAD_EN=1;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=32;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=0;STATUS_EN=1;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=32;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=0;ISO=0"
  "INPUT_WIDTH=16;ACC_WIDTH=32;SIGNED=1;OP_MODE=2;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=1"
  "INPUT_WIDTH=16;ACC_WIDTH=128;SIGNED=1;OP_MODE=0;OVERFLOW_MODE=0;LOAD_EN=1;STATUS_EN=1;ISO=0"
)

: > "$EV/config_matrix_sim.txt"
FAIL=0
for cfg in "${CONFIGS[@]}"; do
  # 生成 TB 参数 define
  DEFS=""
  IFS=';' read -ra KV <<< "$cfg"
  for kv in "${KV[@]}"; do
    DEFS="$DEFS +define+${kv%%=*}=${kv#*=}"
  done
  # 编译 + 运行（固定 seed）
  if ! ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $DEFS \
      "$RTL" "$MATRIX_TB" -top config_matrix_tb -o /tmp/cm_sim > "$EV/tmp_cfg.log" 2>&1 \
      && /tmp/cm_sim >> "$EV/config_matrix_sim.txt" 2>&1 ); then
    echo "[FAIL] config [$cfg] 编译/运行失败" | tee -a "$EV/config_matrix_sim.txt"
    tail -5 "$EV/tmp_cfg.log" >> "$EV/config_matrix_sim.txt"
    FAIL=1
    continue
  fi
  if grep -q "CONFIG_FAIL" "$EV/config_matrix_sim.txt"; then
    echo "[FAIL] config [$cfg] 功能断言失败" | tee -a "$EV/config_matrix_sim.txt"
    FAIL=1
  else
    echo "[PASS] config [$cfg]" | tee -a "$EV/config_matrix_sim.txt"
  fi
  rm -f "$EV/tmp_cfg.log"
done

if [ $FAIL -eq 0 ]; then
  echo "[G5] config matrix sim PASS — ${#CONFIGS[@]} 配置全部通过" | tee -a "$EV/config_matrix_sim.txt"
else
  echo "[G5] config matrix sim FAIL" | tee -a "$EV/config_matrix_sim.txt"
  exit 1
fi
echo "[G5] OK — evidence in $EV/"
