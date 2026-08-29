#!/usr/bin/env python3
"""CG 功耗/面积对比绘图 — incrementer_decrementer（CG_EN=0 vs 1，ACTIVE/HOLD 场景）。

数据源：build/eda/ppa/<run-id>/cg_*.txt（tag 含 impl/cg/scene；
        dyn_power_uW/leak_power_nW/area）。
输出：reports/ppa_cg_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 根目录执行，matplotlib 经 uv 临时环境提供）：
  uv run --with matplotlib python characterization/plot_cg_power.py \
      --run-dirs run-20260829-03 --out reports/ppa_cg_run-20260829-03.png
"""

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

IMPL_NAMES = {0: "ripple", 1: "segmented"}
SCENES = ["ACTIVE", "HOLD"]
TAG_RE = re.compile(r"^cg_impl(\d)_w\d+_cg(\d)_(ACTIVE|HOLD)$")


def load(run_dirs: list[Path]) -> dict[tuple[int, int, str], dict[str, float]]:
    data: dict[tuple[int, int, str], dict[str, float]] = {}
    for run_dir in run_dirs:
        for f in sorted(run_dir.glob("cg_*_summary.txt")):
            m = TAG_RE.match(f.name.removesuffix("_summary.txt"))
            if not m:
                continue
            impl, cg, scene = int(m.group(1)), int(m.group(2)), m.group(3)
            fields: dict[str, float] = {}
            for ln in f.read_text(encoding="utf-8").splitlines():
                if "=" in ln:
                    k, _, v = ln.partition("=")
                    try:
                        fields[k.strip()] = float(v)
                    except ValueError:
                        pass
            data[(impl, cg, scene)] = {
                "area": fields.get("area", float("nan")),
                "dyn_power_uW": fields.get("dyn_power_uW", float("nan")),
                "leak_power_nW": fields.get("leak_power_nW", float("nan")),
                "total_power_uW": fields.get("total_power_uW", float("nan")),
            }
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dirs", required=True, type=str)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()
    cbb = Path.cwd()
    run_dirs = [cbb / "build/eda/ppa" / r.strip() for r in args.run_dirs.split(",")]
    out = args.out.resolve() if args.out.is_absolute() else (cbb / args.out).resolve()
    missing = [str(r) for r in run_dirs if not r.is_dir()]
    if missing:
        print(f"ERROR: run dirs not found: {missing}", file=sys.stderr)
        return 10

    data = load(run_dirs)
    if not data:
        print("ERROR: no cg_*_summary.txt parsed", file=sys.stderr)
        return 10

    # 2 行（ripple/segmented）× 3 列（area/dyn/leak），x 轴为 CG_EN，ACTIVE/HOLD 双线
    fig, axes = plt.subplots(2, 3, figsize=(16, 8))
    metrics = [
        ("area", "Total cell area (um^2)"),
        ("dyn_power_uW", "Dynamic power (uW)"),
        ("leak_power_nW", "Leakage power (nW)"),
    ]
    colors = {"ACTIVE": "tab:red", "HOLD": "tab:blue"}
    for ri, impl in enumerate([0, 1]):
        for ci, (key, ylabel) in enumerate(metrics):
            ax = axes[ri][ci]
            for scene in SCENES:
                xs = [cg for cg in [0, 1] if (impl, cg, scene) in data]
                ys = [data[(impl, cg, scene)][key] for cg in xs]
                ax.plot(xs, ys, "o-", color=colors[scene], label=scene)
            ax.set_xlabel("CG_EN")
            ax.set_xticks([0, 1])
            ax.set_ylabel(ylabel)
            ax.grid(True, alpha=0.3)
            ax.legend(fontsize=9)
            ax.set_title(f"{IMPL_NAMES[impl]} (W=32)")
    fig.suptitle(
        "incrementer_decrementer CG area/power — CG_EN=0 vs 1, ACTIVE/HOLD "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")

    print(f"{'impl':>10} {'CG_EN':>5} {'scene':>7} {'area':>9} {'dyn_uW':>9} {'leak_nW':>9}")
    for (impl, cg, scene) in sorted(data):
        d = data[(impl, cg, scene)]
        print(f"{IMPL_NAMES[impl]:>10} {cg:>5} {scene:>7} {d['area']:>9.3f} "
              f"{d['dyn_power_uW']:>9.3f} {d['leak_power_nW']:>9.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
