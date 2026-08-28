#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_static_checks.sh   （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/{param_matrix.txt, negative_w3.txt, negative_impl.txt}
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/parity_gen_check.sv"

# ---- 正向编译矩阵：三实现 × {4,8,33,64,127,256}（含非 2 幂）----
: > "$EV/param_matrix.txt"
for impl in 0 1 2; do
    for w in 4 8 33 64 127 256; do
        ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
            -pvalue+parity_gen_check.DATA_WIDTH=$w -pvalue+parity_gen_check.PC_IMPL=$impl \
            -o /tmp/pg_g3_${impl}_${w} > "$EV/tmp.log" 2>&1 ) || {
            echo "FAIL impl=$impl W=$w" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
        echo "PASS impl=$impl W=$w" | tee -a "$EV/param_matrix.txt"
    done
done

# ---- 负向参数：PC-001（DATA_WIDTH 越界）elaboration $error 拦截（REQ-004）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+parity_gen_check.DATA_WIDTH=3 \
    -o /tmp/pg_neg_w > "$EV/negative_w3.txt" 2>&1 ) && {
    echo "negative DATA_WIDTH=3 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-001" "$EV/negative_w3.txt" || { echo "missing PC-001 id in log"; exit 1; }

# ---- 负向参数：PC_IMPL 越界（g_param_impl $error 拦截；数值参数 -pvalue 可靠）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+parity_gen_check.DATA_WIDTH=16 -pvalue+parity_gen_check.PC_IMPL=3 \
    -o /tmp/pg_neg_i > "$EV/negative_impl.txt" 2>&1 ) && {
    echo "negative PC_IMPL=3 unexpectedly PASSED"; exit 1; } || true
grep -q "PC_IMPL" "$EV/negative_impl.txt" || { echo "missing PC_IMPL guard in log"; exit 1; }

rm -f "$EV/tmp.log"
echo "[G3] static baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
