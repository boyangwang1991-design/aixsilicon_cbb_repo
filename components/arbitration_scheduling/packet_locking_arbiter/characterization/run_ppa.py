#!/usr/bin/env python3
"""Library-bound DC sweep and independent report extraction. Native tools only."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEP = ROOT.parent / "fixed_priority_arbiter/rtl/fixed_priority_arbiter.sv"
RTL = ROOT / "rtl/packet_locking_arbiter.sv"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def one(point, run_dir, db):
    n, mode, w = point
    d = run_dir / f"n{n}_m{mode}_w{w}"
    d.mkdir(parents=True, exist_ok=False)
    env = dict(
        os.environ,
        PLA_LIBRARY=str(db),
        PLA_DEP=str(DEP),
        PLA_RTL=str(RTL),
        PLA_N=str(n),
        PLA_MODE=str(mode),
        PLA_W=str(w),
        PLA_SDC=str(ROOT / "constraints/packet_locking_arbiter.sdc"),
    )
    with (d / "dc.txt").open("w") as f:
        p = subprocess.run(
            ["dc_shell", "-f", str(ROOT / "characterization/synth.tcl")],
            cwd=d,
            env=env,
            stdout=f,
            stderr=subprocess.STDOUT,
            timeout=900,
        )
    txt = (d / "dc.txt").read_text(errors="replace")
    if p.returncode or "PLA_SYNTH_DONE" not in txt or re.search(r"^Error:", txt, re.M):
        raise RuntimeError(f"DC failed: {d}/dc.txt")
    (d / "parameters.json").write_text(json.dumps(dict(NUM_REQ=n, LOCK_MODE=mode, LEN_W=w)))
    print("SYNTH", d.name, flush=True)


def number(pattern, text):
    m = re.search(pattern, text, re.M)
    if not m:
        raise ValueError("Missing report metric: " + pattern)
    return float(m.group(1))


def power(text, label, target):
    m = re.search(label + r"\s*=\s*([\d.eE+\-]+)\s*([munp]?W)", text)
    if not m:
        raise ValueError("Missing power metric " + label)
    units = {"W": 1, "mW": 1e-3, "uW": 1e-6, "nW": 1e-9, "pW": 1e-12}
    return float(m[1]) * units[m[2]] / units[target]


def extract(run_dir):
    rows = []
    for d in sorted(run_dir.glob("n*_m*_w*")):
        params = json.loads((d / "parameters.json").read_text())
        area = (d / "area.txt").read_text()
        timing = (d / "timing.txt").read_text()
        pw = (d / "power-total.txt").read_text()
        reg = (d / "reg_timing.txt").read_text()
        slack = [float(x) for x in re.findall(r"slack \((?:MET|VIOLATED)\)\s+([-\d.]+)", timing)]
        rr = [float(x) for x in re.findall(r"slack \((?:MET|VIOLATED)\)\s+([-\d.]+)", reg)]
        if not slack:
            raise ValueError("No timing evidence " + d.name)
        row = dict(
            parameters=params,
            area_um2=number(r"Total cell area:\s+([\d.]+)", area),
            worst_slack_ns=min(slack),
            reg_to_reg_slack_ns=min(rr) if rr else None,
            dyn_power_uW=power(pw, "Total Dynamic Power", "uW"),
            leak_power_nW=power(pw, "Cell Leakage Power", "nW"),
            registers=int((d / "registers.txt").read_text().strip()),
            reports_sha256={f.name: sha(f) for f in d.glob("*.txt")},
        )
        child_area = sum(
            float(x) for x in re.findall(r"^g_select\.u_(?:all|mask)\s+([\d.]+)", area, re.M)
        )
        row["child_area_um2"] = child_area
        row["parent_local_area_um2"] = round(row["area_um2"] - child_area, 6)
        rows.append(row)
    manifest = json.loads((run_dir / "context.json").read_text())
    result = dict(
        context=manifest,
        rows=rows,
        evidence_level="PPA-E2",
        activity="Vectorless input probability 0.5, toggle rate 0.1; not workload-measured power.",
    )
    result["extraction_sha256"] = sha(Path(__file__))
    result["tool_version"] = re.search(r"Version:\s+(\S+)", area).group(1)
    (ROOT / "reports/ppa-summary.json").write_text(json.dumps(result, indent=2) + "\n")
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axs = plt.subplots(1, 3, figsize=(12, 3.5))
    for mode in [0, 1]:
        points = sorted(
            [
                r
                for r in rows
                if r["parameters"]["LOCK_MODE"] == mode and r["parameters"]["LEN_W"] == 8
            ],
            key=lambda r: r["parameters"]["NUM_REQ"],
        )
        for ax, key, title in zip(
            axs,
            ["area_um2", "worst_slack_ns", "dyn_power_uW"],
            ["Area (um2)", "Worst setup slack (ns)", "Dynamic power (uW, estimated)"],
            strict=True,
        ):
            ax.plot(
                [r["parameters"]["NUM_REQ"] for r in points],
                [r[key] for r in points],
                "-o",
                label=["EOP", "Length"][mode],
            )
            ax.set_title(title)
            ax.set_xlabel("Requesters")
            ax.grid(alpha=0.3)
    axs[0].legend()
    fig.tight_layout()
    fig.savefig(ROOT / "reports/ppa-sweep.png", dpi=180)
    plt.close(fig)
    return rows


def main():
    global DEP
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", default="run-20260910-02")
    ap.add_argument("--extract-only", action="store_true")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--dep", type=Path)
    args = ap.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.run_id):
        raise SystemExit("Invalid run id")
    if args.dep:
        DEP = args.dep.resolve()
    run_dir = ROOT / "build/eda/ppa" / args.run_id
    if not args.extract_only:
        if not shutil.which("dc_shell"):
            raise SystemExit("OPTIONAL_UNAVAILABLE: dc_shell")
        snapshot = yaml.safe_load((ROOT / "build/eda/pdk.local.yaml").read_text())
        db = None
        for node in snapshot["nodes"]:
            for bundle in node["libraries"]:
                for lib in bundle["libraries"]:
                    if lib["library"] == "sc9_cmos28lp_base_hvt":
                        db = Path(lib["corner_files"]["db"]["tt_nominal_max_1p00v_25c"])
        if db is None or not db.is_file():
            raise SystemExit("Requested TT library not present in snapshot")
        run_dir.mkdir(parents=True, exist_ok=False)
        context = dict(
            run_id=args.run_id,
            rtl_sha256=sha(RTL),
            dependency=dict(vlnv="aixsilicon:cbb:fixed_priority_arbiter:0.1.0", sha256=sha(DEP)),
            library=db.name,
            library_sha256=sha(db),
            corner="TT 1.00V 25C",
            clock_ns=2.5,
            uncertainty_ns=0.1,
            input_delay_ns=0.5,
            output_delay_ns=0.5,
            output_load_pf=0.01,
            compile="compile_ultra -no_autoungroup; no retiming or clock gating",
            scripts={
                p.name: sha(p)
                for p in [
                    Path(__file__),
                    ROOT / "characterization/synth.tcl",
                    ROOT / "constraints/packet_locking_arbiter.sdc",
                ]
            },
        )
        (run_dir / "context.json").write_text(json.dumps(context, indent=2))
        (run_dir / "library.local.txt").write_text(str(db) + "\n")
        points = [(n, m, 8) for n in [1, 4, 17, 64] for m in [0, 1]] + [(4, 1, w) for w in [1, 16]]
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            list(pool.map(lambda p: one(p, run_dir, db), points))
    if not all((d / "power-total.txt").exists() for d in run_dir.glob("n*_m*_w*")):
        env = dict(os.environ, PLA_LIBRARY=(run_dir / "library.local.txt").read_text().strip())
        with (run_dir / "power-replay.txt").open("w") as f:
            p = subprocess.run(
                ["dc_shell", "-f", str(ROOT / "characterization/report_power.tcl")],
                cwd=run_dir,
                env=env,
                stdout=f,
                stderr=subprocess.STDOUT,
                timeout=240,
            )
        txt = (run_dir / "power-replay.txt").read_text(errors="replace")
        if p.returncode or "PLA_POWER_DONE" not in txt or re.search(r"^Error:", txt, re.M):
            raise RuntimeError("Power report replay failed")
    rows = extract(run_dir)
    print("PPA points:", len(rows))


if __name__ == "__main__":
    main()
