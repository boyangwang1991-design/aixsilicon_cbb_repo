#!/usr/bin/env python3
"""plot_ppa_comparison.py — parallel_data_fetch PPA 对比图（面积 / 时序 slack / 漏电）。

数据源：build/eda/ppa/<run-id>/*_summary.txt（synth_sweep.tcl 产出）。
顺序：与 characterization/plan.yaml 的 points 声明顺序一致（逻辑顺序，非字典序）。
输出：<out>.png（150dpi，面积 / slack / 漏电三个子图）。

用法（从 CBB 根目录）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dir build/eda/ppa/<RUNID> --out reports/ppa_<RUNID>.png

说明：本构件核心价值是**长距布线资源**而非逻辑门面积；本图只呈现逻辑级 PPA，
      物理收益需与「同宽并行总线」做布局对比（见 docs/design.md §6 与 plan.yaml planned）。
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

# 与 characterization/plan.yaml 的 points 顺序一致（逻辑顺序）
ORDER_LABELS = [
    ("dw256_lw32_slice2", "256/32 banked (def)"),
    ("dw256_lw32_slice0", "256/32 shift"),
    ("dw256_lw32_slice1", "256/32 indexed"),
    ("dw256_lw32_pipe1", "256/32 pipe=1"),
    ("dw256_lw32_pipe8", "256/32 pipe=8"),
    ("dw512_lw64_slice2", "512/64 banked"),
    ("dw1024_lw128_slice2", "1024/128 banked"),
    ("dw64_lw32_slice2", "64/32 banked"),
    ("dw256_lw32_async_fifo8", "256/32 async FIFO=8"),
    ("dw256_lw32_async", "256/32 async FIFO=16"),
]


def load_summaries(run_dir: Path) -> dict[str, dict[str, str]]:
    data: dict[str, dict[str, str]] = {}
    for f in run_dir.glob("*_summary.txt"):
        tag = f.name.removesuffix("_summary.txt").removeprefix("pdf_")
        kv: dict[str, str] = {}
        for line in f.read_text(errors="ignore").splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                kv[k.strip()] = v.strip()
        data[tag] = kv
    return data


def ordered_tags(data: dict[str, dict[str, str]]) -> list[tuple[str, str]]:
    """按 ORDER_LABELS 的声明顺序返回 (tag, label)；未声明的 tag 追加到末尾。"""
    out: list[tuple[str, str]] = []
    used: set[str] = set()
    for key, label in ORDER_LABELS:
        for tag in data:
            if tag == key and tag not in used:
                out.append((tag, label))
                used.add(tag)
    for tag in data:
        if tag not in used:
            out.append((tag, tag))
    return out


def fnum(v: str | None) -> float | None:
    if v is None:
        return None
    m = re.search(r"-?[0-9.]+(?:[eE][+-]?\d+)?", v)
    return float(m.group(0)) if m else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dir", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    data = load_summaries(args.run_dir)
    if not data:
        print(f"no *_summary.txt under {args.run_dir}", file=sys.stderr)
        return 10

    tags = ordered_tags(data)
    labels = [lab for _, lab in tags]
    x = range(len(tags))

    def series(field: str) -> list[float]:
        return [fnum(data[t].get(field)) or 0.0 for t, _ in tags]

    area = series("area")
    slack = series("slack")
    leak = series("leak_power_nW")

    fig, axes = plt.subplots(3, 1, figsize=(12, 13))

    axes[0].bar(x, area, color="#4C78A8")
    axes[0].set_ylabel("Total cell area (um^2)")
    axes[0].set_title("parallel_data_fetch — logic area by configuration (GF 28nm LP sc9_base_hvt tt)")
    axes[0].grid(axis="y", alpha=0.3)

    axes[1].bar(x, slack, color="#F58518")
    axes[1].axhline(0.0, color="red", linewidth=1, linestyle="--")
    axes[1].set_ylabel("Worst setup slack (ns) @2.5ns")
    axes[1].set_title("Timing slack (>=0 MET; 2.5ns = 400MHz; async shows per-domain worst)")
    axes[1].grid(axis="y", alpha=0.3)

    axes[2].bar(x, leak, color="#54A24B")
    axes[2].set_ylabel("Cell leakage power (nW)")
    axes[2].set_title("Leakage (dynamic power omitted here: activity is a synthesis estimate, no SAIF)")
    axes[2].grid(axis="y", alpha=0.3)

    for ax in axes:
        ax.set_xticks(list(x))
        ax.set_xticklabels(labels, rotation=30, ha="right", fontsize=8)

    plt.tight_layout()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(args.out, dpi=150)
    print(f"wrote {args.out} ({len(tags)} points)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())