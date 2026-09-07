#!/usr/bin/env python3
"""extract_ppa.py — 从 DC 完整 PPA 报告集抽取关键指标（模板，2026-08-29 复盘固化）。

用法（从 CBB 根目录）:
    uv run python characterization/extract_ppa.py <cbb_root> <run_id>

输入: build/eda/ppa/<run_id>/<tag>_{area,timing_max,io,power,clock,regs}*
输出: build/eda/ppa/<run_id>/ppa_summary.md

时序判据（按模块类型，optimize-cbb-ppa step 5）:
- 时序模块（含寄存器）→ **reg→reg 最差 setup slack** 主判据（timing_max.rpt 中
  `slack (MET|VIOLATED)` 最小值）；组合输出 arrival 仅作 IO 参考；
- 纯组合模块 → 以**组合 arrival**（io.rpt）为时序结论；
- 违规只看 vclk slack 的 VIOLATED（report_constraint 的 leakage power slack 非时序）。

按 CBB 定制点：tag 的 mode 标签解析（默认用 tag 名；多实现时按实际命名扩展）。
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------- 解析函数


def parse_area(rpt: Path) -> str:
    for ln in rpt.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(r"Total cell area:\s+([0-9.]+)", ln)
        if m:
            return m.group(1)
    return "n/a"


def parse_regs(txt: Path) -> str:
    t = txt.read_text(encoding="utf-8", errors="ignore").strip()
    return t if re.fullmatch(r"\d+", t) else "n/a"


def parse_worst_setup_slack(tmax: Path) -> tuple[str, str]:
    """reg→reg 最差 setup slack 与状态（timing_max，vclk group）。"""
    worst: float | None = None
    status = "none"
    for ln in tmax.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(r"slack \((MET|VIOLATED)\)\s+(-?[0-9.]+)", ln)
        if m:
            st, s = m.group(1), float(m.group(2))
            if st == "VIOLATED":
                status = "VIOLATED"
            elif status == "none":
                status = "MET"
            if worst is None or s < worst:
                worst = s
    if worst is None:
        return "n/a", "n/a"
    return f"{worst:.4f}", status


def parse_io_arrival(io: Path) -> str:
    """组合输出最差 arrival，作 IO 参考 / 纯组合主指标。"""
    best: float | None = None
    for ln in io.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(r"data arrival time\s+([0-9.]+)", ln)
        if m:
            v = float(m.group(1))
            if best is None or v > best:
                best = v
    return f"{best:.4f}" if best is not None else "n/a"


def parse_power(pwr: Path) -> tuple[str, str]:
    """动态/漏电功耗，单位归一化到 µW / nW。
    DC 报告当功耗较大时 Dynamic Power 单位会从 uW 自动切换为 mW
    （Power Units 头为 'Dynamic Power Units = 1mW'）——本函数按行内后缀归一化，
    避免 d32 等大功耗点被漏提（2026-09-03 sync_fifo 实测：1.6215 mW 档漏提）。"""
    dyn, leak = "n/a", "n/a"
    for ln in pwr.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(r"Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+(mW|uW)", ln)
        if m:
            v = float(m.group(1))
            dyn = f"{v * 1000.0:.4f}" if m.group(2) == "mW" else f"{v:.4f}"
        m = re.search(r"Cell Leakage Power\s+=\s+([0-9.eE+-]+)\s+(uW|nW)", ln)
        if m:
            v = float(m.group(1))
            leak = f"{v * 1000.0:.4f}" if m.group(2) == "uW" else f"{v:.4f}"
    return dyn, leak


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", help="CBB 根目录")
    ap.add_argument("run_id", help="PPA run id，如 run-20260829-01")
    ap.add_argument("--sequential-tags", default="", help="逗号分隔的时序模块 tag 子串（其余按组合 arrival 判时序）")
    args = ap.parse_args()

    root = Path(args.root)
    base = root / "build" / "eda" / "ppa" / args.run_id
    if not base.is_dir():
        print(f"[extract_ppa] ERROR: 报告目录不存在: {base}")
        return 20

    seq_subs = [s for s in args.sequential_tags.split(",") if s]

    rows: list[dict[str, str]] = []
    for rpt in sorted(base.glob("*_area.rpt")):
        tag = rpt.name.removesuffix("_area.rpt")
        tmax = base / f"{tag}_timing_max.rpt"
        io = base / f"{tag}_io.rpt"
        pwr = base / f"{tag}_power.rpt"
        regs = base / f"{tag}_regs.txt"
        worst, status = parse_worst_setup_slack(tmax)
        arrival = parse_io_arrival(io)
        dyn, leak = parse_power(pwr)
        is_seq = any(s in tag for s in seq_subs) if seq_subs else (worst != "n/a")
        if is_seq:
            verdict = "PASS" if status == "MET" else "FAIL"
        else:
            verdict = "PASS" if arrival != "n/a" else "FAIL"
        rows.append({
            "tag": tag,
            "area": parse_area(rpt), "regs": parse_regs(regs),
            "worst_slack_ns": worst, "slack_status": status,
            "io_arrival_ns": arrival,
            "verdict": verdict, "dyn_uW": dyn, "leak_nW": leak,
        })

    out = base / "ppa_summary.md"
    lines = [
        "# PPA Summary",
        "",
        f"> run: `{args.run_id}`；报告集：`build/eda/ppa/{args.run_id}/`（完整原始报告供人查看）",
        "> 时序主判据：时序模块用 **reg→reg 最差 setup slack**（非纯组合不用 arrival 判时序）；",
        "> 纯组合以组合 arrival 为时序结论；违规只看 vclk slack 的 VIOLATED（leakage 非时序）。",
        "",
        "| tag | area(µm²) | regs | worst_slack(ns) | slack_status | io_arrival(ns) | verdict | dyn(µW) | leak(nW) |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(
            f"| {r['tag']} | {r['area']} | {r['regs']} | {r['worst_slack_ns']} | "
            f"{r['slack_status']} | {r['io_arrival_ns']} | **{r['verdict']}** | "
            f"{r['dyn_uW']} | {r['leak_nW']} |"
        )
    lines += ["", f"_extract_ppa.py @ {args.run_id} — 共 {len(rows)} 个配置_", ""]
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"[extract_ppa] OK: {out}（{len(rows)} 配置）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
