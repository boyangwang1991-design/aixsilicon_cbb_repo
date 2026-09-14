#!/usr/bin/env python3
"""Replay/extract isolated W128 BINARY synthesis recovery experiments."""

import argparse
import hashlib
import json
import os
import re
import resource
import signal
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "build/eda/ppa/w128_l0_binary"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--extract-only", action="store_true")
    ap.add_argument("--strategy", choices=["low_effort", "classic"], default="low_effort")
    args = ap.parse_args()
    retry = ROOT / "build/eda/ppa_diagnosis" / args.strategy
    compile_command = (
        "set_datapath_optimization_effort [current_design] low\ncompile_ultra"
        if args.strategy == "low_effort"
        else "compile -map_effort medium"
    )
    original_script = (ORIGINAL / "run.tcl").read_text()
    if original_script.count("\ncompile_ultra\n") != 1:
        raise SystemExit("Unexpected original synthesis script")
    script = original_script.replace(
        "\ncompile_ultra\n",
        "\n" + compile_command + "\n",
    )
    rtl = (ORIGINAL / "cm_ppa.sv").read_bytes()
    if not args.extract_only:
        if (retry / "dc.txt").exists():
            raise SystemExit(
                "Existing evidence retained; use --extract-only or archive the retry directory"
            )
        retry.mkdir(parents=True, exist_ok=True)
        (retry / "cm_ppa.sv").write_bytes(rtl)
        (retry / "run.tcl").write_text(script)

        def limits():
            resource.setrlimit(resource.RLIMIT_AS, (7 * 1024**3, 7 * 1024**3))

        with (retry / "dc.txt").open("w") as output:
            proc = subprocess.Popen(
                ["dc_shell", "-f", "run.tcl"],
                cwd=retry,
                stdout=output,
                stderr=subprocess.STDOUT,
                start_new_session=True,
                preexec_fn=limits,
            )
            try:
                rc = proc.wait(timeout=600)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGTERM)
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                raise SystemExit("Retry timed out; evidence retained")
            if rc:
                raise SystemExit(f"DC retry exited {rc}; evidence retained")
    if (retry / "run.tcl").read_text() != script or (retry / "cm_ppa.sv").read_bytes() != rtl:
        raise SystemExit("Retry inputs do not match the documented experiment")
    log = (retry / "dc.txt").read_text(errors="replace")
    if "CM-PPA-DONE" not in log or re.search(r"^Error:|Fatal:", log, re.M):
        raise SystemExit("No successful DC completion; no PPA result emitted")

    def number(file, pattern):
        match = re.search(pattern, (retry / file).read_text())
        if not match:
            raise SystemExit("Missing metric in " + file)
        return float(match[1])

    files = [
        "cm_ppa.sv",
        "run.tcl",
        "dc.txt",
        "area.rpt",
        "timing.rpt",
        "power.rpt",
        "check.rpt",
        "check_timing.rpt",
        "constraints.rpt",
        "mapped.v",
        "cells.rpt",
    ]
    original = json.loads((ORIGINAL / "ppa.json").read_text())
    result = {
        "tag": "w128_l0_binary",
        "configuration": original["configuration"],
        "status": "synthesized",
        "library_sha256": original["library_sha256"],
        "compile": compile_command.replace("\n", "; "),
        "strategy": args.strategy,
        "virtual_memory_limit_mib": 7168,
        "timeout_seconds": 600,
        "area": number("area.rpt", r"Total cell area:\s+([0-9.]+)"),
        "arrival_ns": number("timing.rpt", r"data arrival time\s+([0-9.]+)"),
        "wns_ns": number("timing.rpt", r"slack \([^)]*\)\s+(-?[0-9.]+)"),
        "raw_hashes": {
            name: hashlib.sha256((retry / name).read_bytes()).hexdigest() for name in files
        },
        "comparison": "Separate experiment: optimization differs from the main PPA table",
        "rtl_changed": False,
        "netlist_equivalence": "not_run",
    }
    (ROOT / f"reports/ppa-retry-{args.strategy}.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    print("CM-PPA-RETRY-PASS")


if __name__ == "__main__":
    main()
