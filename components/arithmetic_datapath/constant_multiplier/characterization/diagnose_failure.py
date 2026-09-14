#!/usr/bin/env python3
"""Correlate the DC child failure with retained kernel OOM evidence."""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    sources = {
        "dc": "build/eda/ppa/w128_l0_binary/dc.txt",
        "kernel": "build/eda/ppa_diagnosis/kernel-original.txt",
    }
    dc, kernel = [(ROOT / path).read_text(errors="replace") for path in sources.values()]
    child = re.search(r"detected bad exit for job (\d+)", dc)
    if not child:
        raise SystemExit("No DC child PID evidence")
    oom = re.search(
        rf"Out of memory: Killed process {child[1]} \(common_shell_ex\).*?"
        r"anon-rss:(\d+)kB",
        kernel,
    )
    if not oom:
        raise SystemExit("No matching kernel OOM evidence; do not infer OOM from DC alone")
    result = {
        "tag": "w128_l0_binary",
        "tool_status": "tool_internal_error",
        "root_cause": "system_out_of_memory",
        "child_pid": int(child[1]),
        "killed_child_anon_rss_kib": int(oom[1]),
        "evidence": {
            role: {"path": path, "sha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest()}
            for role, path in sources.items()
        },
        "note": "Kernel OOM kill and DC child failure match by PID; no PPA metrics inferred.",
    }
    low_path = ROOT / "build/eda/ppa_diagnosis/low_effort/dc.txt"
    if low_path.exists():
        low_log = low_path.read_text(errors="replace")
        if "The tool has just run out of memory" not in low_log:
            raise SystemExit("Low-effort trial has not reached the expected recorded OOM outcome")
        result["low_effort_retry"] = {
            "status": "tool_out_of_memory",
            "virtual_memory_limit_mib": 7168,
            "path": str(low_path.relative_to(ROOT)),
            "sha256": hashlib.sha256(low_path.read_bytes()).hexdigest(),
        }
        result["evidence"]["low_effort_dc"] = {
            "path": str(low_path.relative_to(ROOT)),
            "sha256": hashlib.sha256(low_path.read_bytes()).hexdigest(),
        }
    classic_path = ROOT / "build/eda/ppa_diagnosis/classic/dc.txt"
    if classic_path.exists():
        if "CM-PPA-DONE" in classic_path.read_text(errors="replace"):
            raise SystemExit("Classic experiment completed; re-evaluate its status")
        result["classic_retry"] = {
            "status": "cancelled",
            "reason": "Stopped at the user's request to wrap up; no PPA conclusion",
        }
        result["evidence"]["classic_dc"] = {
            "path": str(classic_path.relative_to(ROOT)),
            "sha256": hashlib.sha256(classic_path.read_bytes()).hexdigest(),
        }
    (ROOT / "reports/ppa-failure-diagnosis.json").write_text(json.dumps(result, indent=2) + "\n")
    print("CM-OOM-CONFIRMED")


if __name__ == "__main__":
    main()
