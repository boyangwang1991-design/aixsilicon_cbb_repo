#!/usr/bin/env python3
"""从 PPA run 目录的 *_power.rpt 确定性提取功耗，回填对应 *_summary.txt。

背景：synth_sweep.tcl 早期版本的 summary 提取只抓 area/arrival/slack，
漏了 power 字段；raw 证据 *_power.rpt 完整存在时可用本脚本回填，
无需重跑 DC 综合（提取为纯文本解析，可复现）。

提取字段（与修复后的 synth_sweep.tcl summary 正则一致）：
  - Total Dynamic Power  = <x> uW  -> dyn_power_uW=<x>
  - Cell Leakage Power   = <y> nW  -> leak_power_nW=<y>

用法（从 CBB 工作区根执行）：
  uv run python characterization/extract_power_summary.py \
      --run-dir build/eda/ppa/run-20260828-01
幂等：summary 中已存在的 dyn_power_uW/leak_power_nW 行先移除再回填。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

RE_DYN = re.compile(r"Total Dynamic Power\s+=\s+([0-9.eE+-]+)\s+uW")
RE_LEAK = re.compile(r"Cell Leakage Power\s+=\s+([0-9.eE+-]+)\s+nW")
FIELDS = ("dyn_power_uW", "leak_power_nW")


def parse_power(rpt: Path) -> tuple[str | None, str | None]:
    dyn = leak = None
    for line in rpt.read_text(encoding="utf-8", errors="replace").splitlines():
        if (m := RE_DYN.search(line)) and dyn is None:
            dyn = m.group(1)
        if (m := RE_LEAK.search(line)) and leak is None:
            leak = m.group(1)
    return dyn, leak


def backfill(summary: Path, dyn: str | None, leak: str | None) -> bool:
    if dyn is None and leak is None:
        return False
    lines = [
        ln
        for ln in summary.read_text(encoding="utf-8").splitlines()
        if not any(ln.startswith(f + "=") for f in FIELDS)
    ]
    if dyn is not None:
        lines.append(f"dyn_power_uW={dyn}")
    if leak is not None:
        lines.append(f"leak_power_nW={leak}")
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dir", required=True, type=Path)
    args = ap.parse_args()
    run_dir = args.run_dir.resolve()
    if not run_dir.is_dir():
        print(f"ERROR: run dir not found: {run_dir}", file=sys.stderr)
        return 10

    rpts = sorted(run_dir.glob("*_power.rpt"))
    if not rpts:
        print(f"ERROR: no *_power.rpt under {run_dir}", file=sys.stderr)
        return 10

    print(f"{'tag':<16} {'dyn_uW':>10} {'leak_nW':>10}")
    updated = 0
    for rpt in rpts:
        tag = rpt.name.removesuffix("_power.rpt")
        summary = run_dir / f"{tag}_summary.txt"
        if not summary.is_file():
            print(f"SKIP {tag}: missing {summary.name}", file=sys.stderr)
            continue
        dyn, leak = parse_power(rpt)
        if backfill(summary, dyn, leak):
            updated += 1
        print(f"{tag:<16} {dyn or '-':>10} {leak or '-':>10}")
    print(f"backfilled {updated}/{len(rpts)} summaries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
