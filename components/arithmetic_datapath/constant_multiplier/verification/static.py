#!/usr/bin/env python3
"""Native negative elaboration and static log checks."""

import json, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    out = ROOT / "build/eda/static"
    out.mkdir(parents=True, exist_ok=True)
    results = []
    for i, param in enumerate(
        [
            ".INPUT_WIDTH(0)",
            ".INPUT_WIDTH(129)",
            ".COEFF_WIDTH(1)",
            ".LATENCY(9)",
            ".SHIFT_RIGHT(1)",
            ".ROUND_MODE(2)",
            ".OUTPUT_MODE(2)",
            ".IMPL(2)",
        ]
    ):
        d = out / str(i)
        d.mkdir(exist_ok=True)
        (d / "tb.sv").write_text(f"module tb;constant_multiplier #({param}) dut();endmodule\n")
        with (d / "compile.txt").open("w") as f:
            r = subprocess.run(
                [
                    "vcs",
                    "-full64",
                    "-sverilog",
                    str(ROOT / "rtl/constant_multiplier.sv"),
                    "tb.sv",
                    "-top",
                    "tb",
                    "-o",
                    "simv",
                ],
                cwd=d,
                stdout=f,
                stderr=subprocess.STDOUT,
                timeout=90,
            )
        log = (d / "compile.txt").read_text(errors="replace")
        ok = r.returncode != 0 and "CM-CONFIG" in log
        results.append(
            {"parameter": param, "expected": "elaboration rejection CM-CONFIG", "pass": ok}
        )
        if not ok:
            raise SystemExit("negative elaboration failed " + str(d / "compile.txt"))
    (out / "result.json").write_text(json.dumps(results, indent=2) + "\n")
    print("CM-STATIC-PASS")


if __name__ == "__main__":
    main()
