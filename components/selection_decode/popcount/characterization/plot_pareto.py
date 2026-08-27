#!/usr/bin/env python3
# ============================================================================
# plot_pareto.py — G6 PPA Pareto 散点图生成（ppareport 配套，确定性可重放）
# 数据源：evidence/ppa/<run-id>/*_summary.txt（面积）+ *_power.rpt（可选标注）
# 输出：docs/assets/ppa_pareto_<run-id>.png（插入 ppa-report.md）
# 依赖：matplotlib（工作区 venv）；纯 stdlib 解析 + numpy-free
# ============================================================================
from __future__ import annotations

import re
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")                     # 无显示环境安全
import matplotlib.pyplot as plt           # noqa: E402


def parse_summaries(run_dir: Path) -> dict[tuple[str, int], tuple[float, float]]:
    """解析 *_summary.txt → {(impl, W): (area, slack)}"""
    out: dict[tuple[str, int], tuple[float, float]] = {}
    for f in sorted(run_dir.glob("*_summary.txt")):
        m = re.match(r"(tree|colcmp|lookup)_w(\d+)_summary", f.stem)
        if not m:
            continue
        impl, w = m.group(1), int(m.group(2))
        area = slack = None
        for line in f.read_text().splitlines():
            if line.startswith("area="):
                area = float(line.split("=")[1])
            elif line.startswith("slack="):
                slack = float(line.split("=")[1])
        if area is not None and slack is not None:
            out[(impl, w)] = (area, slack)
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: plot_pareto.py <run_id> <cbb_root>")
        return 20
    run_id, root = sys.argv[1], Path(sys.argv[2])
    run_dir = root / "evidence" / "ppa" / run_id
    data = parse_summaries(run_dir)
    if not data:
        print(f"[FAIL] no summaries parsed under {run_dir}")
        return 10

    fig, ax = plt.subplots(figsize=(8, 5.5))
    colors = {"tree": "#1f77b4", "lookup": "#2ca02c", "colcmp": "#d62728"}
    markers = {"tree": "o", "lookup": "^", "colcmp": "s"}
    impls = ("tree", "lookup", "colcmp")

    for impl in impls:
        xs = [a for (i, _), (a, _) in data.items() if i == impl]
        ys = [s for (i, _), (_, s) in data.items() if i == impl]
        ax.scatter(xs, ys, c=colors[impl], marker=markers[impl],
                   s=70, label=impl, zorder=3,
                   edgecolors="black", linewidths=0.5)
        # 点旁标宽度
        for (i, w), (a, s) in data.items():
            if i == impl:
                ax.annotate(f"W{w}", (a, s), textcoords="offset points",
                            xytext=(7, -4), fontsize=8, color=colors[i])

    # Pareto 前沿（tree 系列，按面积排序依次连线示意支配链）
    front = sorted(((a, s) for (i, _), (a, s) in data.items()
                    if i == "tree"), key=lambda t: t[0])
    ax.plot([p[0] for p in front], [p[1] for p in front],
            "--", color="#1f77b4", alpha=0.6, lw=1.2,
            label="Pareto chain (tree)", zorder=2)

    # 违例区着色
    ylim_min = min(s for _, s in data.values()) - 0.5
    ax.axhspan(ylim_min, 0.0, facecolor="#d62728", alpha=0.06, zorder=1)
    ax.text(20, ylim_min + 0.15, "timing VIOLATED region",
            fontsize=8, color="#d62728", style="italic")

    ax.set_xscale("log")
    ax.set_xlabel("Total cell area (um^2) — log scale")
    ax.set_ylabel("Worst slack @400MHz (ns)")
    ax.set_title(f"popcount PPA Pareto — {run_id}\n"
                 "(SC9 HVT, tt_1p00v_25c, virtual clock 2.5ns)")
    ax.grid(True, which="both", alpha=0.25)
    ax.legend(loc="lower left", fontsize=9)

    out_png = Path(root).resolve() / "characterization" / f"pareto_{run_id}.png"
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out_png, dpi=150)
    print(f"[OK] -> {out_png}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
