#!/usr/bin/env bash
# ============================================================================
# run_static_checks.sh — G3 静态基线（Compile/Elaboration/Lint/负向）
# 用法: bash verification/scripts/run_static_checks.sh  （从 CBB 根目录执行）
# 产出: build/eda/evidence/g3_static/{compile.txt, negative_elab.txt, lint.txt}
# 纪律：先探测原生工具（vcs/spyglass），再执行；EDA 产物在 build/eda/ 下
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
P=$(pwd)
EV="$P/build/eda/evidence/g3_static"
WORK="$P/build/eda"
mkdir -p "$EV" "$WORK"

RTL="$P/rtl/apb_register_slice.sv"
NEG_TB="$P/verification/formal/negative_elab_tb.sv"   # 正式负向 TB（tc_negative_elab）

echo "=== [probe] EDA tools ==="
command -v vcs >/dev/null 2>&1 && echo "vcs=$(command -v vcs)" || echo "vcs: MISSING"
command -v spyglass >/dev/null 2>&1 && echo "spyglass=$(command -v spyglass)" || echo "spyglass: MISSING"

# ---- 1. Compile + Elaboration（正例参数矩阵 + 负向参数拦截）----
if command -v vcs >/dev/null 2>&1; then
  # 正向：SLICE_MODE×RESP_STAGES × 宽度点编译/elab 矩阵（可复现）
  : > "$EV/param_matrix.txt"
  for mode in 0 1 2; do
    for rs in 1 2; do
      for aw in 8 16 32; do
        for dw in 8 32 64; do
          if ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog \
              -pvalue+apb_register_slice.ADDR_WIDTH=$aw \
              -pvalue+apb_register_slice.DATA_WIDTH=$dw \
              -pvalue+apb_register_slice.SLICE_MODE=$mode \
              -pvalue+apb_register_slice.RESP_STAGES=$rs \
              $RTL -o /tmp/ars_g3_${mode}_${rs}_${aw}_${dw} > "$EV/tmp.log" 2>&1 ); then
            echo "PASS mode=$mode rs=$rs aw=$aw dw=$dw" | tee -a "$EV/param_matrix.txt"
          else
            echo "FAIL mode=$mode rs=$rs aw=$aw dw=$dw" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1
          fi
        done
      done
    done
  done

  # 负向：非法参数 elaboration $error 拦截（REQ-007；vcs 非零退出 + 命中报错 ID）
  set +e
  ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog $RTL $NEG_TB -top negative_elab_tb \
      -o /tmp/ars_neg > "$EV/negative_elab.txt" 2>&1 )
  neg_rc=$?
  set -e
  if [ "$neg_rc" -eq 0 ]; then
    echo "[NEGATIVE] elaboration 未拦截非法参数，负向测试失败"; exit 1
  fi
  grep -qi "ADDR_WIDTH\|DATA_WIDTH\|SLICE_MODE\|RESP_STAGES\|PC-001\|PC-006" "$EV/negative_elab.txt" || {
    echo "[NEGATIVE] vcs 非零退出但未命中预期报错 ID"; cat "$EV/negative_elab.txt"; exit 1; }
  echo "compile/elab PASS: $(grep -c PASS "$EV/param_matrix.txt") positive configs + negative elab intercepted" \
    > "$EV/compile.txt"
  echo "[G3] compile/elab OK (vcs)"
else
  echo "[BLOCKED] vcs not found" > "$EV/compile.txt"
fi

# ---- 2. Lint（SpyGlass lint/lint_rtl，新式 project 调用）----
if command -v spyglass >/dev/null 2>&1; then
  SGW="$WORK/sg"
  rm -rf "$SGW" && mkdir -p "$SGW"
  cat > "$SGW/ars_lint.prj" <<EOF
set_option enableSV yes
set_option enableSV09 yes
set_option top apb_register_slice
read_file -type hdl $RTL
EOF
  ( cd "$SGW" && spyglass -project ars_lint.prj -goal lint/lint_rtl -batch \
      > "$EV/tmp_lint.log" 2>&1 ) || true
  summary=$(grep "Reported Messages" "$EV/tmp_lint.log" | tail -1 || true)
  echo "Lint Summary: $summary" > "$EV/lint.txt"
  echo "（0 Fatal / 0 Error 即通过；warning/info 见 lint_waivers.md）" >> "$EV/lint.txt"
  fatal=$(echo "$summary" | sed -n 's/.* \([0-9][0-9]*\) Fatals.*/\1/p')
  err=$(echo "$summary" | sed -n 's/.* Fatals, *\([0-9][0-9]*\) Errors.*/\1/p')
  fatal=${fatal:-1}                    # 未匹配到汇总行则视为失败
  err=${err:-0}
  if [ "$fatal" -gt 0 ] || [ "$err" -gt 0 ]; then
    echo "[lint] Fatal=$fatal Error=$err，阻断 G3"; cat "$EV/tmp_lint.log"; exit 1
  fi
  echo "[G3] lint OK (spyglass lint/lint_rtl: 0 Fatal / 0 Error)"
else
  echo "[skip] spyglass MISSING → Lint 走 OPTIONAL_UNAVAILABLE" > "$EV/lint.txt"
fi

rm -f "$EV/tmp.log" "$EV/tmp_lint.log"
echo "[G3] static baseline OK — evidence in $EV/（EDA 产物在 build/eda/，不入库）"
