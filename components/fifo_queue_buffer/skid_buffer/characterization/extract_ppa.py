#!/usr/bin/env python3
"""extract_ppa.py — 从 DC 完整 PPA 报告集抽取关键指标（不重新综合）。

用法（从 CBB 根目录）:
    uv run python characterization/extract_ppa.py <cbb_root> <run_id>

输入: build/eda/ppa/<run_id>/skid_*_{area,timing_max,io,power,regs}*
输出: build/eda/ppa/<run_id>/ppa_summary.md

时序判据（多实现，2026-08-29）:
- forward/full（时序模块，create_clock 绑定 clk）→ **reg→reg 最差 setup slack** 主判据
  （timing_max.rpt 中 vclk path group 的 `slack (MET|VIOLATED)` 最小值）；
- BYPASS（组合直通，无寄存器）→ 无 reg→reg，以**组合 arrival**（io.rpt）为时序结论；
- IO 参考 = 组合输出（reg→out）最差 arrival；违规只看 vclk slack 的 VIOLATED
  （report_constraint 的 leakage power slack 属功耗、非时序）。
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
    """组合输出（reg→out）最差 arrival，作 IO 参考 / BYPASS 时序结论。"""
    best: float | None = None
    for ln in io.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(r"data arrival time\s+([0-9.]+)", ln)
        if m:
            v = float(m.group(1))
            if best is None or v > best:
                best = v
    return f"{best:.4f}" if best is not None else "n/a"


def parse_power(pwr: Path) -> tuple[str, str]:
    dyn, leak = "n/a", "n/a"
    for ln in pwr.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = re.search(r"Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+uW", ln)
        if m:
            dyn = m.group(1)
        m = re.search(r"Cell Leakage Power\s+=\s+([0-9.eE+-]+)\s+nW", ln)
        if m:
            leak = m.group(1)
    return dyn, leak


def main() -> int:
    ap = argparse.ArgumentParser(description="抽取 DC PPA 报告集关键指标")
    ap.add_argument("root", help="CBB 根目录")
    ap.add_argument("run_id", help="PPA run id，如 run-20260829-01")
    args = ap.parse_args()

    root = Path(args.root)
    base = root / "build" / "eda" / "ppa" / args.run_id
    if not base.is_dir():
        print(f"[extract_ppa] ERROR: 报告目录不存在: {base}")
        return 20

    rows: list[dict[str, str]] = []
    for rpt in sorted(base.glob("skid_*_area.rpt")):
        tag = rpt.name.removesuffix("_area.rpt")
        # tag 解析：skid_w<W>_i<impl> / skid_byp_w<W>
        mw = re.match(r"skid_w(\d+)_i(\d)", tag)
        mbyp = re.match(r"skid_byp_w(\d+)", tag)
        if mw:
            data_w, impl = mw.group(1), int(mw.group(2))
            mode = "forward" if impl == 0 else "full"
            bypass = "0"
        elif mbyp:
            data_w, impl, mode, bypass = mbyp.group(1), "1", "bypass", "1"
        else:
            continue
        tmax = base / f"{tag}_timing_max.rpt"
        io = base / f"{tag}_io.rpt"
        pwr = base / f"{tag}_power.rpt"
        regs = base / f"{tag}_regs.txt"
        worst, status = parse_worst_setup_slack(tmax)
        arrival = parse_io_arrival(io)
        dyn, leak = parse_power(pwr)
        if mode == "bypass":
            # 组合直通：无 reg→reg，以组合 arrival 为时序结论
            verdict = "PASS" if arrival != "n/a" else "FAIL"
        else:
            verdict = "PASS" if status == "MET" else "FAIL"
        rows.append({
            "tag": tag, "mode": mode, "data_w": data_w,
            "area": parse_area(rpt), "regs": parse_regs(regs),
            "worst_slack_ns": worst, "slack_status": status,
            "io_arrival_ns": arrival,
            "verdict": verdict, "dyn_uW": dyn, "leak_nW": leak,
        })

    out = base / "ppa_summary.md"
    lines = [
        "# PPA Summary — skid_buffer（多实现 profile）",
        "",
        f"> run: `{args.run_id}`；报告集：`build/eda/ppa/{args.run_id}/`（完整原始报告供人查看）",
        f"> 库/corner：`sc9_cmos28lp_base_hvt` `tt_nominal_max_1p00v_25c`；约束 400MHz（2.5ns）",
        "> 时序主判据：forward/full 用 **reg→reg 最差 setup slack**（非纯组合不用 arrival 判时序）；",
        "> BYPASS（组合直通，无寄存器）以组合 arrival 为时序结论；IO arrival 仅作参考；",
        "> 违规只看 vclk slack 的 VIOLATED（leakage power slack 属功耗、非时序）。",
        "",
        "| mode | DATA_W | area(µm²) | regs | worst_slack(ns) | slack_status | io_arrival(ns) | verdict | dyn(µW) | leak(nW) |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(
            f"| {r['mode']} | {r['data_w']} | {r['area']} | {r['regs']} | {r['worst_slack_ns']} | "
            f"{r['slack_status']} | {r['io_arrival_ns']} | **{r['verdict']}** | "
            f"{r['dyn_uW']} | {r['leak_nW']} |"
        )
    lines += ["", f"_extract_ppa.py @ {args.run_id} — 共 {len(rows)} 个配置_", ""]
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"[extract_ppa] OK: {out}（{len(rows)} 配置，主判据=reg→reg worst slack / BYPASS=arrival）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
