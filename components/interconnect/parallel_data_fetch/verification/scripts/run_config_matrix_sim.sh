#!/usr/bin/env bash
# G5 配置空间验证 — parallel_data_fetch（配置逐点 RTL 仿真，分两层执行）
#
# 分层策略（运行时间可控 + 不违反阶段前置）：
#   Tier A（默认，留在 C4/G5）：有界代表点，覆盖各参数分区与关键交互，
#     目的 = 证明"这批代表配置都能正确工作"，使 RTL 成为 C5/G6 的合法候选。
#     Tier B（--full，G6 PPA 之后执行）：在 Pareto 点已知的前提下扩大扫描
#     （含 --complete-pairwise 全覆盖），交给 CI runner，不阻塞交互流程。
#     依据：workflow-policy PLAN-01 阶段顺序 C4(G4/G5) → C5(G6)，
#     且 artifact-contract 要求 C5 前置为"功能 smoke 通过的候选"。
#
# 每个配置：独立编译（+define+ 注入参数）→ 跑一笔端到端事务 → 断言语义。
# 实测单配置 ≈ 20 s（VCS W-2024.09），Tier A 约 12 点 ≈ 4 min；Tier B 32 点 ≈ 11 min。
#
# 纪律：本 TB 无随机（确定性）；证据以 *.txt 落 build/eda/evidence/g5_config/；原始日志不入库。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBB_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RTL_REQ="${CBB_DIR}/rtl/parallel_data_fetch_requester.sv"
RTL_PRV="${CBB_DIR}/rtl/parallel_data_fetch_provider.sv"
RTL_TOP="${CBB_DIR}/rtl/parallel_data_fetch.sv"
TB="${CBB_DIR}/verification/simulation/config_matrix_tb.sv"
WORK="${CBB_DIR}/build/eda"
EVID="${WORK}/evidence/g5_config"

mkdir -p "${WORK}" "${EVID}"
cd "${WORK}" || exit 40

if ! command -v vcs >/dev/null 2>&1; then
  echo "OPTIONAL_UNAVAILABLE: vcs not found on PATH" | tee "${EVID}/config_matrix_sim.txt"
  exit 20
fi

PASS=0; FAIL=0; SKIP=0
DETAIL="${EVID}/config_matrix_sim.txt"
: > "${DETAIL}"
echo "== parallel_data_fetch G5 config-space simulation ==" | tee -a "${DETAIL}"
echo "vcs: $(vcs -ID 2>/dev/null | head -1 || echo unknown)" | tee -a "${DETAIL}"
echo "blocks: mandatory + boundary + pairwise 代表点 + risk + consumer + 异步族 + 切片三实现" | tee -a "${DETAIL}"
echo | tee -a "${DETAIL}"

# run_cfg <label> <DW=x;LW=y;...>
run_cfg() {
  local label="$1"; local cfg="$2"
  local defs=()

  IFS=';' read -ra KV <<< "$cfg"
  # 整流校验：DW % LW == 0 且 DW >= LW（config-gen 已保证，此处防手工误加）
  local dw lw
  dw="$(echo "${cfg}" | tr ';' '\n' | awk -F= '$1=="DW"{print $2}')"
  lw="$(echo "${cfg}" | tr ';' '\n' | awk -F= '$1=="LW"{print $2}')"
  if [ -n "${dw}" ] && [ -n "${lw}" ]; then
    if [ $((dw % lw)) -ne 0 ] || [ "${dw}" -lt "${lw}" ]; then
      echo "SKIP  ${label} (non-integer split DW=${dw} LW=${lw}; illegal by contract)" | tee -a "${DETAIL}"
      SKIP=$((SKIP+1)); return
    fi
  fi

  for kv in "${KV[@]}"; do defs+=("+define+${kv%%=*}=${kv#*=}"); done

  if ! vcs -full64 -sverilog -timescale=1ns/1ps -nc -assert svaext \
        "${defs[@]}" "${RTL_REQ}" "${RTL_PRV}" "${RTL_TOP}" "${TB}" -top config_matrix_tb \
        -o "simv_g5_${label}" > "g5_compile_${label}.log" 2>&1; then
    echo "FAIL  ${label} (compile) [${cfg}]" | tee -a "${DETAIL}"
    grep -E "Error-\[" -m3 "g5_compile_${label}.log" | tee -a "${DETAIL}"
    FAIL=$((FAIL+1)); return
  fi

  ./"simv_g5_${label}" -l "g5_run_${label}.log" > "g5_run_${label}.txt" 2>&1
  local rc=$?
  if [ "${rc}" -eq 0 ] && grep -q "CONFIG_PASS" "g5_run_${label}.txt"; then
    echo "PASS  ${label} [${cfg}]" | tee -a "${DETAIL}"
    PASS=$((PASS+1))
  else
    echo "FAIL  ${label} (simulate rc=${rc}) [${cfg}]" | tee -a "${DETAIL}"
    grep -E "^\[FAIL\]|CONFIG_FAIL" "g5_run_${label}.txt" | head -5 | tee -a "${DETAIL}"
    FAIL=$((FAIL+1))
  fi
}

# ============================================================================
# Tier A —— 有界代表点（默认；留在 C4/G5，目标 ≤4 min）
# 选取原则：每个参数至少出现一次极值/非默认；覆盖"参数×参数"关键交互；
#          代表 C5 候选所需的基本功能成立性。不声称全组合覆盖。
# ============================================================================
echo "---- Tier A: bounded representative points ----" | tee -a "${DETAIL}"
run_cfg A_default_dw256       "DW=256;LW=32"                                  # mandatory
run_cfg A_dw_min              "DW=8;LW=1"                                     # 宽度下界 + 最窄链路
run_cfg A_lw_eq_dw            "DW=8;LW=8"                                     # BEAT_COUNT=1 退化
run_cfg A_dw_max_narrow       "DW=4096;LW=1;TIMEOUT_CYCLES=65536"             # 宽度上界 + 最长帧
run_cfg A_nonpow2_beats       "DW=144;LW=16"                                  # 非 2 次幂 BEAT_COUNT
run_cfg A_slice_shift         "DW=256;LW=32;SLICE_IMPL=0"                     # 切片实现
run_cfg A_slice_indexed       "DW=256;LW=32;SLICE_IMPL=1"
run_cfg A_slice_banked        "DW=256;LW=32;SLICE_IMPL=2"
run_cfg A_msb_pipe8           "DW=256;LW=32;LSB_FIRST=0;LINK_PIPE_STAGES=8"   # 顺序 × 长线流水
run_cfg A_odd_parity          "DW=256;LW=32;ODD_PARITY=1"                     # 校验极性
run_cfg A_parity_off_to_off   "DW=256;LW=32;PARITY_EN=0;TIMEOUT_EN=0"         # 可选功能全关
run_cfg A_async_crit_fifo     "DW=64;LW=16;ASYNC_MODE=1;RSP_FIFO_DEPTH=4;CLK_A=11;CLK_B=20"  # 异步临界（RTL 接线敏感点）
run_cfg A_async_typ           "DW=256;LW=32;ASYNC_MODE=1;RSP_FIFO_DEPTH=16;CLK_A=5;CLK_B=7"  # 异步典型

# ============================================================================
# Tier B —— 扩展扫描（--full；建议在 G6 PPA 之后由 CI runner 执行）
# 依据：C4→C5 阶段顺序（workflow-policy PLAN-01）与 artifact-contract 的 C5 前置
#       （功能 smoke 通过的候选）。PPA 完成后已知 Pareto 点，可据此定向加扫，
#       并把剩余预算给 --complete-pairwise 全覆盖。
# ============================================================================
if [ "${1:-}" = "--full" ]; then
  echo "---- Tier B: extended sweep (--full) ----" | tee -a "${DETAIL}"
  # 宽度 × 链路 交互
  run_cfg B_dw4096_lw32        "DW=4096;LW=32;TIMEOUT_CYCLES=65536"
  run_cfg B_lw_max             "DW=256;LW=256"
  run_cfg B_gap512_64          "DW=512;LW=64"
  run_cfg B_gap1024_128        "DW=1024;LW=128;ODD_PARITY=1"
  run_cfg B_nonpow2_192_64     "DW=192;LW=64"
  # 校验 × 顺序
  run_cfg B_parity_lsb0        "DW=64;LW=8;LSB_FIRST=0;PARITY_EN=1"
  # 复位语义 × 可选功能
  run_cfg B_reset_data_one     "DW=256;LW=32;RESET_DEFAULT_DATA=1"
  run_cfg B_timeout_off_only   "DW=256;LW=32;TIMEOUT_EN=0"
  # 长线流水多点
  run_cfg B_pipe_1             "DW=256;LW=32;LINK_PIPE_STAGES=1"
  run_cfg B_pipe_4             "DW=256;LW=32;LINK_PIPE_STAGES=4"
  # consumer 全点
  run_cfg B_consumer_512_64    "DW=512;LW=64"
  run_cfg B_consumer_1024_128  "DW=1024;LW=128"
  # 异步：最大事务 + 多种时钟比 + 切片实现
  run_cfg B_async_4096_8       "DW=4096;LW=8;ASYNC_MODE=1;RSP_FIFO_DEPTH=512;CLK_A=5;CLK_B=7"
  run_cfg B_async_a_fast       "DW=64;LW=16;ASYNC_MODE=1;RSP_FIFO_DEPTH=64;CLK_A=5;CLK_B=20"
  run_cfg B_async_a_slow       "DW=64;LW=16;ASYNC_MODE=1;RSP_FIFO_DEPTH=64;CLK_A=20;CLK_B=5"
  run_cfg B_async_wide         "DW=1024;LW=64;ASYNC_MODE=1;RSP_FIFO_DEPTH=64;CLK_A=7;CLK_B=13"
  run_cfg B_async_slice_shift  "DW=256;LW=32;ASYNC_MODE=1;SLICE_IMPL=0;RSP_FIFO_DEPTH=16;CLK_A=7;CLK_B=11"
  run_cfg B_async_slice_indexed "DW=256;LW=32;ASYNC_MODE=1;SLICE_IMPL=1;RSP_FIFO_DEPTH=16;CLK_A=7;CLK_B=11"
  run_cfg B_async_pipe0_parity "DW=256;LW=32;ASYNC_MODE=1;PARITY_EN=1;ODD_PARITY=1;RSP_FIFO_DEPTH=16;CLK_A=3;CLK_B=5"
else
  echo "---- Tier B skipped（默认只跑 Tier A；需要扩展扫描时加 --full，建议在 G6 之后）----" | tee -a "${DETAIL}"
fi

echo | tee -a "${DETAIL}"
SUMMARY="g5 config matrix: ${PASS} pass / ${FAIL} fail / ${SKIP} skip (Tier $([ "${1:-}" = "--full" ] && echo 'A+B' || echo 'A'))"
echo "${SUMMARY}" | tee -a "${DETAIL}"
echo "${SUMMARY}" > "${EVID}/summary.txt"
[ "${FAIL}" -eq 0 ] || exit 10
exit 0