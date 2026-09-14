#!/usr/bin/env python3
"""plot_ppa_comparison.py — accumulator PPA 对比图（面积 / 动态功耗 / 漏电）。

数据源：build/eda/ppa/<run-id>/*_summary.txt（synth_sweep.tcl 产出）。
输出：<out>.png（150dpi，面积/动态功耗/漏电三个子图）。
用法（从 CBB 根目录）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dir build/eda/ppa/<RUNID> --out reports/ppa_<RUNID>.png
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


def load_summaries(run_dir: Path) -> dict[str, dict[str, str]]:
    data: dict[str, dict[str, str]] = {}
    for f in sorted(run_dir.glob("*_summary.txt")):
        tag = f.name.removesuffix("_summary.txt")
        d: dict[str, str] = {}
        for line in f.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = re.match(r"(area|dyn_power_uW|leak_power_nW|arrival|slack)=(.+)", line)
            if m:
                d[m.group(1)] = m.group(2)
        data[tag] = d
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dir", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()
    run_dir, out = args.run_dir.resolve(), args.out.resolve()
    if not run_dir.is_dir():
        print(f"ERROR: run dir not found: {run_dir}", file=sys.stderr)
        return 10
    data = load_summaries(run_dir)
    if not data:
        print(f"ERROR: no *_summary.txt under {run_dir}", file=sys.stderr)
        return 10

    tags = list(data)
    def col(key: str) -> list[float]:
        vals = []
        for t in tags:
            try:
                vals.append(float(data[t].get(key, "nan")))
            except (TypeError, ValueError):
                vals.append(float("nan"))
        return vals

    area, dyn, leak = col("area"), col("dyn_power_uW"), col("leak_power_nW")

    fig, axes = plt.subplots(3, 1, figsize=(12, 10))
    x = range(len(tags))
    axes[0].bar(x, area, color="#1f77b4")
    axes[0].set_ylabel("Area (um^2)"); axes[0].set_title("accumulator PPA (run sweep, tt 1p00v 25c)")
    axes[1].bar(x, dyn, color="#2ca02c")
    axes[1].set_ylabel("Dynamic Power (uW)")
    axes[2].bar(x, leak, color="#d62728")
    axes[2].set_ylabel("Leakage (nW)")
    for ax in axes:
        ax.set_xticks(x)
        ax.set_xticklabels(tags, rotation=45, ha="right", fontsize=7)
        ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    print(f"wrote {out} ({len(tags)} points)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
