#!/usr/bin/env python3
"""PPA 对比绘图 — sync_fifo 多实现（面积 / reg→reg slack / 动态功耗 × DEPTH）。

数据源：build/eda/ppa/<run-id>/*_{area,timing_max,power,regs}.*（报告集）
        + characterization/extract_ppa.py 产物 ppa_summary.md（若存在则优先）。
输出：reports/ppa_<run-id>.png（300dpi）+ stdout 数据表。

用法（从 CBB 根目录执行，matplotlib 经 uv 临时环境提供，不污染 .venv）：
  uv run --with matplotlib python characterization/plot_ppa_comparison.py \
      --run-dir build/eda/ppa/run-20260903-01 --out reports/ppa_run-20260903-01.png

按 optimize-cbb-ppa 纪律：多实现 Sweep 后必须出对比图（禁 ASCII 图、禁只贴文本）；
功耗是 PPA 一级属性，与面积/时序同图呈现。
"""

import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # 无显示环境出图
import matplotlib.pyplot as plt  # noqa: E402

# tag → (实现名, 输出级)  例 sync_rc_d8 / sync_rr_d32 / sync_sc_d8 / sync_sr_d32
TAG_RE = re.compile(r"^sync_(rc|rr|sc|sr)_d(\d+)$")
MODE_NAMES = {
    "rc": "register × comb",
    "rr": "register × reg",
    "sc": "shift × comb",
    "sr": "shift × reg",
}
STYLES = {"rc": "o-", "rr": "s-", "sc": "^-", "sr": "D-."}
COLORS = {"rc": "tab:blue", "rr": "tab:orange", "sc": "tab:green", "sr": "tab:red"}


def _parse(report: Path, pattern: str) -> float | None:
    if not report.exists():
        return None
    for ln in report.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(pattern, ln)
        if m:
            return float(m.group(1))
    return None


def load_data(run_dir: Path) -> dict[str, dict[int, dict[str, float]]]:
    """data[mode][depth] = {area, slack_ns, dyn_uW}"""
    data: dict[str, dict[int, dict[str, float]]] = {}
    for f in sorted(run_dir.glob("*_area.rpt")):
        m = TAG_RE.match(f.name.removesuffix("_area.rpt"))
        if not m:
            continue
        mode, depth = m.group(1), int(m.group(2))
        tag = f.name.removesuffix("_area.rpt")
        area = _parse(f, r"Total cell area:\s+([0-9.]+)")
        slack = _parse(run_dir / f"{tag}_timing_max.rpt",
                       r"slack \((?:MET|VIOLATED)\)\s+(-?[0-9.]+)")
        dyn = _parse(run_dir / f"{tag}_power.rpt",
                     r"Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+(mW|uW)")
        if dyn is not None:
            # 从报告原文判断单位（读取匹配行的单位）
            _unit = None
            for ln in (run_dir / f"{tag}_power.rpt").read_text(encoding="utf-8",
                                                               errors="ignore").splitlines():
                mm = re.search(r"Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+(mW|uW)", ln)
                if mm:
                    _unit = mm.group(2)
                    break
            dyn = dyn * 1000.0 if _unit == "mW" else dyn
        data.setdefault(mode, {})[depth] = {
            "area": area if area is not None else float("nan"),
            "slack_ns": slack if slack is not None else float("nan"),
            "dyn_uW": dyn if dyn is not None else float("nan"),
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

    data = load_data(run_dir)
    if not data:
        print(f"ERROR: no *_area.rpt parsed under {run_dir}", file=sys.stderr)
        return 10

    depths = sorted({d for m in data.values() for d in m})
    fig, axes = plt.subplots(1, 3, figsize=(17, 4.8))
    metrics = [
        ("area", "Total cell area (um^2)"),
        ("slack_ns", "Worst reg->reg setup slack (ns)"),
        ("dyn_uW", "Total dynamic power (uW)"),
    ]
    for ax, (key, ylabel) in zip(axes, metrics):
        for mode in sorted(data):
            xs = [d for d in depths if d in data[mode]]
            ys = [data[mode][d][key] for d in xs]
            ax.plot(xs, ys, STYLES.get(mode, "o-"), color=COLORS.get(mode, "tab:gray"),
                    label=MODE_NAMES.get(mode, mode))
        ax.set_xlabel("DEPTH")
        ax.set_ylabel(ylabel)
        ax.set_xticks(depths)
        ax.grid(True, alpha=0.3)
        ax.legend(fontsize=8)
    fig.suptitle(
        "sync_fifo PPA sweep — register vs shift × comb vs reg output "
        "(sc9_cmos28lp_base_hvt tt 1.00V 25C, 400MHz, DATA_W=32)"
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=300)
    print(f"PNG written: {out}")

    print(f"{'mode':>18} {'depth':>5} {'area':>10} {'slack_ns':>8} {'dyn_uW':>9}")
    for mode in sorted(data):
        for d in sorted(data[mode]):
            v = data[mode][d]
            print(f"{MODE_NAMES.get(mode, mode):>18} {d:>5} {v['area']:>10.2f} "
                  f"{v['slack_ns']:>8.3f} {v['dyn_uW']:>9.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
