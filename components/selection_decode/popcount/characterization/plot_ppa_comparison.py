#!/usr/bin/env python3
"""PPA 对比绘图（面积/时序/动态功耗 × 数据位宽，按实现分线）。

数据源：build/eda/ppa/<run-id>/*_summary.txt（含 area/arrival/dyn_power_uW）。
输出：reports/ppa_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 工作区根执行）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dir build/eda/ppa/run-20260828-01 --out reports/ppa_run-20260828-01.png

按 SKILL 纪律：多实现/多配置 Sweep 完成后必须出对比图（禁 ASCII 图、禁只贴文本）；
功耗是 PPA 一级属性，与面积/时序同图呈现。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # 无显示环境出图
import matplotlib.pyplot as plt  # noqa: E402

IMPL_NAMES = {0: "direct", 1: "tree", 2: "wallace", 3: "comp4_2", 4: "lut"}
WIDTHS = [8, 16, 32, 64]
TAG_RE = re.compile(r"^impl(\d)_w(\d+)$")


def load_summaries(run_dir: Path) -> dict[int, dict[int, dict[str, float]]]:
    """data[impl][width] = {area, arrival, dyn_power_uW}"""
    data: dict[int, dict[int, dict[str, float]]] = {}
    for f in sorted(run_dir.glob("*_summary.txt")):
        m = TAG_RE.match(f.name.removesuffix("_summary.txt"))
        if not m:
            continue
        impl, w = int(m.group(1)), int(m.group(2))
        fields: dict[str, float] = {}
        for ln in f.read_text(encoding="utf-8").splitlines():
            if "=" in ln:
                k, _, v = ln.partition("=")
                try:
                    fields[k.strip()] = float(v)
                except ValueError:
                    pass
        data.setdefault(impl, {})[w] = {
            "area": fields.get("area", float("nan")),
            "arrival": fields.get("arrival", float("nan")),
            "dyn_power_uW": fields.get("dyn_power_uW", float("nan")),
        }
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
        print(f"ERROR: no *_summary.txt parsed under {run_dir}", file=sys.stderr)
        return 10

    fig, axes = plt.subplots(1, 3, figsize=(16, 4.6))
    metrics = [
        ("area", "Total cell area (um^2)"),
        ("arrival", "Data arrival time (ns)"),
        ("dyn_power_uW", "Dynamic power (uW)"),
    ]
    for ax, (key, ylabel) in zip(axes, metrics):
        for impl in sorted(data):
            xs = [w for w in WIDTHS if w in data.get(impl, {})]
            ys = [data[impl][w][key] for w in xs]
            ax.plot(xs, ys, marker="o", label=IMPL_NAMES.get(impl, f"impl{impl}"))
        ax.set_xlabel("DATA_W (bit)")
        ax.set_ylabel(ylabel)
        ax.set_xticks(WIDTHS)
        ax.grid(True, alpha=0.3)
        ax.legend(fontsize=8)
    fig.suptitle(
        "popcount PPA sweep — 5 impls x W{{8,16,32,64}} "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz, 0.5ns port delay)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")
    for impl in sorted(data):
        for w in sorted(data[impl]):
            d = data[impl][w]
            print(
                f"impl{impl}({IMPL_NAMES[impl]:>7}) W{w:>2}: "
                f"area={d['area']:.2f} arrival={d['arrival']:.2f} "
                f"dyn={d['dyn_power_uW']:.2f}uW"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
