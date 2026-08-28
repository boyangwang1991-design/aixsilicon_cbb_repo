#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_static_checks.sh   （从 CBB 根目录执行）
# 产出: evidence/g3_static/{param_matrix.txt, negative_w3.txt, negative_cw9.txt}
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV=evidence/g3_static
mkdir -p "$EV"

# ---- 工具探测（先探测再判定，aix tool 未注册 ≠ EDA 不可用）----
command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/popcount.sv $P/rtl/popcount_compressed.sv"

# ---- 正向编译矩阵：三实现 × {4,8,33,64,127,256}（含非 2 幂）----
: > "$EV/param_matrix.txt"
for impl in 0 1 2; do
    for w in 4 8 33 64 127 256; do
        vcs -full64 -timescale=1ns/1ps -sverilog $RTL \
            -pvalue+popcount.INPUT_WIDTH=$w -pvalue+popcount.PC_IMPL=$impl \
            -o /tmp/pc_g3_${impl}_${w} > "$EV/tmp.log" 2>&1 || {
            echo "FAIL impl=$impl W=$w" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1; }
        echo "PASS impl=$impl W=$w" | tee -a "$EV/param_matrix.txt"
    done
done

# ---- 负向参数：PC-001 / PC-002 elaboration $error 拦截（REQ-004）----
vcs -full64 -timescale=1ns/1ps -sverilog $RTL -pvalue+popcount.INPUT_WIDTH=3 \
    -o /tmp/pc_neg_w > "$EV/negative_w3.txt" 2>&1 && {
    echo "negative INPUT_WIDTH=3 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-001" "$EV/negative_w3.txt" || { echo "missing PC-001 id in log"; exit 1; }

vcs -full64 -timescale=1ns/1ps -sverilog $RTL -pvalue+popcount.INPUT_WIDTH=16 \
    -pvalue+popcount.CHUNK_W=9 -pvalue+popcount.PC_IMPL=2 \
    -o /tmp/pc_neg_c > "$EV/negative_cw9.txt" 2>&1 && {
    echo "negative CHUNK_W=9 unexpectedly PASSED"; exit 1; } || true
grep -q "PC-002" "$EV/negative_cw9.txt" || { echo "missing PC-002 id in log"; exit 1; }

rm -f "$EV/tmp.log"
echo "[G3] static baseline OK — evidence in $EV/"
