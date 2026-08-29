#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/functional_sim.txt
# 固定 seed: TB 内 SEED=32'hA1B2_0828（tc_random/equiv 可重放）
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/weighted_rr_arbiter.sv"
TB="$P/verification/simulation/wrra_tb.sv"

# ---- 单仿真多场景（配额窗口 + 边界 + 随机互斥 + smooth + 等价 + 寄存 + ack 锁定）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog -assert enable_diag $RTL $TB \
    -o /tmp/wrra_g4 > "$EV/tmp_compile.log" 2>&1 )
# -assert disable_cover 关闭覆盖 info；-suppress 抑制 VCS 提示类信息，保持证据干净
/tmp/wrra_g4 -assert disable_cover -suppress=all > "$EV/functional_sim.txt" 2>&1
grep -q "WRRA_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
echo "[sim] WRRA_TB PASS (quota_window + edge + random2000×N64 + smooth + equiv + registered + ack_lock)"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
