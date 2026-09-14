#!/usr/bin/env python3
"""Formality RTL equivalence for explicitly listed configurations, not the entire domain."""

import argparse, hashlib, json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from generate import generate


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    a = ap.parse_args()
    out = ROOT / "build/eda/formal"
    out.mkdir(parents=True, exist_ok=True)
    results = []
    for w, k, l in [(8, 45, 0)] if a.quick else [(8, 45, 0), (8, -7, 1), (128, -1, 0)]:
        for impl in ["BINARY", "CSD", "ADDER_GRAPH"]:
            d = out / f"w{w}_k{k}_l{l}_{impl.lower()}"
            d.mkdir(parents=True, exist_ok=True)
            cfg = dict(INPUT_WIDTH=w, COEFF=str(k), LATENCY=l)
            if k == -7:
                cfg.update(
                    OUTPUT_MODE="QUANTIZED",
                    OUTPUT_WIDTH=4,
                    OUTPUT_SIGNED=True,
                    SHIFT_RIGHT=1,
                    ROUND_MODE="NEAREST_EVEN",
                    OVERFLOW_MODE="SATURATE",
                )
            generate(dict(cfg, IMPL="NATIVE"), d / "ref", "cm_formal")
            generate(dict(cfg, IMPL=impl), d / "imp", "cm_formal")
            tcl = """set hdlin_sv_enable_rtl_attributes false
read_sverilog -r ref/cm_formal.sv
set_top r:/WORK/cm_formal
read_sverilog -i imp/cm_formal.sv
set_top i:/WORK/cm_formal
set_dont_match_points -type cell {r:/WORK/cm_formal/n* i:/WORK/cm_formal/n*}
match
if {[verify]} {puts "CM-FORMAL-PASS"; exit 0} else {report_failing_points; report_aborted_points; exit 1}
"""
            (d / "run.tcl").write_text(tcl)
            print("formal " + d.name, flush=True)
            with (d / "formal.txt").open("w") as f:
                r = subprocess.run(
                    ["fm_shell", "-f", "run.tcl"],
                    cwd=d,
                    stdout=f,
                    stderr=subprocess.STDOUT,
                    timeout=300,
                )
            log = (d / "formal.txt").read_text(errors="replace")
            good = r.returncode == 0 and "CM-FORMAL-PASS" in log and "Verification SUCCEEDED" in log
            result = {
                "parameters": cfg,
                "implementation": impl,
                "status": "proved" if good else "failed",
                "log_sha256": hashlib.sha256((d / "formal.txt").read_bytes()).hexdigest(),
                "reference_sha256": hashlib.sha256(
                    (d / "ref/cm_formal.sv").read_bytes()
                ).hexdigest(),
                "implementation_sha256": hashlib.sha256(
                    (d / "imp/cm_formal.sv").read_bytes()
                ).hexdigest(),
            }
            results.append(result)
            (out / "result.json").write_text(json.dumps(results, indent=2) + "\n")
            if not good:
                raise SystemExit("formal failed: " + str(d / "formal.txt"))
    print("CM-FORMAL-PASS", flush=True)


if __name__ == "__main__":
    main()
