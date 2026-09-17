#!/usr/bin/env bash
# run_synth_sweep.sh — G6 PPA 综合 + 抽取 runner（包内 Bash，供 run-step 调用）
#
# 纪律：
#   * 先探测综合工具（command -v dc_shell）；未注册 aix action 不等于 EDA 不可用；
#   * 原始综合产物落 build/eda/ppa/<RUNID>/（build/ 不入库）；本脚本不改 RTL；
#   * 库上下文来自 characterization/pdk.yaml（真实库，非伪造）；corner 为 tt 单角。
#
# 用法（从 CBB 根）：
#   IDE_RUN_ID=run-<id> bash characterization/run_synth_sweep.sh
# 产物：build/eda/ppa/<RUNID>/pdf_<tag>_{area,timing,power}.rpt + *_summary.txt
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export IDE_CBB_ROOT="${IDE_CBB_ROOT:-$CBB_DIR}"
export IDE_RTL_DIR="${IDE_RTL_DIR:-$CBB_DIR/rtl}"
export IDE_RUN_ID="${IDE_RUN_ID:-run-$(date +%Y%m%d)-01}"

if ! command -v dc_shell >/dev/null 2>&1; then
  echo "OPTIONAL_UNAVAILABLE: dc_shell not found on PATH" >&2
  exit 20
fi

LOG_DIR="${CBB_DIR}/build/eda"
mkdir -p "${LOG_DIR}"
LOG="${LOG_DIR}/synth_${IDE_RUN_ID}.log"

# EDA 产物纪律：dc_shell 会在 CWD 生成 `.mr` 等中间文件，必须落 build/eda（不入库），
# 不得散落 CBB 根。故在 build/eda 下运行，用绝对路径引用 tcl 与包内路径。
cd "${LOG_DIR}" || exit 40
dc_shell -f "${SCRIPT_DIR}/synth_sweep.tcl" > "${LOG}" 2>&1
rc=$?
# 清理本 CWD 的 DC 中间产物（保留 .log 与 ppa 结果）
rm -rf "${LOG_DIR}"/*.mr 2>/dev/null || true

done_cnt="$(grep -cE '^PPA-DONE' "${LOG}" || true)"
sum_cnt="$(find "${CBB_DIR}/build/eda/ppa/${IDE_RUN_ID}" -name '*_summary.txt' 2>/dev/null | wc -l)"

echo "[g6] runid=${IDE_RUN_ID} dc_rc=${rc} ppa_done=${done_cnt} summaries=${sum_cnt}"
echo "[g6] log=${LOG}"

# 库/corner 错误不得被当作"完成"；无 summary 即失败
if [ "${rc}" -ne 0 ] || [ "${sum_cnt}" -eq 0 ]; then
  echo "[g6] FAIL: synthesis did not produce summaries (see ${LOG})" >&2
  exit 10
fi
exit 0