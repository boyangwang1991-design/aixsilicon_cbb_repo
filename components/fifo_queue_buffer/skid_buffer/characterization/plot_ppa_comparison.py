#!/usr/bin/env python3
"""PPA 对比绘图 — skid_buffer 多实现（面积 / worst_slack / 动态功耗 × DATA_W）。

数据源：build/eda/ppa/<run-id>/ 完整报告集（复用 characterization/extract_ppa.py 解析）。
输出：reports/ppa_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 根目录执行，matplotlib 经 uv 临时环境提供，不污染 .venv）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dir build/eda/ppa/run-20260829-01 --out reports/ppa_run-20260829-01.png

按 SKILL 纪律：多实现/多配置 Sweep 后必须出对比图（禁 ASCII 图、禁只贴文本）；
功耗是 PPA 一级属性，与面积/时序同图呈现。时序主判据 = reg→reg worst setup slack。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # 无显示环境出图
import matplotlib.pyplot as plt  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_ppa import (  # noqa: E402
    parse_area,
    parse_io_arrival,
    parse_power,
    parse_regs,
    parse_worst_setup_slack,
)

MODES = ("forward", "full", "bypass")
WIDTHS = [8, 32, 128]


def load_report(run_dir: Path, tag: str) -> dict[str, str]:
    """读取单配置报告集的抽取值。"""
    d: dict[str, str] = {}
    area = run_dir / f"{tag}_area.rpt"
    if area.exists():
        d["area"] = parse_area(area)
    tmax = run_dir / f"{tag}_timing_max.rpt"
    if tmax.exists():
        worst, status = parse_worst_setup_slack(tmax)
        d["worst_slack"], d["slack_status"] = worst, status
    io = run_dir / f"{tag}_io.rpt"
    if io.exists():
        d["arrival"] = parse_io_arrival(io)
    pwr = run_dir / f"{tag}_power.rpt"
    if pwr.exists():
        dyn, leak = parse_power(pwr)
        d["dyn_uW"], d["leak_nW"] = dyn, leak
    regs = run_dir / f"{tag}_regs.txt"
    if regs.exists():
        d["regs"] = parse_regs(regs)
    return d


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dir", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()
    run_dir, out = args.run_dir.resolve(), args.out.resolve()
    if not run_dir.is_dir():
        print(f"ERROR: run dir not found: {run_dir}", file=sys.stderr)
        return 10

    # data[mode][width] = {area, worst_slack, dyn_uW, arrival, regs}
    data: dict[str, dict[int, dict[str, str]]] = {m: {} for m in MODES}
    for rpt in sorted(run_dir.glob("skid_*_area.rpt")):
        tag = rpt.name.removesuffix("_area.rpt")
        mw = re.match(r"skid_w(\d+)_i(\d)", tag)
        mbyp = re.match(r"skid_byp_w(\d+)", tag)
        if mw:
            mode = "forward" if mw.group(2) == "0" else "full"
            data[mode][int(mw.group(1))] = load_report(run_dir, tag)
        elif mbyp:
            data["bypass"][int(mbyp.group(1))] = load_report(run_dir, tag)
    if not any(data[m] for m in MODES):
        print(f"ERROR: no skid_* reports parsed under {run_dir}", file=sys.stderr)
        return 10

    fig, axes = plt.subplots(1, 3, figsize=(16, 4.6))
    style = {"forward": "o-", "full": "s-", "bypass": "^--"}
    color = {"forward": "tab:blue", "full": "tab:orange", "bypass": "tab:green"}

    # 1) 面积 vs DATA_W
    ax = axes[0]
    for mode in MODES:
        xs = [w for w in WIDTHS if w in data[mode]]
        ys = []
        for w in xs:
            try:
                ys.append(float(data[mode][w].get("area", "nan")))
            except ValueError:
                ys.append(float("nan"))
        if xs:
            ax.plot(xs, ys, style[mode], color=color[mode], label=mode)
    ax.set_xlabel("DATA_W (bit)")
    ax.set_ylabel("Total cell area (um^2)")
    ax.set_xticks(WIDTHS)
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=8)
    ax.set_title("Area")

    # 2) 时序主判据：reg→reg worst setup slack vs DATA_W（越高越好；bypass 组合 arrival 标注）
    ax = axes[1]
    for mode in ("forward", "full"):
        xs = [w for w in WIDTHS if w in data[mode]]
        ys = []
        for w in xs:
            try:
                ys.append(float(data[mode][w].get("worst_slack", "nan")))
            except ValueError:
                ys.append(float("nan"))
        if xs:
            ax.plot(xs, ys, style[mode], color=color[mode], label=f"{mode} (slack)")
    for w, d in data["bypass"].items():
        try:
            arr = float(d.get("arrival", "nan"))
            ax.scatter([w], [arr], marker="^", color=color["bypass"], zorder=5,
                       label="bypass (comb. arrival)" if w == WIDTHS[0] else None)
        except ValueError:
            pass
    ax.set_xlabel("DATA_W (bit)")
    ax.set_ylabel("worst setup slack (ns)  [bypass: arrival]")
    ax.set_xticks(WIDTHS)
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=8)
    ax.set_title("Timing (reg-to-reg worst slack)")

    # 3) 动态功耗 vs DATA_W
    ax = axes[2]
    for mode in MODES:
        xs = [w for w in WIDTHS if w in data[mode]]
        ys = []
        for w in xs:
            try:
                ys.append(float(data[mode][w].get("dyn_uW", "nan")))
            except ValueError:
                ys.append(float("nan"))
        if xs:
            ax.plot(xs, ys, style[mode], color=color[mode], label=mode)
    ax.set_xlabel("DATA_W (bit)")
    ax.set_ylabel("Dynamic power (uW)")
    ax.set_xticks(WIDTHS)
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=8)
    ax.set_title("Dynamic power")

    fig.suptitle(
        "skid_buffer PPA — forward vs full vs bypass "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz, reg-to-reg worst slack)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")

    print(f"{'mode':>8} {'W':>4} {'area':>10} {'slack':>7} {'arrival':>8} {'regs':>5} {'dyn_uW':>9} {'leak_nW':>9}")
    for mode in MODES:
        for w in sorted(data[mode]):
            d = data[mode][w]
            print(
                f"{mode:>8} {w:>4} {d.get('area','-'):>10} {d.get('worst_slack','-'):>7} "
                f"{d.get('arrival','-'):>8} {d.get('regs','-'):>5} "
                f"{d.get('dyn_uW','-'):>9} {d.get('leak_nW','-'):>9}"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
