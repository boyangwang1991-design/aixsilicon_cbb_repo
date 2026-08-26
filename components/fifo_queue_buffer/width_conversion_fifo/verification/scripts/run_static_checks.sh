#!/usr/bin/env bash
# ============================================================
# G3 静态基线：VCS compile/elab + SpyGlass lint（可复现）
# QUE-012 width_conversion_fifo
# 用法: bash run_static_checks.sh <cbb_root>
# ============================================================
set -euo pipefail

CBB_ROOT="${1:?用法: bash run_static_checks.sh <cbb_root>}"
CBB="$CBB_ROOT/components/fifo_queue_buffer/width_conversion_fifo"
OUT="$CBB/evidence/g3_static"
mkdir -p "$OUT"

echo "=== [G3-1] VCS compile/elab (默认 N2W) ==="
rm -rf /tmp/wcf_g3_n2w && mkdir -p /tmp/wcf_g3_n2w
( cd /tmp/wcf_g3_n2w \
  && vcs -full64 -sverilog -timescale=1ns/1ps +incdir+$CBB/rtl/interface \
       $CBB/rtl/interface/width_conversion_fifo_pkg.svh \
       $CBB/rtl/impl/impl_pointer_count/width_conversion_fifo.sv \
       -top width_conversion_fifo -l compile_n2w.log \
  && cp compile_n2w.log "$OUT/" )

echo "=== [G3-2] VCS compile/elab (W2N) ==="
rm -rf /tmp/wcf_g3_w2n && mkdir -p /tmp/wcf_g3_w2n
cat > /tmp/wcf_g3_w2n/w2n_top.sv <<'SV'
module w2n_top;
  width_conversion_fifo #(.DIRECTION(1), .NARROW_WIDTH(8), .RATIO(4), .DEPTH(8)) u_dut (
    .clk(1'b0), .rst_n(1'b0),
    .narrow_in_data('0), .narrow_in_valid(1'b0), .narrow_in_ready(),
    .wide_in_data('0), .wide_in_valid(1'b0), .wide_in_ready(),
    .narrow_out_data(), .narrow_out_valid(), .narrow_out_ready(1'b0),
    .wide_out_data(), .wide_out_valid(), .wide_out_ready(1'b0));
endmodule
SV
( cd /tmp/wcf_g3_w2n \
  && vcs -full64 -sverilog -timescale=1ns/1ps +incdir+$CBB/rtl/interface \
       $CBB/rtl/interface/width_conversion_fifo_pkg.svh \
       $CBB/rtl/impl/impl_pointer_count/width_conversion_fifo.sv w2n_top.sv \
       -top w2n_top -l compile_w2n.log \
  && cp compile_w2n.log "$OUT/" )

echo '=== [G3-3] VCS 负向: DEPTH=1 应触发 $error (PC-003/PC-005) ==='
rm -rf /tmp/wcf_g3_neg && mkdir -p /tmp/wcf_g3_neg
cat > /tmp/wcf_g3_neg/neg_top.sv <<'SV'
module neg_top;
  width_conversion_fifo #(.DIRECTION(0), .NARROW_WIDTH(8), .RATIO(4), .DEPTH(1)) u_dut (
    .clk(1'b0), .rst_n(1'b0),
    .narrow_in_data('0), .narrow_in_valid(1'b0), .narrow_in_ready(),
    .wide_in_data('0), .wide_in_valid(1'b0), .wide_in_ready(),
    .narrow_out_data(), .narrow_out_valid(), .narrow_out_ready(1'b0),
    .wide_out_data(), .wide_out_valid(), .wide_out_ready(1'b0));
endmodule
SV
set +e
( cd /tmp/wcf_g3_neg \
  && vcs -full64 -sverilog -timescale=1ns/1ps +incdir+$CBB/rtl/interface \
       $CBB/rtl/interface/width_conversion_fifo_pkg.svh \
       $CBB/rtl/impl/impl_pointer_count/width_conversion_fifo.sv neg_top.sv \
       -top neg_top -l compile_neg.log >/dev/null 2>&1 )
NEG_RC=$?
set -e
if [ "$NEG_RC" -eq 0 ]; then
  echo "NEGATIVE-DEPTH1-FAILED-TO-REJECT (unexpected: vcs rc=0)" | tee "$OUT/negative_depth1.txt"
else
  {
    echo "NEGATIVE-REJECTED-OK (elaboration \$error, vcs rc=$NEG_RC)"
    grep -iE "PC-00" /tmp/wcf_g3_neg/compile_neg.log | head
  } | tee "$OUT/negative_depth1.txt"
fi

echo "=== [G3-4] SpyGlass lint/lint_rtl ==="
rm -rf /tmp/wcf_g3_lint && mkdir -p /tmp/wcf_g3_lint
cat > /tmp/wcf_g3_lint/wcf.prj <<PRJ
set_option enableSV09 yes
set_option top width_conversion_fifo
read_file -type verilog $CBB/rtl/interface/width_conversion_fifo_pkg.svh
read_file -type verilog $CBB/rtl/impl/impl_pointer_count/width_conversion_fifo.sv
PRJ
( cd /tmp/wcf_g3_lint && timeout 300 spyglass -project wcf.prj -goal lint/lint_rtl -batch > lint_run.log 2>&1 \
  && echo "SPYGLASS-LINT-PASS" || echo "SPYGLASS-LINT-NONZERO" ) | tee "$OUT/spyglass_lint.txt"
cp /tmp/wcf_g3_lint/wcf/consolidated_reports/*/moresimple.rpt "$OUT/" 2>/dev/null || true

echo "=== G3 证据目录 ==="
ls -la "$OUT/"
echo "=== 完成 ==="
