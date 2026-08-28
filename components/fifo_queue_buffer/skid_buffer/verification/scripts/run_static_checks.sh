#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线可复现脚本 (implement-cbb-rtl 纪律 #14)
# 用法: bash verification/scripts/run_static_checks.sh   （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/{param_matrix.txt, negative_w0.txt, negative_w1025.txt}
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# 负向参数：generate 块内 $error 在 elaboration 期拦截（PC-001/002，REQ-004）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/skid_buffer.sv"

# ---- 正向编译矩阵：DATA_W ∈ {1,8,32,64,128}（RTL 顶层，-pvalue 覆盖参数）----
: > "$EV/param_matrix.txt"
for w in 1 8 32 64 128; do
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+skid_buffer.DATA_W=$w \
        -o /tmp/skid_g3_${w} > "$EV/tmp.log" 2>&1 ) || {
        echo "FAIL DATA_W=$w" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
    echo "PASS DATA_W=$w" | tee -a "$EV/param_matrix.txt"
done

# ---- 负向参数：DATA_W=0（PC-001 越界）elaboration $error 拦截（REQ-004）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+skid_buffer.DATA_W=0 \
    -o /tmp/skid_neg0 > "$EV/negative_w0.txt" 2>&1 ) && {
    echo "negative DATA_W=0 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-001" "$EV/negative_w0.txt" || { echo "missing PC-001 id in negative_w0 log"; exit 1; }

# ---- 负向参数：DATA_W=1025（PC-002 越界）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+skid_buffer.DATA_W=1025 \
    -o /tmp/skid_neg1025 > "$EV/negative_w1025.txt" 2>&1 ) && {
    echo "negative DATA_W=1025 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-002" "$EV/negative_w1025.txt" || { echo "missing PC-002 id in negative_w1025 log"; exit 1; }

rm -f "$EV/tmp.log"
echo "[G3] static baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
