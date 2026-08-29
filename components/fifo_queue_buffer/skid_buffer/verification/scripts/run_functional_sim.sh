#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/{functional_sim.txt}
# 固定 seed: TB 内 SEED=32'hCBB_2026_0828（可重放）
# 覆盖配置（多实现 profile）：
#   full32   : DATA_W=32, IMPL=1, BYPASS=0（full 满吞吐，默认）
#   fwd32    : DATA_W=32, IMPL=0, BYPASS=0（forward 简单打拍）
#   bwd32    : DATA_W=32, IMPL=2, BYPASS=0（backward ready 寄存/透传）
#   bypass32 : DATA_W=32, IMPL=1, BYPASS=1（组合直通）
#   full1    : DATA_W=1,  IMPL=1, BYPASS=0（边界位宽）
# 场景：tc_random(+fwd)/tc_backpressure(+fwd)/tc_edge/tc_bypass 参考模型队列整体比对
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

RTL="$P/rtl/skid_buffer.sv $P/rtl/impl/forward/skid_buffer.sv $P/rtl/impl/full/skid_buffer.sv $P/rtl/impl/backward/skid_buffer.sv"
TB="$P/verification/simulation/skid_buffer_tb.sv"
: > "$EV/functional_sim.txt"

run_cfg() {
    local tag=$1 w=$2 impl=$3 byp=$4
    echo "===== $tag (DATA_W=$w IMPL=$impl BYPASS=$byp) =====" | tee -a "$EV/functional_sim.txt"
    ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL $TB \
        -pvalue+skid_buffer_tb.DATA_W=$w -pvalue+skid_buffer_tb.IMPL=$impl -pvalue+skid_buffer_tb.BYPASS=$byp \
        -o /tmp/skid_g4_${tag} > "$EV/tmp_compile_${tag}.log" 2>&1 ) || {
        echo "compile $tag FAILED"; cat "$EV/tmp_compile_${tag}.log"; exit 1; }
    /tmp/skid_g4_${tag} >> "$EV/functional_sim.txt" 2>&1
    rm -f "$EV/tmp_compile_${tag}.log"
}

run_cfg full32   32 1 0
run_cfg fwd32    32 0 0
run_cfg bwd32    32 2 0
run_cfg bypass32 32 1 1
run_cfg full1     1 1 0

grep -q "SKID_BUFFER_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
echo "[sim] SKID_BUFFER_TB PASS × 5 配置（full32/fwd32/bwd32/bypass32/full1）"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
