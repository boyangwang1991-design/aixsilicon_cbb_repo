#!/usr/bin/env bash
# G3 静态基线 — parallel_data_fetch（Compile / Elaboration / 负向参数拦截）
#
# 纪律：
#   * 先探测原生工具（command -v vcs），未注册 aix action 不等于 EDA 不可用；
#   * 所有 EDA 产物（csrc/、simv*、*.daidir）落 build/eda/，禁止散落 CBB 根；
#   * 证据摘要以 *.txt 落 build/eda/evidence/g3_static/（build/ 不入库）。
#
# 结构：三个独立模块都做 elaboration（端点可单独集成，必须各自可编译）：
#   parallel_data_fetch_requester / parallel_data_fetch_provider / parallel_data_fetch(wrapper)
# 正向：多组参数化 elaborate 必须成功（sync/async、pipeline、切片三实现、边界）
# 负向：非法参数组必须由 generate 内 $error 在 elaboration 期拒绝（工具非零退出）
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBB_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RTL_DIR="${CBB_DIR}/rtl"
RTL_REQ="${RTL_DIR}/parallel_data_fetch_requester.sv"
RTL_PRV="${RTL_DIR}/parallel_data_fetch_provider.sv"
RTL_TOP="${RTL_DIR}/parallel_data_fetch.sv"
WORK="${CBB_DIR}/build/eda"
EVID="${WORK}/evidence/g3_static"

mkdir -p "${WORK}" "${EVID}"
cd "${WORK}" || exit 40

if ! command -v vcs >/dev/null 2>&1; then
  echo "OPTIONAL_UNAVAILABLE: vcs not found on PATH" | tee "${EVID}/summary.txt"
  exit 20
fi

VCS_VER="$(vcs -ID 2>/dev/null | head -1 || echo unknown)"
PASS=0; FAIL=0; NEG_PASS=0; NEG_FAIL=0
DETAIL="${EVID}/static_baseline.txt"
: > "${DETAIL}"

# $1=label $2=top $3..=参数覆盖
elab_positive() {
  local label="$1"; local top="$2"; shift 2
  local args=()
  for kv in "$@"; do args+=("-pvalue+${top}.${kv}"); done
  if vcs -full64 -sverilog -timescale=1ns/1ps -nc \
        "${args[@]}" "${RTL_REQ}" "${RTL_PRV}" "${RTL_TOP}" -top "${top}" -o "simv_${label}" \
        > "elab_${label}.log" 2>&1; then
    echo "PASS  positive ${label} (top=${top})" | tee -a "${DETAIL}"
    PASS=$((PASS+1))
  else
    echo "FAIL  positive ${label} (top=${top}) see elab_${label}.log" | tee -a "${DETAIL}"
    FAIL=$((FAIL+1))
  fi
}

# 负向：期望 elaboration 失败且报错含 parallel_data_fetch 参数诊断
elab_negative() {
  local label="$1"; local top="$2"; shift 2
  local args=()
  for kv in "$@"; do args+=("-pvalue+${top}.${kv}"); done
  if vcs -full64 -sverilog -timescale=1ns/1ps -nc \
        "${args[@]}" "${RTL_REQ}" "${RTL_PRV}" "${RTL_TOP}" -top "${top}" -o "simv_neg_${label}" \
        > "elab_neg_${label}.log" 2>&1; then
    echo "FAIL  negative ${label} elaborated but must be rejected" | tee -a "${DETAIL}"
    NEG_FAIL=$((NEG_FAIL+1))
  elif grep -q "parallel_data_fetch" "elab_neg_${label}.log"; then
    echo "PASS  negative ${label} rejected by \$error" | tee -a "${DETAIL}"
    NEG_PASS=$((NEG_PASS+1))
  else
    echo "FAIL  negative ${label} failed without parameter diagnostic" | tee -a "${DETAIL}"
    NEG_FAIL=$((NEG_FAIL+1))
  fi
}

echo "== parallel_data_fetch G3 static baseline ==" | tee -a "${DETAIL}"
echo "vcs: ${VCS_VER}" | tee -a "${DETAIL}"
echo "modules: parallel_data_fetch_requester | parallel_data_fetch_provider | parallel_data_fetch(wrapper)" | tee -a "${DETAIL}"
for f in "${RTL_REQ}" "${RTL_PRV}" "${RTL_TOP}"; do
  echo "sha256 $(basename "${f}"): $(sha256sum "${f}" | awk '{print $1}')" | tee -a "${DETAIL}"
done
echo | tee -a "${DETAIL}"

echo "---- positive elaboration (wrapper) ----" | tee -a "${DETAIL}"
elab_positive default        parallel_data_fetch
elab_positive sync_pipe1     parallel_data_fetch LINK_PIPE_STAGES=1
elab_positive sync_pipe8     parallel_data_fetch LINK_PIPE_STAGES=8
elab_positive beat1          parallel_data_fetch DATA_WIDTH=8 LINK_WIDTH=8
elab_positive nonpow2_beats  parallel_data_fetch DATA_WIDTH=144 LINK_WIDTH=16
elab_positive slice_shift    parallel_data_fetch SLICE_IMPL=0
elab_positive slice_indexed  parallel_data_fetch SLICE_IMPL=1
elab_positive slice_banked   parallel_data_fetch SLICE_IMPL=2
elab_positive msb_first      parallel_data_fetch LSB_FIRST=0
elab_positive odd_parity     parallel_data_fetch ODD_PARITY=1
elab_positive no_parity      parallel_data_fetch PARITY_EN=0
elab_positive no_timeout     parallel_data_fetch TIMEOUT_EN=0
elab_positive wide_4096      parallel_data_fetch DATA_WIDTH=4096 LINK_WIDTH=1 TIMEOUT_CYCLES=65536
elab_positive wide_narrow    parallel_data_fetch DATA_WIDTH=4096 LINK_WIDTH=8 RSP_FIFO_DEPTH=512
elab_positive async_typical  parallel_data_fetch ASYNC_MODE=1 RSP_FIFO_DEPTH=16
elab_positive async_max      parallel_data_fetch ASYNC_MODE=1 DATA_WIDTH=4096 LINK_WIDTH=8 RSP_FIFO_DEPTH=512
elab_positive async_stages4  parallel_data_fetch ASYNC_MODE=1 REQ_SYNC_STAGES=4

echo "---- positive elaboration (端点可独立集成) ----" | tee -a "${DETAIL}"
elab_positive req_standalone parallel_data_fetch_requester
elab_positive req_sync_pipe  parallel_data_fetch_requester LINK_PIPE_STAGES=4
elab_positive prv_standalone parallel_data_fetch_provider
elab_positive prv_banked     parallel_data_fetch_provider SLICE_IMPL=2

echo | tee -a "${DETAIL}"
echo "---- negative elaboration (expect generate \$error) ----" | tee -a "${DETAIL}"
elab_negative dw_lt_lw           parallel_data_fetch DATA_WIDTH=8 LINK_WIDTH=32
elab_negative dw_not_divisible   parallel_data_fetch DATA_WIDTH=10 LINK_WIDTH=4
elab_negative dw_over_max        parallel_data_fetch DATA_WIDTH=8192 LINK_WIDTH=32
elab_negative lw_zero            parallel_data_fetch DATA_WIDTH=256 LINK_WIDTH=0
elab_negative lw_over_max        parallel_data_fetch DATA_WIDTH=256 LINK_WIDTH=257
elab_negative async_depth_small  parallel_data_fetch ASYNC_MODE=1 RSP_FIFO_DEPTH=2
elab_negative timeout_too_small  parallel_data_fetch TIMEOUT_CYCLES=8
elab_negative slice_impl_oob     parallel_data_fetch SLICE_IMPL=3
elab_negative async_pipe_conflict parallel_data_fetch ASYNC_MODE=1 LINK_PIPE_STAGES=1
elab_negative fifo_not_pow2      parallel_data_fetch RSP_FIFO_DEPTH=12
elab_negative fifo_not_pow2b     parallel_data_fetch RSP_FIFO_DEPTH=24
elab_negative req_dw_oob         parallel_data_fetch_requester DATA_WIDTH=8192
elab_negative req_stages_low     parallel_data_fetch_requester REQ_SYNC_STAGES=1
elab_negative prv_lw_oob         parallel_data_fetch_provider LINK_WIDTH=0
elab_negative prv_slice_oob      parallel_data_fetch_provider SLICE_IMPL=9

echo | tee -a "${DETAIL}"
SUMMARY="positive: ${PASS} pass / ${FAIL} fail; negative: ${NEG_PASS} pass / ${NEG_FAIL} fail"
echo "${SUMMARY}" | tee -a "${DETAIL}"
echo "${SUMMARY}" > "${EVID}/summary.txt"

if [ "${FAIL}" -ne 0 ] || [ "${NEG_FAIL}" -ne 0 ]; then
  exit 10
fi
exit 0
