#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线可复现脚本 (implement-cbb-rtl 纪律 #14)
# 用法: bash verification/scripts/run_static_checks.sh   （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/{param_matrix.txt, negative_*.txt}
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# 负向参数：generate 块内 $error 在 elaboration 期拦截（PC-001..004，REQ-004）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/skid_buffer.sv $P/rtl/impl/forward/skid_buffer.sv $P/rtl/impl/full/skid_buffer.sv $P/rtl/impl/backward/skid_buffer.sv"

# ---- 正向编译矩阵：DATA_W ∈ {1,8,32,64,128} × IMPL ∈ {0,1,2} + BYPASS=1 ----
: > "$EV/param_matrix.txt"
for w in 1 8 32 64 128; do
    for impl in 0 1 2; do
        ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
            -pvalue+skid_buffer.DATA_W=$w -pvalue+skid_buffer.IMPL=$impl \
            -o /tmp/skid_g3_${w}_i${impl} > "$EV/tmp.log" 2>&1 ) || {
            echo "FAIL DATA_W=$w IMPL=$impl" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
        echo "PASS DATA_W=$w IMPL=$impl" | tee -a "$EV/param_matrix.txt"
    done
done
# BYPASS=1（直通，忽略 IMPL）
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+skid_buffer.DATA_W=32 -pvalue+skid_buffer.BYPASS=1 \
    -o /tmp/skid_g3_bp > "$EV/tmp.log" 2>&1 ) || {
    echo "FAIL BYPASS=1" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
echo "PASS BYPASS=1" | tee -a "$EV/param_matrix.txt"

# ---- 负向：DATA_W=0 / 1025（PC-001/002）----
for n in "0 PC-001" "1025 PC-002"; do
    set -- $n
    w=$1; tag=$2
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
        -pvalue+skid_buffer.DATA_W=$w \
        -o /tmp/skid_neg_w${w} > "$EV/negative_w${w}.txt" 2>&1 ) && {
        echo "negative DATA_W=$w unexpectedly PASSED"; exit 1; } || true
    grep -q "$tag" "$EV/negative_w${w}.txt" || { echo "missing $tag in negative_w${w} log"; exit 1; }
done

# ---- 负向：IMPL=3（PC-003）、BYPASS=2（PC-004）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+skid_buffer.IMPL=3 \
    -o /tmp/skid_neg_impl > "$EV/negative_impl.txt" 2>&1 ) && {
    echo "negative IMPL=3 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-003" "$EV/negative_impl.txt" || { echo "missing PC-003 in negative_impl log"; exit 1; }
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
    -pvalue+skid_buffer.BYPASS=2 \
    -o /tmp/skid_neg_byp > "$EV/negative_byp.txt" 2>&1 ) && {
    echo "negative BYPASS=2 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-004" "$EV/negative_byp.txt" || { echo "missing PC-004 in negative_byp log"; exit 1; }

rm -f "$EV/tmp.log"
echo "[G3] static baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
