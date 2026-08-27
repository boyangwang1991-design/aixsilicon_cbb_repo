#!/usr/bin/env bash
# ============================================================
# G4 功能验证：VCS 仿真（N2W/W2N 定向+随机）+ SVA + 断言变异
# QUE-012 width_conversion_fifo
# 用法: bash run_functional_sim.sh <cbb_root>
# ============================================================
set -euo pipefail

CBB_ROOT="${1:?用法: bash run_functional_sim.sh <cbb_root>}"
CBB="$CBB_ROOT/components/fifo_queue_buffer/width_conversion_fifo"
OUT="$CBB/evidence/g4_functional"
mkdir -p "$OUT"

RTL="$CBB/rtl/width_conversion_fifo.sv"
TB="$CBB/verification/simulation/width_conversion_fifo_tb.sv"
COMMON="-full64 -sverilog -timescale=1ns/1ps +incdir+$CBB/rtl"

echo "=== [G4-1] N2W 仿真 ==="
rm -rf /tmp/wcf_g4_n2w && mkdir -p /tmp/wcf_g4_n2w
( cd /tmp/wcf_g4_n2w \
  && vcs $COMMON $RTL $TB -top width_conversion_fifo_tb -l c.log >/dev/null 2>&1 \
  && ./simv +ntb_random_seed=1 -l run.log 2>&1 | grep -E "\[TB\]" > "$OUT/n2w_sim.txt" )

echo "=== [G4-2] W2N 仿真 ==="
rm -rf /tmp/wcf_g4_w2n && mkdir -p /tmp/wcf_g4_w2n
( cd /tmp/wcf_g4_w2n \
  && vcs $COMMON $RTL $TB -top width_conversion_fifo_tb -pvalue+width_conversion_fifo_tb.DIRECTION=1 -l c.log >/dev/null 2>&1 \
  && ./simv +ntb_random_seed=1 -l run.log 2>&1 | grep -E "\[TB\]" > "$OUT/w2n_sim.txt" )

echo "=== [G4-3] 断言变异: count<=DEPTH -> count>DEPTH 应触发断言失败 ==="
rm -rf /tmp/wcf_g4_mut && mkdir -p /tmp/wcf_g4_mut
# 轻量单文件：pkg 与 module 同居，变异直接拷贝单文件并改写断言（import 方案）。
cp $CBB/rtl/width_conversion_fifo.sv /tmp/wcf_g4_mut/dut_mut.sv
sed -i 's/(count <= DEPTH\[CNT_W-1:0\])/(count > DEPTH[CNT_W-1:0])/' /tmp/wcf_g4_mut/dut_mut.sv
( cd /tmp/wcf_g4_mut \
  && vcs $COMMON dut_mut.sv $TB -top width_conversion_fifo_tb -l c.log >/dev/null 2>&1 \
  && ./simv +ntb_random_seed=1 -l run.log 2>&1 | grep -icE "failed at" > "$OUT/mutation_failures.txt" )

echo "=== 证据目录 ==="
ls -la "$OUT/"
echo "=== 完成 ==="
