#!/usr/bin/env python3
# ============================================================================
# plot_pareto.py — parity_gen_check PPA Sweep 对比图（树/线双实现）
# 读 build/eda/ppa/<runid>/*_summary.txt → 面积/宽度 + slack/宽度 曲线
# 用法: uv run --with matplotlib python characterization/plot_pareto.py <runid>
# 产物: reports/ppa-<runid>.png（报告目录，供 ppa-report.md 引用）
# ============================================================================
import re
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: plot_pareto.py <runid>"); return 20
    runid = sys.argv[1]
    root = Path(__file__).resolve().parent.parent
    ppa = root / "build" / "eda" / "ppa" / runid
    if not ppa.is_dir():
        print("[err] ppa dir missing:", ppa); return 10

    impls = ["tree", "linear"]
    data = {i: {"w": [], "area": [], "arrival": [], "slack": []} for i in impls}
    for f in ppa.glob("*_summary.txt"):
        m = re.match(r"(tree|linear)_w(\d+)", f.stem)
        if not m:
            continue
        impl, w = m.group(1), int(m.group(2))
        for line in f.read_text(encoding="utf-8").splitlines():
            if line.startswith("area="):
                data[impl]["area"].append((w, float(line[5:])))
            elif line.startswith("arrival="):
                data[impl]["arrival"].append((w, float(line[8:])))
            elif line.startswith("slack="):
                data[impl]["slack"].append((w, float(line[6:])))
    for i in impls:
        data[i]["area"].sort()
        data[i]["arrival"].sort()
        data[i]["slack"].sort()

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4))
    for i in impls:
        w = [x[0] for x in data[i]["area"]]
        a = [x[1] for x in data[i]["area"]]
        ax1.plot(w, a, marker="o", label=i)
    ax1.set_xscale("log", base=2)
    ax1.set_xticks([8, 16, 32, 64, 128, 256])
    ax1.set_xlabel("DATA_WIDTH (log2)")
    ax1.set_ylabel("Total cell area (μm²)")
    ax1.set_title(f"parity_gen_check area — {runid}")
    ax1.legend(); ax1.grid(True, alpha=0.3)

    # 时序主指标 = data arrival time（纯组合：输入→输出传播延迟，独立于虚拟时钟）
    for i in impls:
        w = [x[0] for x in data[i]["arrival"]]
        s = [x[1] for x in data[i]["arrival"]]
        ax2.plot(w, s, marker="s", label=i)
    ax2.set_xscale("log", base=2)
    ax2.set_xticks([8, 16, 32, 64, 128, 256])
    ax2.set_xlabel("DATA_WIDTH (log2)")
    ax2.set_ylabel("Data arrival time (ns)")
    ax2.set_title(f"parity_gen_check timing (arrival) — {runid}")
    ax2.legend(); ax2.grid(True, alpha=0.3)

    fig.tight_layout()
    outdir = root / "reports"
    outdir.mkdir(exist_ok=True)
    out = outdir / (f"ppa-{runid}.png")
    fig.savefig(out, dpi=140)
    plt.close(fig)
    print("[plot]", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
