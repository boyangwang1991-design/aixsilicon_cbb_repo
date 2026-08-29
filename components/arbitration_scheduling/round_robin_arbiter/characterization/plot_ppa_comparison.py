#!/usr/bin/env python3
"""PPA 对比绘图 — round_robin_arbiter 多实现（面积 / 组合 arrival / 动态功耗 × NUM_REQ）。

数据源：build/eda/ppa/<run-id>/*_summary.txt（含 area/arrival/slack/dyn_power_uW；
        缺失 dyn_power_uW 时回退解析同目录 *_power.rpt 的 Total Dynamic Power）。
输出：reports/ppa_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 根目录执行，matplotlib 经 uv 临时环境提供，不污染 .venv）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dir build/eda/ppa/run-20260829-01 --out reports/ppa_run-20260829-01.png

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

IMPL_NAMES = {0: "mask", 1: "rotate_prio", 2: "pointer"}
N_REQ = [4, 8, 16, 32, 64]
TAG_RE = re.compile(r"^impl(\d)_n(\d+)$")


def _power_from_rpt(run_dir: Path, tag: str) -> float | None:
    """回退：从 <tag>_power.rpt 提取 Total Dynamic Power (uW)。"""
    prt = run_dir / f"{tag}_power.rpt"
    if not prt.exists():
        return None
    for ln in prt.read_text(encoding="utf-8").splitlines():
        m = re.search(r"Total Dynamic Power\s+=\s+([0-9.]+)\s+uW", ln)
        if m:
            return float(m.group(1))
    return None


def load_summaries(run_dir: Path) -> dict[int, dict[int, dict[str, float]]]:
    """data[impl][n] = {area, arrival, slack, dyn_power_uW}"""
    data: dict[int, dict[int, dict[str, float]]] = {}
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
        tag = f"impl{impl}_n{n}"
        if "dyn_power_uW" not in fields:
            p = _power_from_rpt(run_dir, tag)
            if p is not None:
                fields["dyn_power_uW"] = p
        data.setdefault(impl, {})[n] = {
            "area": fields.get("area", float("nan")),
            "arrival": fields.get("arrival", float("nan")),
            "slack": fields.get("slack", float("nan")),
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
    styles = {0: "o-", 1: "s-", 2: "d-."}
    colors = {0: "tab:blue", 1: "tab:orange", 2: "tab:green"}
    for ax, (key, ylabel) in zip(axes, metrics):
        for impl in sorted(data):
            xs = [n for n in N_REQ if n in data.get(impl, {})]
            ys = [data[impl][n][key] for n in xs]
            ax.plot(xs, ys, styles.get(impl, "o-"), color=colors.get(impl, "tab:gray"),
                    label=IMPL_NAMES.get(impl, f"impl{impl}"))
        ax.set_xlabel("NUM_REQ")
        ax.set_ylabel(ylabel)
        ax.set_xticks(N_REQ)
        ax.grid(True, alpha=0.3)
        ax.legend(fontsize=8)
    fig.suptitle(
        "round_robin_arbiter PPA sweep — mask vs rotate_prio vs pointer "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz, comb. arrival)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")

    print(f"{'impl':>12} {'N':>3} {'area':>10} {'arrival':>8} {'slack':>7} {'dyn_uW':>9}")
    for impl in sorted(data):
        for n in sorted(data[impl]):
            d = data[impl][n]
            print(
                f"{IMPL_NAMES.get(impl, f'impl{impl}'):>12} {n:>3} {d['area']:>10.2f} "
                f"{d['arrival']:>8.2f} {d['slack']:>7.2f} {d['dyn_power_uW']:>9.2f}"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
