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

RTL="$P/rtl/incrementer_decrementer.sv"
NEG_TB="$P/verification/formal/negative_elab_tb.sv"

echo "=== [probe] EDA tools ==="
command -v vcs >/dev/null 2>&1 && echo "vcs=$(command -v vcs)" || echo "vcs: MISSING"
command -v spyglass >/dev/null 2>&1 && echo "spyglass=$(command -v spyglass)" || echo "spyglass: MISSING"

# ---- 1. Compile + Elaboration（正例 + 负向参数拦截）----
if command -v vcs >/dev/null 2>&1; then
  # 正向：两实现 × 多参数点 × CG_EN 编译/elab 矩阵（可复现）
  : > "$EV/param_matrix.txt"
  for impl in 0 1; do
    for n in 8 16 32 64; do
      for seg in 4 8; do
        for cg in 0 1; do
          if ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog \
              -pvalue+incrementer_decrementer.DATA_W=$n \
              -pvalue+incrementer_decrementer.ID_IMPL=$impl \
              -pvalue+incrementer_decrementer.SEG_W=$seg \
              -pvalue+incrementer_decrementer.CG_EN=$cg \
              "$RTL" -o /tmp/ide_g3_${impl}_${n}_${seg}_${cg} > "$EV/tmp.log" 2>&1 ); then
            echo "PASS impl=$impl W=$n SEG=$seg CG=$cg" | tee -a "$EV/param_matrix.txt"
          else
            echo "FAIL impl=$impl W=$n SEG=$seg CG=$cg" | tee -a "$EV/param_matrix.txt"; cat "$EV/tmp.log"; exit 1
          fi
        done
      done
    done
  done

  # 负向：非法参数 elaboration $error 拦截（REQ-005；vcs 非零退出 + 命中报错 ID）
  # TB negative_elab_tb 直接以非法参数实例化（DATA_W=1/1025、ID_IMPL=2、SEG_W=1/17）
  set +e
  ( cd "$WORK" && vcs -full64 -timescale=1ns/1ps -sverilog \
      "$RTL" "$NEG_TB" -top negative_elab_tb \
      -o /tmp/ide_neg > "$EV/negative_elab.txt" 2>&1 )
  neg_rc=$?
  set -e
  if [ "$neg_rc" -eq 0 ]; then
    echo "[NEGATIVE] 非法参数未拦截，负向测试失败"; exit 1
  fi
  grep -qi "PC-001\|PC-002\|PC-003\|PC-004\|PC-005" "$EV/negative_elab.txt" || {
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
  cat > "$SGW/ide_lint.prj" <<EOF
set_option enableSV yes
set_option enableSV09 yes
set_option top incrementer_decrementer
set_option incdir $P/rtl
set_option mthresh 200000
read_file -type hdl $RTL
EOF
  ( cd "$SGW" && spyglass -project ide_lint.prj -goal lint/lint_rtl -batch \
      > "$EV/tmp_lint.log" 2>&1 ) || true
  summary=$(grep "Reported Messages" "$EV/tmp_lint.log" | tail -1 || true)
  echo "Lint Summary: $summary" > "$EV/lint.txt"
  echo "（0 Fatal / 0 Error 即通过；warning/info 见 lint_waivers.md）" >> "$EV/lint.txt"
  fatal=$(echo "$summary" | sed -n 's/.* \([0-9][0-9]*\) Fatals.*/\1/p')
  err=$(echo "$summary" | sed -n 's/.* Fatals, *\([0-9][0-9]*\) Errors.*/\1/p')
  fatal=${fatal:-1}
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
