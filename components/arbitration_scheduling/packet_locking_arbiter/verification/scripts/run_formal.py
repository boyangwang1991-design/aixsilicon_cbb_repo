#!/usr/bin/env python3
"""Native Formality equivalence of parameter-specialized RTL against DC netlists.

This is synthesis equivalence, not an unbounded proof of packet liveness.
"""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RTL = ROOT / "rtl/packet_locking_arbiter.sv"
DEP = ROOT.parent / "fixed_priority_arbiter/rtl/fixed_priority_arbiter.sv"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def quote(p):
    if any(c in str(p) for c in "{}\n"):
        raise ValueError("Unsupported Tcl path")
    return "{" + str(p) + "}"


def one(d, library):
    params = json.loads((d / "parameters.json").read_text())
    work = d / "formal"
    work.mkdir(exist_ok=True)
    cache = work / "result.json"
    fingerprint = dict(
        rtl=sha(RTL), dependency=sha(DEP), netlist=sha(d / "netlist.v"), runner=sha(Path(__file__))
    )
    if cache.exists():
        previous = json.loads(cache.read_text())
        if previous.get("inputs") == fingerprint and previous.get("status") == "pass":
            return previous
    source = RTL.read_text()
    for k, v in params.items():
        source, count = re.subn(
            r"(parameter int " + k + r" = )\d+", lambda m, value=v: m[1] + str(value), source
        )
        if count != 1:
            raise ValueError("Parameter specialization mismatch")
    ref = work / "reference.sv"
    ref.write_text(source)
    tops = re.findall(
        r"^module (packet_locking_arbiter\w*)\s*\(", (d / "netlist.v").read_text(), re.M
    )
    if len(tops) != 1:
        raise ValueError("Cannot identify mapped top")
    script = work / "verify.tcl"
    script.write_text(f"""set synopsys_auto_setup true
set_svf {quote(d / "design.svf")}
read_db {quote(library)}
read_sverilog -r [list {quote(DEP)} {quote(ref)}]
set_top r:/WORK/packet_locking_arbiter
read_verilog -i {quote(d / "netlist.v")}
set_top i:/WORK/{tops[0]}
match
if {{[verify]}} {{
  puts "PLA_FORMAL_PASS"
}} else {{
  report_failing_points
  report_unmatched_points
  puts "PLA_FORMAL_FAIL"
}}
exit
""")
    with (work / "formal.txt").open("w") as f:
        result = subprocess.run(
            ["fm_shell", "-f", str(script)],
            cwd=work,
            stdout=f,
            stderr=subprocess.STDOUT,
            timeout=600,
        )
    txt = (work / "formal.txt").read_text(errors="replace")
    passed = (
        result.returncode == 0 and "PLA_FORMAL_PASS\n" in txt and "Verification SUCCEEDED" in txt
    )
    if not passed:
        raise RuntimeError("Formality failed: " + str(work / "formal.txt"))
    print("FORMAL PASS", d.name, flush=True)
    result = dict(
        parameters=params,
        status="pass",
        inputs=fingerprint,
        reference_sha256=sha(ref),
        netlist_sha256=sha(d / "netlist.v"),
        log_sha256=sha(work / "formal.txt"),
    )
    cache.write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", default="run-20260910-02")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument(
        "--available",
        action="store_true",
        help="Verify completed synthesis points during sweep; report remains partial.",
    )
    args = ap.parse_args()
    if not re.fullmatch(r"[\w-]+", args.run_id):
        raise SystemExit("Invalid run id")
    if not shutil.which("fm_shell"):
        raise SystemExit("OPTIONAL_UNAVAILABLE: native fm_shell")
    run = ROOT / "build/eda/ppa" / args.run_id
    library = Path((run / "library.local.txt").read_text().strip())
    ds = sorted(d for d in run.glob("n*_m*_w*") if (d / "parameters.json").exists())
    if not ds or (not args.available and len(ds) != 10):
        raise SystemExit("Expected complete 10-point synthesis sweep")
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(lambda d: one(d, library), ds))
    (ROOT / "reports/formal-summary.json").write_text(
        json.dumps(
            dict(
                status="pass" if len(rows) == 10 else "partial",
                method="RTL-to-mapped-netlist equivalence",
                rtl_sha256=sha(RTL),
                dependency_sha256=sha(DEP),
                rows=rows,
            ),
            indent=2,
        )
        + "\n"
    )


if __name__ == "__main__":
    main()
