#!/usr/bin/env python3
"""PPA 对比绘图 — weighted_rr_arbiter 双实现（quota_counter / deficit_rotate）× WMODE × NUM_REQ。

数据源：build/eda/ppa/<run-id>/*_summary.txt（含 tag/area/arrival/slack/dyn_power_uW）。
tag 约定：
  impl<k>_n<N>      → WMODE=0（quota，run-…-01）
  sm_impl<k>_n<N>   → WMODE=1（smooth，run-…-02）
输出：reports/ppa_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 根目录执行，matplotlib 经 uv 临时环境提供，不污染 .venv）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dirs run-20260829-01:run-20260829-02 --out reports/ppa_run-20260829-01.png

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

IMPL_NAMES = {0: "quota_counter", 1: "deficit_rotate"}
N_REQ = [4, 8, 16]
TAG_RE = re.compile(r"^(?:sm_)?impl(\d)_n(\d+)$")


def load_summaries(run_dirs: list[Path]) -> dict[tuple[int, int, int], dict[str, float]]:
    """data[(wmode, impl, n)] = {area, arrival, slack, dyn_power_uW}"""
    data: dict[tuple[int, int, int], dict[str, float]] = {}
    for run_dir in run_dirs:
        # wmode 由 run-id 后缀判定：-01=quota(WMODE=0)，-02=smooth(WMODE=1)
        # （勿用子串 in 判断：run-20260829-01 含 "02" 会误判）
        wmode = 1 if run_dir.name.endswith("-02") else 0
        for f in sorted(run_dir.glob("*_summary.txt")):
            m = TAG_RE.match(f.name.removesuffix("_summary.txt"))
            if not m:
                continue
            impl, n = int(m.group(1)), int(m.group(2))
            fields: dict[str, float] = {}
            for ln in f.read_text(encoding="utf-8").splitlines():
                if "=" in ln:
                    k, _, v = ln.partition("=")
                    try:
                        fields[k.strip()] = float(v)
                    except ValueError:
                        pass
            data[(wmode, impl, n)] = {
                "area": fields.get("area", float("nan")),
                "arrival": fields.get("arrival", float("nan")),
                "slack": fields.get("slack", float("nan")),
                "dyn_power_uW": fields.get("dyn_power_uW", float("nan")),
            }
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

    # 2 行（quota / smooth）x 3 列（area / arrival / power）
    fig, axes = plt.subplots(2, 3, figsize=(16, 8))
    metrics = [
        ("area", "Total cell area (um^2)"),
        ("arrival", "Data arrival time (ns)"),
        ("dyn_power_uW", "Dynamic power (uW)"),
    ]
    styles = {0: "o-", 1: "s-"}
    colors = {0: "tab:blue", 1: "tab:orange"}
    for ri, wmode in enumerate([0, 1]):
        for ci, (key, ylabel) in enumerate(metrics):
            ax = axes[ri][ci]
            for impl in [0, 1]:
                xs = [n for n in N_REQ if (wmode, impl, n) in data]
                ys = [data[(wmode, impl, n)][key] for n in xs]
                ax.plot(xs, ys, styles[impl], color=colors[impl],
                        label=IMPL_NAMES[impl])
            ax.set_xlabel("NUM_REQ")
            ax.set_ylabel(ylabel)
            ax.set_xticks(N_REQ)
            ax.grid(True, alpha=0.3)
            ax.legend(fontsize=8)
            ax.set_title(f"{'WMODE=0 quota' if wmode == 0 else 'WMODE=1 smooth'}")
    fig.suptitle(
        "weighted_rr_arbiter PPA sweep — quota_counter vs deficit_rotate "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")

    print(f"{'WMODE':>6} {'impl':>14} {'N':>3} {'area':>10} {'arrival':>8} {'slack':>7} {'dyn_uW':>9}")
    for (wmode, impl, n) in sorted(data):
        d = data[(wmode, impl, n)]
        print(f"{wmode:>6} {IMPL_NAMES[impl]:>14} {n:>3} {d['area']:>10.2f} "
              f"{d['arrival']:>8.3f} {d['slack']:>7.3f} {d['dyn_power_uW']:>9.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
