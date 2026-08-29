#!/usr/bin/env python3
"""PPA 对比绘图 — incrementer_decrementer 两实现（ripple / segmented）× DATA_W × SEG_W。

数据源：build/eda/ppa/<run-id>/*_summary.txt（含 tag/area/arrival/slack/dyn_power_uW）。
tag 约定：impl<k>_w<W>_seg<S>（k=0 ripple, 1 segmented；ripple 忽略 SEG_W，取 seg4 表示）。
输出：reports/ppa_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 根目录执行，matplotlib 经 uv 临时环境提供，不污染 .venv）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dirs run-20260829-01 --out reports/ppa_run-20260829-01.png

按 SKILL 纪律：多实现/多配置 Sweep 后必须出对比图（禁 ASCII 图、禁只贴文本）；
功耗是 PPA 一级属性，与面积/时序同图呈现。
"""

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # 无显示环境出图
import matplotlib.pyplot as plt  # noqa: E402

IMPL_NAMES = {0: "ripple", 1: "segmented"}
WIDTHS = [8, 16, 32, 64]
TAG_RE = re.compile(r"^impl(\d)_w(\d+)_seg(\d+)$")


def load_summaries(run_dirs: list[Path]) -> dict[tuple[int, int], dict[str, float]]:
    """data[(impl, w)] = {area, arrival, slack, dyn_power_uW}

    ripple（impl=0）忽略 SEG_W（seg4/seg8 数据相同），取 seg4 代表；
    segmented（impl=1）取 seg4（时序最优）与 seg8（面积优化）中较优者。
    """
    raw: dict[tuple[int, int, int], dict[str, float]] = {}
    for run_dir in run_dirs:
        for f in sorted(run_dir.glob("*_summary.txt")):
            m = TAG_RE.match(f.name.removesuffix("_summary.txt"))
            if not m:
                continue
            impl, w, seg = int(m.group(1)), int(m.group(2)), int(m.group(3))
            fields: dict[str, float] = {}
            for ln in f.read_text(encoding="utf-8").splitlines():
                if "=" in ln:
                    k, _, v = ln.partition("=")
                    try:
                        fields[k.strip()] = float(v)
                    except ValueError:
                        pass
            raw[(impl, w, seg)] = {
                "area": fields.get("area", float("nan")),
                "arrival": fields.get("arrival", float("nan")),
                "slack": fields.get("slack", float("nan")),
                "dyn_power_uW": fields.get("dyn_power_uW", float("nan")),
            }

    # 聚合到 (impl, w)：segmented 取 seg4/seg8 中 area 较小的；ripple 取 seg4
    data: dict[tuple[int, int], dict[str, float]] = {}
    for (impl, w, seg), d in raw.items():
        if impl == 0 and seg != 4:
            continue
        key = (impl, w)
        if key not in data:
            data[key] = d
        else:
            # segmented 保留面积更小的配置（seg4 vs seg8）
            if impl == 1 and d["area"] < data[key]["area"]:
                data[key] = d
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dirs", required=True, type=str,
                    help="comma-separated run dir names relative to build/eda/ppa")
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()
    cbb = Path.cwd()
    run_dirs = [cbb / "build/eda/ppa" / r.strip() for r in args.run_dirs.split(",")]
    out = args.out.resolve() if args.out.is_absolute() else (cbb / args.out).resolve()
    missing = [str(r) for r in run_dirs if not r.is_dir()]
    if missing:
        print(f"ERROR: run dirs not found: {missing}", file=sys.stderr)
        return 10

    data = load_summaries(run_dirs)
    if not data:
        print("ERROR: no *_summary.txt parsed", file=sys.stderr)
        return 10

    fig, axes = plt.subplots(1, 3, figsize=(16, 5))
    metrics = [
        ("area", "Total cell area (um^2)"),
        ("arrival", "Data arrival time (ns)"),
        ("dyn_power_uW", "Dynamic power (uW)"),
    ]
    styles = {0: "o-", 1: "s-"}
    colors = {0: "tab:blue", 1: "tab:orange"}
    for ci, (key, ylabel) in enumerate(metrics):
        ax = axes[ci]
        for impl in [0, 1]:
            xs = [w for w in WIDTHS if (impl, w) in data]
            ys = [data[(impl, w)][key] for w in xs]
            ax.plot(xs, ys, styles[impl], color=colors[impl], label=IMPL_NAMES[impl])
        ax.set_xlabel("DATA_W")
        ax.set_ylabel(ylabel)
        ax.set_xticks(WIDTHS)
        ax.grid(True, alpha=0.3)
        ax.legend(fontsize=9)
    fig.suptitle(
        "incrementer_decrementer PPA sweep — ripple vs segmented "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")

    print(f"{'impl':>10} {'W':>4} {'area':>10} {'arrival':>8} {'slack':>7} {'dyn_uW':>9}")
    for (impl, w) in sorted(data):
        d = data[(impl, w)]
        print(f"{IMPL_NAMES[impl]:>10} {w:>4} {d['area']:>10.2f} "
              f"{d['arrival']:>8.3f} {d['slack']:>7.3f} {d['dyn_power_uW']:>9.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
