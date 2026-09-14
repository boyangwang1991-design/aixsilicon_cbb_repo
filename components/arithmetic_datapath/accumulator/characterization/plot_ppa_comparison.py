#!/usr/bin/env python3
"""plot_ppa_comparison.py — accumulator PPA 对比图（面积 / 动态功耗 / 漏电）。

数据源：build/eda/ppa/<run-id>/*_summary.txt（synth_sweep.tcl 产出）。
顺序：与 characterization/plan.yaml 的 points 声明顺序一致（逻辑递增，非字典序），
      标签为可读短名（如 "16/32 ADD"）。
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

# 与 characterization/plan.yaml points 一致的顺序（逻辑递增）：
# 每个 (tag 正则片段 -> 可读标签)。tag 为 synth_sweep 生成的 acc_<tag>_summary.txt。
ORDER_LABELS = [
    ("iw8_aw16_sgn1_op0_ovf0_ld1_st1_iso0", "8/16 ADD"),
    ("iw16_aw32_sgn1_op0_ovf0_ld1_st1_iso0", "16/32 ADD (def)"),
    ("iw16_aw32_sgn1_op2_ovf0_ld1_st1_iso0", "16/32 ADDSUB"),
    ("iw16_aw32_sgn1_op2_ovf1_ld1_st1_iso0", "16/32 ADDSUB SAT"),
    ("iw16_aw32_sgn0_op0_ovf0_ld1_st1_iso0", "16/32 UNS ADD"),
    ("iw16_aw64_sgn1_op0_ovf0_ld1_st1_iso0", "16/64 ADD"),
    ("iw32_aw64_sgn1_op0_ovf0_ld1_st1_iso0", "32/64 ADD"),
    ("iw32_aw32_sgn1_op2_ovf1_ld1_st1_iso0", "32/32 ADDSUB SAT"),
    ("iw16_aw32_sgn1_op0_ovf0_ld0_st1_iso0", "16/32 noLOAD"),
    ("iw16_aw32_sgn1_op0_ovf0_ld1_st0_iso0", "16/32 noSTATUS"),
    ("iw16_aw32_sgn1_op2_ovf0_ld1_st1_iso1", "16/32 ADDSUB ISO"),
    ("iw16_aw128_sgn1_op0_ovf0_ld1_st1_iso0", "16/128 ADD"),
]


def load_summaries(run_dir: Path) -> dict[str, dict[str, str]]:
    data: dict[str, dict[str, str]] = {}
    for f in run_dir.glob("*_summary.txt"):
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

    # 按声明顺序取（缺失的点跳过，保持顺序稳定）
    tags, labels = [], []
    for fragment, label in ORDER_LABELS:
        tag = next((t for t in data if fragment in t), None)
        if tag is not None:
            tags.append(tag)
            labels.append(label)
    if not tags:
        print("ERROR: no declared points found in run dir", file=sys.stderr)
        return 10

    def col(key: str) -> list[float]:
        vals = []
        for t in tags:
            try:
                vals.append(float(data[t].get(key, "nan")))
            except (TypeError, ValueError):
                vals.append(float("nan"))
        return vals

    area, dyn, leak = col("area"), col("dyn_power_uW"), col("leak_power_nW")

    fig, axes = plt.subplots(3, 1, figsize=(13, 10))
    x = range(len(tags))
    axes[0].bar(x, area, color="#1f77b4")
    axes[0].set_ylabel("Area (um^2)")
    axes[0].set_title("accumulator PPA (dc_shell, CMOS28NM tt 1p00v 25c, 400MHz)")
    axes[1].bar(x, dyn, color="#2ca02c")
    axes[1].set_ylabel("Dynamic Power (uW)")
    axes[2].bar(x, leak, color="#d62728")
    axes[2].set_ylabel("Leakage (nW)")
    for ax in axes:
        ax.set_xticks(x)
        ax.set_xticklabels(labels, rotation=30, ha="right", fontsize=8)
        ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    print(f"wrote {out} ({len(tags)} points, order: {labels})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
