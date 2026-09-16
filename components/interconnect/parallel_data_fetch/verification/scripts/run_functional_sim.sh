#!/usr/bin/env bash
# G4 功能仿真 — parallel_data_fetch（同步模式：定向 + 约束随机 + 错误注入 + 参数化矩阵）
#
# 纪律：
#   * 原生仿真器直接调用（VCS），产物落 build/eda/；断言故障必须使仿真非零退出；
#   * 证据摘要落 build/eda/evidence/g4_functional/（build/ 不入库）。
#
# 覆盖矩阵（与本工程 verification/plan.yaml 的 testcase 对应）：
#   sync_basic / provider_latency / backpressure / snapshot_hold / random / reset / error_inject
#   beat1（BEAT_COUNT=1）、pipe1/pipe8（长线 pipeline）、slice0/1/2（切片等价）、
#   msb_first、odd_parity、no_parity
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBB_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RTL_REQ="${CBB_DIR}/rtl/parallel_data_fetch_requester.sv"
RTL_PRV="${CBB_DIR}/rtl/parallel_data_fetch_provider.sv"
RTL_TOP="${CBB_DIR}/rtl/parallel_data_fetch.sv"
TB="${CBB_DIR}/verification/simulation/parallel_data_fetch_tb.sv"
WORK="${CBB_DIR}/build/eda"
EVID="${WORK}/evidence/g4_functional"
TOP="parallel_data_fetch_tb"

mkdir -p "${WORK}" "${EVID}"
cd "${WORK}" || exit 40

if ! command -v vcs >/dev/null 2>&1; then
  echo "OPTIONAL_UNAVAILABLE: vcs not found on PATH" | tee "${EVID}/summary.txt"
  exit 20
fi

PASS=0; FAIL=0
DETAIL="${EVID}/functional.txt"
: > "${DETAIL}"
echo "== parallel_data_fetch G4 functional baseline ==" | tee -a "${DETAIL}"
echo "vcs: $(vcs -ID 2>/dev/null | head -1 || echo unknown)" | tee -a "${DETAIL}"
echo | tee -a "${DETAIL}"

run_case() {
  local label="$1"; shift
  local args=()
  for kv in "$@"; do args+=("-pvalue+${TOP}.${kv}"); done

  if ! vcs -full64 -sverilog -timescale=1ns/1ps -nc -assert svaext \
        "${args[@]}" "${RTL_REQ}" "${RTL_PRV}" "${RTL_TOP}" "${TB}" -top "${TOP}" \
        -o "simv_g4_${label}" > "g4_compile_${label}.log" 2>&1; then
    echo "FAIL  ${label} (compile failed, see g4_compile_${label}.log)" | tee -a "${DETAIL}"
    FAIL=$((FAIL+1))
    return
  fi

  ./"simv_g4_${label}" -l "g4_run_${label}.log" > "g4_run_${label}.txt" 2>&1
  local rc=$?

  if [ "${rc}" -eq 0 ] && grep -q "RESULT: PASS" "g4_run_${label}.txt"; then
    local line
    line="$(grep -E 'transactions=' "g4_run_${label}.txt" | head -1)"
    echo "PASS  ${label} | ${line}" | tee -a "${DETAIL}"
    PASS=$((PASS+1))
  else
    echo "FAIL  ${label} rc=${rc} (see g4_run_${label}.txt)" | tee -a "${DETAIL}"
    grep -E "^\[FAIL\]|Error|RESULT:" "g4_run_${label}.txt" | head -8 | tee -a "${DETAIL}"
    FAIL=$((FAIL+1))
  fi
}

# 参数化覆盖矩阵：默认 DW=64 LW=16（BEAT_COUNT=4）
run_case sync_default
run_case beat1            DW=8  LW=8          # BEAT_COUNT=1 退化
run_case beats9           DW=144 LW=16        # 非 2 次幂 BEAT_COUNT=9
run_case pipe1            PIPE=1
run_case pipe8            PIPE=8
run_case slice_shift      SLICE_IMPL=0
run_case slice_indexed    SLICE_IMPL=1
run_case slice_banked     SLICE_IMPL=2
run_case msb_first        LSB_FIRST=0
run_case odd_parity       ODD_PARITY=1
run_case no_parity        PARITY_EN=0
run_case wide_link        DW=64 LW=64        # BEAT_COUNT=1 且宽链路

echo | tee -a "${DETAIL}"
SUMMARY="functional: ${PASS} pass / ${FAIL} fail"
echo "${SUMMARY}" | tee -a "${DETAIL}"
echo "${SUMMARY}" > "${EVID}/summary.txt"
[ "${FAIL}" -eq 0 ] || exit 10
exit 0
