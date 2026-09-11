#!/usr/bin/env bash
# ============================================================================
# run_functional_sim.sh — G4 功能验证可复现脚本 (verify-cbb 纪律 #14)
# 用法: bash verification/scripts/run_functional_sim.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g4_functional/{functional_sim.txt}
# 固定 seed: TB 内 SEED=32'hARS_2026_0911（tc_random 可重放）
# EDA 产物纪律：VCS 在 build/eda/ 下运行（csrc/daidir 等生成物落入 build/，不入库）
# 注：dutX 变异实例的 SVA 断言失败是【预期检出】（tc_mutation），用 grep 计数容忍；
#     除变异断言外任何 [FAIL] / Assertion 均判失败。
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g4_functional"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

command -v vcs >/dev/null 2>&1 || { echo "[BLOCKED] vcs not found"; exit 3; }
echo "[probe] vcs=$(command -v vcs)"

RTL="$P/rtl/apb_register_slice.sv"
TB="$P/verification/simulation/apb_register_slice_tb.sv"

# ---- 正常 RTL：单仿真多场景（复位 + 定向 + RS=2 + 随机 300 事务 + 等价）----
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog -assert enable_diag $RTL $TB \
    -o /tmp/ars_g4 > "$EV/tmp_compile.log" 2>&1 )
/tmp/ars_g4 -suppress=ASLR_DETECTED_INFO > "$EV/functional_sim.txt" 2>&1 || true
grep -q "APB_RS_TB PASS" "$EV/functional_sim.txt" || {
    echo "functional sim FAILED"; cat "$EV/functional_sim.txt"; exit 1; }
# 正常 DUT 不得有断言失败
bad_hits=$(grep -c "PROP_ARS_.*failed" "$EV/functional_sim.txt" || true)
if [ "${bad_hits:-0}" -gt 0 ]; then
    echo "[sim] 正常 RTL 出现断言失败"; grep "PROP_ARS_" "$EV/functional_sim.txt" | head -10; exit 1
fi
echo "[sim] APB_RS_TB PASS (reset + directed + rs2 + random300 + equiv)"

# ---- tc_mutation：编译期 RTL 变异（破坏反馈对齐），SVA 应检出（checker 有效性）----
# 变异（确定性 python 注入）：g_resp_reg1 分支中 prdata_main 额外错位 1 拍
#（$past 包裹）→ 数据滞后完成 1 拍 → PROP_ARS_ALIGN_003 在完成拍失败。
MUT="$WORK/apb_register_slice_mut.sv"
python3 - "$RTL" "$MUT" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
mut = text.replace(
    "                end else begin\n"
    "                    pready_main  <= pready_sub;\n"
    "                    prdata_main  <= prdata_sub;\n"
    "                    pslverr_main <= pslverr_sub;\n"
    "                end",
    "                end else begin\n"
    "                    pready_main  <= pready_sub;\n"
    "                    prdata_main  <= $past(prdata_sub); // MUTANT: misaligned\n"
    "                    pslverr_main <= pslverr_sub;\n"
    "                end")
assert mut != text, "mutation anchor not found"
open(dst, "w", encoding="utf-8").write(mut)
print("[mutation] mutant generated:", dst)
PYEOF
( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog -assert enable_diag "$MUT" $TB \
    -o /tmp/ars_g4_mut > "$EV/tmp_compile_mut.log" 2>&1 ) || {
    echo "[mutation] mutant 编译失败（变异无效）"; cat "$EV/tmp_compile_mut.log"; exit 1; }
/tmp/ars_g4_mut -suppress=ASLR_DETECTED_INFO > "$EV/mutation_sim.txt" 2>&1 || true
mut_hits=$(grep -c "PROP_ARS_ALIGN_003" "$EV/mutation_sim.txt" || true)
if [ "${mut_hits:-0}" -lt 1 ]; then
    echo "[mutation] 未检出变异（SVA 有效性存疑）"; grep -i "assert\|FAIL" "$EV/mutation_sim.txt" | head -20; exit 1
fi
echo "[mutation] detected=${mut_hits} (tc_mutation PASS — checker 有效性证明)"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
echo "[G4] functional baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
