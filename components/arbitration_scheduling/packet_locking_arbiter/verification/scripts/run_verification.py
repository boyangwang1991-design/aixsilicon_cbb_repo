#!/usr/bin/env python3
"""Replay native VCS tests, negative elaboration, mutations and SpyGlass lint.

Run using the host's uv environment. No private skill is required at replay time.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "build/eda"
REPORT = ROOT / "reports"
RTL = ROOT / "rtl/packet_locking_arbiter.sv"
DEP = ROOT.parent / "fixed_priority_arbiter/rtl/fixed_priority_arbiter.sv"


def run(cmd, cwd, log, timeout=240):
    cwd.mkdir(parents=True, exist_ok=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as f:
        f.write("COMMAND: " + repr([str(x) for x in cmd]) + "\n")
        f.flush()
        p = subprocess.run(
            [str(x) for x in cmd], cwd=cwd, stdout=f, stderr=subprocess.STDOUT, timeout=timeout
        )
    return p.returncode, log.read_text(errors="replace")


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def compile_one(cfg, directory, source=RTL, tb=True):
    cmd = ["vcs", "-full64", "-sverilog", "-timescale=1ns/1ps", DEP, source]
    top = "pla_tb" if tb else "packet_locking_arbiter"
    if tb:
        cmd += [ROOT / "examples/packet_mux.sv", ROOT / "verification/simulation/pla_tb.sv"]
    cmd += ["-top", top, "-o", directory / "simv", "-Mdir=" + str(directory / "csrc")]
    for k, v in cfg.items():
        cmd += [f"-pvalue+{top}.{k}={v}"]
    return run(cmd, directory, directory / "compile.txt")


def configs():
    positive = []
    negative = []
    for kind in ["mandatory", "boundary", "pairwise", "negative"]:
        for item in yaml.safe_load((ROOT / f"verification/configs/{kind}.yaml").read_text())[
            "configs"
        ]:
            (negative if kind == "negative" else positive).append(dict(item, kind=kind))
    # Risk set is derived, separately recorded; generated SSOT files are untouched.
    seen = {tuple(c["parameters"].items()) for c in positive}
    for n in [3, 17, 64]:
        for w in [1, 8, 16]:
            p = dict(NUM_REQ=n, LOCK_MODE=1, LEN_W=w)
            if tuple(p.items()) not in seen:
                positive.append(
                    dict(config_id=f"cfg_num_req{n}_lock_mode1_len_w{w}", parameters=p, kind="risk")
                )
    return positive, negative


def simulate(item):
    d = WORK / "simulation" / item["config_id"]
    rc, txt = compile_one(item["parameters"], d)
    if rc:
        raise RuntimeError(f"compile failed: {d}/compile.txt")
    runs = []
    for seed in [101, 2027, 65537]:
        rc, txt = run([d / "simv", f"+seed={seed}"], d, d / f"seed_{seed}.txt")
        match = re.search(
            r"PLA_PASS N=(\d+) MODE=(\d+) LEN_W=(\d+) cycles=(\d+) beats=(\d+) packets=(\d+) stalls=(\d+) bubbles=(\d+) resets=(\d+)",
            txt,
        )
        if rc or not match or re.search(r"(?:Fatal|Error):", txt):
            raise RuntimeError(f"simulation failed: {d}/seed_{seed}.txt")
        got = tuple(map(int, match.groups()))
        if got[:3] != tuple(item["parameters"].values()):
            raise RuntimeError("Parameter override did not take effect")
        runs.append(
            dict(
                seed=seed,
                cycles=got[3],
                beats=got[4],
                packets=got[5],
                stalls=got[6],
                bubbles=got[7],
                resets=got[8],
            )
        )
    print("PASS", item["config_id"], flush=True)
    return dict(item, status="pass", runs=runs, compile_sha256=digest(d / "compile.txt"))


def tc_negative_params(items):
    result = []
    for item in items:
        d = WORK / "negative" / item["config_id"]
        rc, txt = compile_one(item["parameters"], d, tb=False)
        p = item["parameters"]
        expected = (
            "PC-001"
            if not 1 <= p["NUM_REQ"] <= 64
            else "PC-002"
            if p["LOCK_MODE"] not in [0, 1]
            else "PC-003"
        )
        if rc == 0 or expected not in txt:
            raise RuntimeError(f"Wrong negative outcome: {d}/compile.txt")
        result.append(dict(item, status="rejected_at_elaboration", diagnostic=expected))
    return result


def mutations():
    original = RTL.read_text()
    variants = {
        "release_without_fire": ("assign done = fire &&", "assign done = 1'b1 &&", 0),
        "wrong_rotation": ("selected + IW'(1)", "selected", 0),
        "early_length": ("effective_remaining == LEN_W'(1)", "effective_remaining == LEN_W'(2)", 1),
        "inverted_mutex": ("$onehot0(grant_o)", "!$onehot0(grant_o)", 0),
    }
    result = []
    for name, (old, new, mode) in variants.items():
        if original.count(old) != 1:
            raise RuntimeError(f"Mutation anchor ambiguous: {name}")
        d = WORK / "mutations" / name
        d.mkdir(parents=True, exist_ok=True)
        source = d / "mutant.sv"
        source.write_text(original.replace(old, new))
        cfg = dict(NUM_REQ=4, LOCK_MODE=mode, LEN_W=8)
        rc, txt = compile_one(cfg, d, source)
        if rc:
            raise RuntimeError(f"Mutant failed to compile, not a kill: {d}")
        rc, txt = run([d / "simv", "+seed=101"], d, d / "run.txt")
        if not re.search(r"Fatal:[^\n]*\n(?:PROP-|MODEL|CONSUMER|single-beat|reset priority)", txt):
            raise RuntimeError(f"Mutation survived or unrelated failure: {d}")
        result.append(dict(name=name, status="killed", log_sha256=digest(d / "run.txt")))
    return result


def lint():
    result = []
    for mode in [0, 1]:
        d = WORK / "lint" / f"mode{mode}"
        d.mkdir(parents=True, exist_ok=True)
        project = d / "pla.prj"
        project.write_text(
            f"set_option enableSV yes\nset_option enableSV09 yes\nset_option top packet_locking_arbiter\nset_option param {{packet_locking_arbiter.LOCK_MODE={mode}}}\nread_file -type hdl {DEP}\nread_file -type hdl {RTL}\n"
        )
        rc, txt = run(
            ["spyglass", "-project", project, "-goal", "lint/lint_rtl", "-batch"],
            d,
            d / "lint.txt",
            600,
        )
        summary = re.findall(
            r"Reported Messages.*?(\d+) Fatals,\s*(\d+) Errors,\s*(\d+) Warnings", txt
        )
        if rc or not summary or any(int(x) for x in summary[-1][:2]):
            raise RuntimeError(f"Lint failed: {d}/lint.txt")
        result.append(
            dict(
                mode=mode,
                fatals=int(summary[-1][0]),
                errors=int(summary[-1][1]),
                warnings=int(summary[-1][2]),
                log_sha256=digest(d / "lint.txt"),
            )
        )
    return result


def main():
    global DEP
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--phase", choices=["sim", "lint", "mutation", "negative", "all"], default="all"
    )
    ap.add_argument("--dep", type=Path)
    ap.add_argument("--jobs", type=int, default=2)
    args = ap.parse_args()
    if args.dep:
        DEP = args.dep.resolve()
    required = (
        ["spyglass"]
        if args.phase == "lint"
        else ["vcs", "spyglass"]
        if args.phase == "all"
        else ["vcs"]
    )
    for tool in required:
        if not shutil.which(tool):
            raise SystemExit(f"OPTIONAL_UNAVAILABLE: native {tool} missing")
    if not DEP.is_file():
        raise SystemExit("Provide dependency RTL with --dep")
    REPORT.mkdir(exist_ok=True)
    result = dict(
        status="running", rtl_sha256=digest(RTL), dependency_sha256=digest(DEP), phase=args.phase
    )
    start = time.monotonic()
    positive, negative = configs()
    try:
        if args.phase in ["sim", "all"]:
            with ThreadPoolExecutor(max_workers=args.jobs) as pool:
                result["matrix"] = list(pool.map(simulate, positive))
        if args.phase in ["negative", "all"]:
            result["negative"] = tc_negative_params(negative)
        if args.phase in ["mutation", "all"]:
            result["mutations"] = mutations()
        if args.phase in ["lint", "all"]:
            result["lint"] = lint()
        result["status"] = "pass"
    except Exception as exc:
        result["status"] = "fail"
        result["error"] = str(exc)
        raise
    finally:
        result["seconds"] = round(time.monotonic() - start, 2)
        (REPORT / f"verification-{args.phase}.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
