#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/{functional_sim.txt}
# 固定 seed: TB 内 SEED=32'hCBB_2026_0903（可重放）
# 覆盖配置（IMPL×OUTPUT_REG×DEPTH 代表点，含边界）：
#   reg_comb16  : DATA_W=32, DEPTH=16,  IMPL=0, OUTPUT_REG=0（register × comb，默认）
#   reg_reg16   : DATA_W=32, DEPTH=16,  IMPL=0, OUTPUT_REG=1（register × reg 输出级）
#   sh_comb16   : DATA_W=32, DEPTH=16,  IMPL=1, OUTPUT_REG=0（shift × comb）
#   sh_reg16    : DATA_W=32, DEPTH=16,  IMPL=1, OUTPUT_REG=1（shift × reg 输出级）
#   reg_comb2   : DATA_W=32, DEPTH=2,   IMPL=0, OUTPUT_REG=0（最小深度边界）
#   reg_comb129 : DATA_W=32, DEPTH=129, IMPL=0, OUTPUT_REG=0（非 2 幂大深度）
#   reg_reg3    : DATA_W=8,  DEPTH=3,   IMPL=0, OUTPUT_REG=1（reg 边界）
#   sh_comb2    : DATA_W=32, DEPTH=2,   IMPL=1, OUTPUT_REG=0（shift 最小深度）
#   w1_comb     : DATA_W=1,  DEPTH=16,  IMPL=0, OUTPUT_REG=0（边界位宽）
# 场景：tc_reset/tc_random/tc_backpressure/tc_edge/tc_out_comb/tc_outreg
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."           # CBB 工程包根目录
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/sync_fifo.sv"
TB="$P/verification/simulation/sync_fifo_tb.sv"
: > "$EV/functional_sim.txt"

run_cfg() {
    local tag=$1 w=$2 d=$3 impl=$4 outreg=$5
    echo "===== $tag (DATA_W=$w DEPTH=$d IMPL=$impl OUTPUT_REG=$outreg) =====" | tee -a "$EV/functional_sim.txt"
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL $TB \
        -pvalue+sync_fifo_tb.DATA_W=$w -pvalue+sync_fifo_tb.DEPTH=$d \
        -pvalue+sync_fifo_tb.IMPL=$impl -pvalue+sync_fifo_tb.OUTPUT_REG=$outreg \
        -o /tmp/sf_g4_${tag} > "$EV/tmp_compile_${tag}.log" 2>&1 ) || {
        echo "compile $tag FAILED"; cat "$EV/tmp_compile_${tag}.log"; exit 1; }
    /tmp/sf_g4_${tag} >> "$EV/functional_sim.txt" 2>&1 || {
        echo "sim $tag FAILED (非零退出)"; exit 1; }
    rm -f "$EV/tmp_compile_${tag}.log"
}

run_cfg reg_comb16   32 16   0 0
run_cfg reg_reg16    32 16   0 1
run_cfg sh_comb16    32 16   1 0
run_cfg sh_reg16     32 16   1 1
run_cfg reg_comb2    32 2    0 0
run_cfg reg_comb129  32 129  0 0
run_cfg reg_reg3      8 3    0 1
run_cfg sh_comb2     32 2    1 0
run_cfg w1_comb       1 16   0 0

grep -q "SYNC_FIFO_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
echo "[sim] SYNC_FIFO_TB PASS × $(grep -c 'SYNC_FIFO_TB PASS' "$EV/functional_sim.txt")/9 配置"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
