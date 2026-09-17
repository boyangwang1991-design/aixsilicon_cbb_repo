#!/usr/bin/env bash
# G4 异步模式（ASYNC_MODE=1）双时钟功能回归 — parallel_data_fetch
#
# 激励矩阵与判据见 docs/design.md §8（异步模式验证方案）。
#   tc_async_modes        A 快 B 慢 / A 慢 B 快 / 临界(FIFO==BEAT_COUNT) / 同频异相(相位 0/3/7)
#   tc_async_reset_order  事务中 B 复位 → 错误结束；link 重建后可完成新事务
#
# 纪律：
#   * 原生仿真器直接调用（VCS），产物落 build/eda/；断言/自检失败须使仿真非零退出；
#   * 证据摘要落 build/eda/evidence/g4_functional/（build/ 不入库）；
#   * 时钟周期用半周期参数表达：#A_PERIOD 翻转 → 周期 = 2*A_PERIOD，两时钟互质/非整数比。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBB_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RTL_REQ="${CBB_DIR}/rtl/parallel_data_fetch_requester.sv"
RTL_PRV="${CBB_DIR}/rtl/parallel_data_fetch_provider.sv"
RTL_TOP="${CBB_DIR}/rtl/parallel_data_fetch.sv"
TB="${CBB_DIR}/verification/simulation/parallel_data_fetch_async_tb.sv"
WORK="${CBB_DIR}/build/eda"
EVID="${WORK}/evidence/g4_functional"
TOP="parallel_data_fetch_async_tb"

mkdir -p "${WORK}" "${EVID}"
cd "${WORK}" || exit 40

if ! command -v vcs >/dev/null 2>&1; then
  echo "OPTIONAL_UNAVAILABLE: vcs not found on PATH" | tee "${EVID}/async_summary.txt"
  exit 20
fi

PASS=0; FAIL=0
DETAIL="${EVID}/async_functional.txt"
: > "${DETAIL}"
echo "== parallel_data_fetch G4 async (dual-clock) regression ==" | tee -a "${DETAIL}"
echo "vcs: $(vcs -ID 2>/dev/null | head -1 || echo unknown)" | tee -a "${DETAIL}"
echo | tee -a "${DETAIL}"

# 编译一次（参数在仿真时用 -pvalue 覆盖，避免多次编译）
if ! vcs -full64 -sverilog -timescale=1ns/1ps -nc -assert svaext \
      "${RTL_REQ}" "${RTL_PRV}" "${RTL_TOP}" "${TB}" -top "${TOP}" \
      -o simv_g4_async > g4_async_compile.log 2>&1; then
  echo "FAIL  async compile failed (see g4_async_compile.log)" | tee -a "${DETAIL}"
  echo "async: 0 pass / 1 fail" > "${EVID}/async_summary.txt"
  exit 10
fi
echo "compile: OK" | tee -a "${DETAIL}"

# run_case <label> <desc> [<param=value> ...]
run_case() {
  local label="$1"; local desc="$2"; shift 2
  local args=()
  for kv in "$@"; do args+=("-pvalue+${TOP}.${kv}"); done

  ./simv_g4_async "${args[@]}" -l "g4_async_${label}.log" > "g4_async_${label}.txt" 2>&1
  local rc=$?

  if [ "${rc}" -eq 0 ] && grep -q "RESULT: PASS" "g4_async_${label}.txt"; then
    local line
    line="$(grep -E 'transactions=' "g4_async_${label}.txt" | head -1)"
    echo "PASS  ${label} (${desc}) | ${line}" | tee -a "${DETAIL}"
    PASS=$((PASS+1))
  else
    echo "FAIL  ${label} (${desc}) rc=${rc} (see g4_async_${label}.txt)" | tee -a "${DETAIL}"
    grep -E "^\[FAIL\]|RESULT:" "g4_async_${label}.txt" | head -6 | tee -a "${DETAIL}"
    FAIL=$((FAIL+1))
  fi
}

# 基准：DW=64 LW=16 → BEAT_COUNT=4
BEATS=4

# ---- tc_async_modes：四种时钟比例（互质/非整数比，避免锁相假象）----
run_case a_fast_b_slow   "A快B慢 4x  (周期 10:40)"   A_PERIOD=5  B_PERIOD=20 RSP_FIFO_DEPTH=16
run_case a_slow_b_fast   "A慢B快 1/4 (周期 40:10)"   A_PERIOD=20 B_PERIOD=5  RSP_FIFO_DEPTH=16
run_case a_slow_b_fast_crit "临界 FIFO==BEAT_COUNT"  A_PERIOD=11 B_PERIOD=20 RSP_FIFO_DEPTH=${BEATS}
run_case same_rate_ph0   "同频异相 相位0"            A_PERIOD=10 B_PERIOD=10 PHASE_SHIFT=0  RSP_FIFO_DEPTH=16
run_case same_rate_ph3   "同频异相 相位3"            A_PERIOD=10 B_PERIOD=10 PHASE_SHIFT=3  RSP_FIFO_DEPTH=16
run_case same_rate_ph7   "同频异相 相位7"            A_PERIOD=10 B_PERIOD=10 PHASE_SHIFT=7  RSP_FIFO_DEPTH=16

# ---- 异构周期（非整数比）补充：验证不同相位/比例下的稳健性 ----
run_case coprime_7_17    "互质周期 7:17"             A_PERIOD=7  B_PERIOD=17 RSP_FIFO_DEPTH=16
run_case fifo_deep       "深 FIFO（非临界）"         A_PERIOD=13 B_PERIOD=19 RSP_FIFO_DEPTH=64

# 说明：REQ_SYNC_STAGES=3/4 需要在 TB 中作为参数透传 DUT（本轮 TB 固定 2，见
# qualification-report 剩余风险）；异步下的级数逐点回归属后续细化工作，不在此夸大覆盖。

echo | tee -a "${DETAIL}"
SUMMARY="async: ${PASS} pass / ${FAIL} fail"
echo "${SUMMARY}" | tee -a "${DETAIL}"
echo "${SUMMARY}" > "${EVID}/async_summary.txt"
[ "${FAIL}" -eq 0 ] || exit 10
exit 0