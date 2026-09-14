#!/usr/bin/env python3
"""Fixed-library representative DC experiment; raw library context stays in build/."""

import argparse, hashlib, json, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from generate import generate


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--library", required=True)
    ap.add_argument("--period", type=float, default=2.5)
    ap.add_argument("--smoke", action="store_true")
    ap.add_argument(
        "--resume",
        action="store_true",
        help="reuse hash-checked completed points, including recorded timeouts",
    )
    ap.add_argument("--max-seconds", type=int, default=600)
    a = ap.parse_args()
    lib = Path(a.library).resolve()
    if not lib.is_file() or a.period <= 0 or a.max_seconds <= 0:
        raise SystemExit("invalid library/period")
    out = ROOT / "build/eda/ppa"
    out.mkdir(parents=True, exist_ok=True)
    points = []
    for w, k, l in (
        [(8, 45, 0)] if a.smoke else [(8, 45, 0), (16, 85, 2), (128, -((1 << 127) - 1), 0)]
    ):
        for impl in ["NATIVE"] if a.smoke else ["NATIVE", "BINARY", "CSD", "ADDER_GRAPH"]:
            tag = f"w{w}_l{l}_{impl.lower()}"
            d = out / tag
            previous = json.loads((d / "ppa.json").read_text()) if (d / "ppa.json").exists() else {}
            previous_rtl_hash = (
                hashlib.sha256((d / "cm_ppa.sv").read_bytes()).hexdigest()
                if (d / "cm_ppa.sv").exists()
                else None
            )
            previous_script = (d / "run.tcl").read_text() if (d / "run.tcl").exists() else None
            c, g = generate(dict(INPUT_WIDTH=w, COEFF=str(k), LATENCY=l, IMPL=impl), d, "cm_ppa")
            # Tcl quoting uses brace literals, rejecting metacharacters in external paths.
            if any(x in str(lib) + str(d) for x in "{}\n"):
                raise SystemExit("unsupported Tcl path")
            clocks = (
                f"create_clock -name clk -period {a.period} [get_ports clk_i]"
                if l
                else f"create_clock -name clk -period {a.period}"
            )
            script = f"""set_app_var target_library {{{lib}}}
set_app_var link_library [list * {{{lib}}}]
define_design_lib WORK -path ./work
analyze -format sverilog cm_ppa.sv
elaborate cm_ppa
current_design cm_ppa
link
{clocks}
set_input_delay 0.25 -clock clk [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay 0.25 -clock clk [all_outputs]
set_input_transition 0.05 [all_inputs]
set_load 0.01 [all_outputs]
set_clock_uncertainty 0.05 [get_clocks clk]
"""
            if not l:
                script += "set_false_path -from [get_ports {clk_i rst_ni ce_i}]\n"
            script += """compile_ultra
redirect -file check.rpt {check_design}
redirect -file check_timing.rpt {check_timing}
redirect -file area.rpt {report_area}
redirect -file timing.rpt {report_timing -max_paths 20}
redirect -file constraints.rpt {report_constraint -all_violators}
redirect -file power.rpt {report_power}
redirect -file resources.rpt {report_resources}
redirect -file cells.rpt {report_cell}
write -format verilog -hierarchy -output mapped.v
puts "CM-PPA-DONE"
exit
"""
            library_hash = hashlib.sha256(lib.read_bytes()).hexdigest()
            smoke = (
                json.loads((out / "smoke.json").read_text())
                if (out / "smoke.json").exists()
                else {}
            )
            previous_library = previous.get("library_sha256", smoke.get("library_sha256"))
            old_log = (d / "dc.txt").read_text(errors="replace") if (d / "dc.txt").exists() else ""
            if (
                a.resume
                and previous_script == script
                and previous_library == library_hash
                and previous_rtl_hash == hashlib.sha256((d / "cm_ppa.sv").read_bytes()).hexdigest()
                and "Fatal: Internal system error" in old_log
            ):
                previous = {
                    "tag": tag,
                    "configuration": c,
                    "status": "tool_internal_error",
                    "maturity": "unavailable",
                    "area": None,
                    "arrival_ns": None,
                    "wns_ns": None,
                    "dynamic_power": None,
                    "leakage_power": None,
                    "library_sha256": library_hash,
                    "rtl_sha256": previous_rtl_hash,
                    "raw_hashes": {
                        "dc.txt": hashlib.sha256((d / "dc.txt").read_bytes()).hexdigest()
                    },
                }
            reusable = (
                a.resume
                and previous_script == script
                and previous_library == library_hash
                and previous.get("rtl_sha256")
                == hashlib.sha256((d / "cm_ppa.sv").read_bytes()).hexdigest()
                and previous.get("raw_hashes")
                and all(
                    (d / name).is_file()
                    and hashlib.sha256((d / name).read_bytes()).hexdigest() == value
                    for name, value in previous["raw_hashes"].items()
                )
            )
            if reusable:
                (d / "ppa.json").write_text(json.dumps(previous, indent=2) + "\n")
                points.append(previous)
                print("reused " + tag, flush=True)
                continue
            (d / "run.tcl").write_text(script)
            print("synthesizing " + tag, flush=True)
            try:
                with (d / "dc.txt").open("w") as f:
                    r = subprocess.run(
                        ["dc_shell", "-f", "run.tcl"],
                        cwd=d,
                        stdout=f,
                        stderr=subprocess.STDOUT,
                        timeout=a.max_seconds,
                    )
            except subprocess.TimeoutExpired:
                result = {
                    "tag": tag,
                    "configuration": c,
                    "status": "timeout",
                    "maturity": "unavailable",
                    "timeout_seconds": a.max_seconds,
                    "area": None,
                    "arrival_ns": None,
                    "wns_ns": None,
                    "dynamic_power": None,
                    "leakage_power": None,
                    "library_sha256": library_hash,
                    "rtl_sha256": hashlib.sha256((d / "cm_ppa.sv").read_bytes()).hexdigest(),
                    "raw_hashes": {
                        "dc.txt": hashlib.sha256((d / "dc.txt").read_bytes()).hexdigest()
                    },
                }
                (d / "ppa.json").write_text(json.dumps(result, indent=2) + "\n")
                points.append(result)
                print("timeout " + tag, flush=True)
                continue
            log = (d / "dc.txt").read_text(errors="replace")
            if "Fatal: Internal system error" in log:
                result = {
                    "tag": tag,
                    "configuration": c,
                    "status": "tool_internal_error",
                    "maturity": "unavailable",
                    "area": None,
                    "arrival_ns": None,
                    "wns_ns": None,
                    "dynamic_power": None,
                    "leakage_power": None,
                    "library_sha256": library_hash,
                    "rtl_sha256": hashlib.sha256((d / "cm_ppa.sv").read_bytes()).hexdigest(),
                    "raw_hashes": {
                        "dc.txt": hashlib.sha256((d / "dc.txt").read_bytes()).hexdigest()
                    },
                }
                (d / "ppa.json").write_text(json.dumps(result, indent=2) + "\n")
                points.append(result)
                print("tool_internal_error " + tag, flush=True)
                continue
            if r.returncode or "CM-PPA-DONE" not in log or re.search(r"^Error:", log, re.M):
                raise SystemExit("DC failed: " + str(d / "dc.txt"))

            def number(file, pattern):
                m = re.search(pattern, (d / file).read_text())
                return float(m[1]) if m else None

            result = {
                "tag": tag,
                "configuration": c,
                "rtl_sha256": hashlib.sha256((d / "cm_ppa.sv").read_bytes()).hexdigest(),
                "maturity": "synthesized",
                "library_sha256": library_hash,
                "area": number("area.rpt", r"Total cell area:\s+([0-9.]+)"),
                "combinational_area": number("area.rpt", r"Combinational area:\s+([0-9.]+)"),
                "sequential_area": number("area.rpt", r"Noncombinational area:\s+([0-9.]+)"),
                "arrival_ns": number("timing.rpt", r"data arrival time\s+([0-9.]+)"),
                "wns_ns": number("timing.rpt", r"slack \([^)]*\)\s+(-?[0-9.]+)"),
                "tns": None,
                "buffer_count": None,
                "max_fanout": None,
                "dynamic_power": None,
                "leakage_power": None,
                "power_note": "unannotated tool estimate retained in raw report; no measured energy claim",
                "raw_hashes": {
                    n: hashlib.sha256((d / n).read_bytes()).hexdigest()
                    for n in ["area.rpt", "timing.rpt", "power.rpt", "check.rpt", "dc.txt"]
                },
            }
            if result["area"] is None:
                raise SystemExit("missing area report")
            (d / "ppa.json").write_text(json.dumps(result, indent=2) + "\n")
            points.append(result)
    context = {
        "library_sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
        "period_ns": a.period,
        "input_output_delay_ns": 0.25,
        "transition_ns": 0.05,
        "load_pf": 0.01,
        "uncertainty_ns": 0.05,
        "tool": "Design Compiler V-2023.12-SP3",
        "retiming": False,
        "activity": "unannotated default estimate",
        "points": points,
    }
    (out / ("smoke.json" if a.smoke else "results.json")).write_text(
        json.dumps(context, indent=2) + "\n"
    )
    if a.smoke:
        print("CBB_CAPABILITY_READY")
    else:
        print(
            "CM-PPA-PASS"
            if all(r.get("maturity") == "synthesized" for r in points)
            else "CM-PPA-PARTIAL"
        )


if __name__ == "__main__":
    main()
