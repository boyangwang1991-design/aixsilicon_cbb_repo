#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线可复现脚本 (implement-cbb-rtl 纪律 #14)
# 用法: bash verification/scripts/run_static_checks.sh   （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/{param_matrix.txt, negative_*.txt}
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# 负向参数：generate 块内 $error 在 elaboration 期拦截（PC-001..006，REQ-008）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/sync_fifo.sv"

# ---- 正向编译矩阵：IMPL×OUTPUT_REG × DATA_W/DEPTH 代表点 ----
: > "$EV/param_matrix.txt"
# 四模式（IMPL × OUTPUT_REG）默认参数点
for impl in 0 1; do
    for outreg in 0 1; do
        ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
            -pvalue+sync_fifo.DATA_W=32 -pvalue+sync_fifo.DEPTH=16 \
            -pvalue+sync_fifo.OUTPUT_REG=$outreg -pvalue+sync_fifo.IMPL=$impl \
            -o /tmp/sf_g3_m${impl}r${outreg} > "$EV/tmp.log" 2>&1 ) || {
            echo "FAIL IMPL=$impl OUTPUT_REG=$outreg" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
        echo "PASS IMPL=$impl OUTPUT_REG=$outreg" | tee -a "$EV/param_matrix.txt"
    done
done
# DATA_W 边界（register comb）
for w in 1 64 128 1024; do
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+sync_fifo.DATA_W=$w -pvalue+sync_fifo.DEPTH=16 \
        -pvalue+sync_fifo.OUTPUT_REG=0 -pvalue+sync_fifo.IMPL=0 \
        -o /tmp/sf_g3_w${w} > "$EV/tmp.log" 2>&1 ) || {
        echo "FAIL DATA_W=$w" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
    echo "PASS DATA_W=$w" | tee -a "$EV/param_matrix.txt"
done
# DEPTH 边界（非 2 幂 129/3 与最大 256，register comb）
for d in 3 32 129 256; do
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+sync_fifo.DATA_W=32 -pvalue+sync_fifo.DEPTH=$d \
        -pvalue+sync_fifo.OUTPUT_REG=0 -pvalue+sync_fifo.IMPL=0 \
        -o /tmp/sf_g3_d${d} > "$EV/tmp.log" 2>&1 ) || {
        echo "FAIL DEPTH=$d" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
    echo "PASS DEPTH=$d" | tee -a "$EV/param_matrix.txt"
done
# DEPTH 边界 shift comb（移位链参数化展开）
for d in 3 32; do
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+sync_fifo.DATA_W=32 -pvalue+sync_fifo.DEPTH=$d \
        -pvalue+sync_fifo.OUTPUT_REG=0 -pvalue+sync_fifo.IMPL=1 \
        -o /tmp/sf_g3_sd${d} > "$EV/tmp.log" 2>&1 ) || {
        echo "FAIL shift DEPTH=$d" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
    echo "PASS shift DEPTH=$d" | tee -a "$EV/param_matrix.txt"
done

# ---- 负向：DATA_W=0 / 1025（PC-001/002）----
for n in "0 PC-001" "1025 PC-002"; do
    set -- $n
    w=$1; tag=$2
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+sync_fifo.DATA_W=$w -pvalue+sync_fifo.DEPTH=16 \
        -pvalue+sync_fifo.OUTPUT_REG=0 -pvalue+sync_fifo.IMPL=0 \
        -o /tmp/sf_neg_w${w} > "$EV/negative_w${w}.txt" 2>&1 ) && {
        echo "negative DATA_W=$w unexpectedly PASSED"; exit 1; } || true
    grep -q "$tag" "$EV/negative_w${w}.txt" || { echo "missing $tag in negative_w${w} log"; exit 1; }
done

# ---- 负向：DEPTH=1 / 257（PC-003/004）----
for n in "1 PC-003" "257 PC-004"; do
    set -- $n
    d=$1; tag=$2
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+sync_fifo.DATA_W=32 -pvalue+sync_fifo.DEPTH=$d \
        -pvalue+sync_fifo.OUTPUT_REG=0 -pvalue+sync_fifo.IMPL=0 \
        -o /tmp/sf_neg_d${d} > "$EV/negative_d${d}.txt" 2>&1 ) && {
        echo "negative DEPTH=$d unexpectedly PASSED"; exit 1; } || true
    grep -q "$tag" "$EV/negative_d${d}.txt" || { echo "missing $tag in negative_d${d} log"; exit 1; }
done

# ---- 负向：OUTPUT_REG=2（PC-005）、IMPL=2（PC-006）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+sync_fifo.DATA_W=32 -pvalue+sync_fifo.DEPTH=16 \
    -pvalue+sync_fifo.OUTPUT_REG=2 -pvalue+sync_fifo.IMPL=0 \
    -o /tmp/sf_neg_or > "$EV/negative_outreg.txt" 2>&1 ) && {
    echo "negative OUTPUT_REG=2 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-005" "$EV/negative_outreg.txt" || { echo "missing PC-005 in negative_outreg log"; exit 1; }
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+sync_fifo.DATA_W=32 -pvalue+sync_fifo.DEPTH=16 \
    -pvalue+sync_fifo.OUTPUT_REG=0 -pvalue+sync_fifo.IMPL=2 \
    -o /tmp/sf_neg_im > "$EV/negative_impl.txt" 2>&1 ) && {
    echo "negative IMPL=2 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-006" "$EV/negative_impl.txt" || { echo "missing PC-006 in negative_impl log"; exit 1; }

rm -f "$EV/tmp.log"
echo "[G3] static baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
