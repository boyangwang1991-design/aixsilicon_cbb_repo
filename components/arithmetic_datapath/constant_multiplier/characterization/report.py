#!/usr/bin/env python3
"""Extract measured results and build a traceable comparison, without rerunning synthesis."""

import hashlib, json, re, sys
from pathlib import Path
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from generate import build, emit


def main():
    raw = ROOT / "build/eda/ppa"
    d = json.loads((raw / "results.json").read_text())
    diagnosis_path = ROOT / "reports/ppa-failure-diagnosis.json"
    diagnosis = json.loads(diagnosis_path.read_text()) if diagnosis_path.exists() else None
    if diagnosis:
        for evidence in diagnosis["evidence"].values():
            if (
                hashlib.sha256((ROOT / evidence["path"]).read_bytes()).hexdigest()
                != evidence["sha256"]
            ):
                raise SystemExit("stale failure diagnosis evidence")
        d["failure_diagnosis"] = diagnosis
    measured = [r for r in d["points"] if r.get("maturity") == "synthesized"]
    first_report = (raw / measured[0]["tag"] / "power.rpt").read_text()
    corner = re.search(r"Operating Conditions:\s+(\S+)", first_report)
    version = re.search(r"Version:\s+(\S+)", first_report)
    d["operating_conditions"] = corner[1] if corner else "unavailable"
    d["tool_version"] = version[1] if version else "unavailable"
    d["status"] = "complete" if len(measured) == len(d["points"]) else "partial"
    lines = [
        "# 固定库综合对比",
        "",
        f"结果等级：synthesized（未完成点单列）；固定库指纹见 ppa-results.json。工艺角 {d['operating_conditions']}，DC {d['tool_version']}，周期 {d['period_ns']} ns，I/O 各 {d['input_output_delay_ns']} ns、负载 {d['load_pf']} pF、转换时间 {d['transition_ns']} ns、不确定度 {d['uncertainty_ns']} ns。组合模式使用虚拟时钟。",
        "",
        "仅比较同组相同位宽、系数、精度和延迟；未运行布局布线。功耗来自默认活动估计，无门级活动及样本窗口，不能证明毛刺收益或每有效样本能量。",
        "",
        "| 配置组 | 实现 | 单元面积 | 到达时间 ns | 最差 slack ns | 动态功耗 W（估计） | 泄漏 W（估计） |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for r in d["points"]:
        c = r["configuration"]
        directory = raw / r["tag"]
        for name, expected in r["raw_hashes"].items():
            if hashlib.sha256((directory / name).read_bytes()).hexdigest() != expected:
                raise SystemExit("stale raw report: " + r["tag"] + "/" + name)
        current = emit(c, build(c), "cm_ppa")
        if hashlib.sha256(current.encode()).hexdigest() != r["rtl_sha256"]:
            raise SystemExit("stale generated RTL: " + r["tag"])
        if r.get("maturity") != "synthesized":
            status = r.get("status", "not_run")
            if diagnosis and diagnosis["tag"] == r["tag"]:
                status += "; " + diagnosis["root_cause"]
            lines.append(
                f"| W{c['INPUT_WIDTH']}/L{c['LATENCY']} | {c['IMPL']} ({status}) | unavailable | unavailable | unavailable | unavailable | unavailable |"
            )
            continue
        p = (directory / "power.rpt").read_text()
        for field, label in [
            ("dynamic_power", "Total Dynamic Power"),
            ("leakage_power", "Cell Leakage Power"),
        ]:
            m = re.search(label + r"\s*=\s*([0-9.eE+-]+)\s*(\w+)", p)
            scale = {"W": 1, "mW": 1e-3, "uW": 1e-6, "nW": 1e-9, "pW": 1e-12}
            r[field] = float(m[1]) * scale[m[2]] if m and m[2] in scale else None
        cells = (directory / "cells.rpt").read_text()
        refs = re.findall(r"^\S+\s+(\S+)", cells, re.M)
        r["flop_count"] = sum(ref.startswith("DFF") for ref in refs)
        r["buffer_count"] = sum(ref.startswith("BUF") for ref in refs)
        r["counting_basis"] = "selected ARM SC9 cell reference prefixes DFF / BUF"
        r["energy_per_valid_sample"] = None
        r["activity_annotated"] = False
        r["equivalence"] = "sampled RTL simulation; formal scope in verification-report.md"

        def fmt(x):
            return "unavailable" if x is None else f"{x:.6g}"

        lines.append(
            "| "
            + " | ".join(
                [
                    f"W{c['INPUT_WIDTH']}/L{c['LATENCY']}",
                    c["IMPL"],
                    *[
                        fmt(r[k])
                        for k in ["area", "arrival_ns", "wns_ns", "dynamic_power", "leakage_power"]
                    ],
                ]
            )
            + " |"
        )
    if diagnosis:
        lines += [
            "",
            f"失败原因已核实：内核 OOM 日志与 DC 异常退出子进程 PID {diagnosis['child_pid']} 一致，"
            f"被杀进程匿名驻留内存为 {diagnosis['killed_child_anon_rss_kib']} KiB。"
            "系统内存耗尽后 DC 报告 tool_internal_error；该点未生成 PPA 指标。"
            "证据指纹见 [诊断记录](ppa-failure-diagnosis.json)。",
        ]
        if diagnosis.get("low_effort_retry"):
            lines += [
                "",
                "降低 datapath 优化等级的隔离重试通过了算术映射阶段，但随后优化阶段仍耗尽内存；"
                "该重试设置单进程 7 GiB 虚拟内存上限，工具明确报告 Out of memory。",
            ]
    if diagnosis and diagnosis.get("classic_retry"):
        lines += [
            "",
            "传统 `compile -map_effort medium` 重试在映射优化阶段按用户收尾要求终止，"
            "状态为 cancelled，未产生可用 PPA 结果；不能据此判定该流程成功或失败。",
        ]
    lines += [
        "",
        "TNS、最大扇出及物理布线指标当前 unavailable；触发器与 buffer 数从所选库的单元类型抽取到 JSON，不以 0 代替。到达时间包含 I/O 条件；流水配置报告保留全部适用路径，不能把不同延迟跨组比较为收益。",
        "",
        "约束报告中的 max_leakage_power=0 是工具默认泄漏优化目标，其 VIOLATED 不属于 setup 失败，不作为已批准功耗上限。\n\nAUTO 仍回退 NATIVE：该代表矩阵不构成所有配置的可信工艺缓存。面积、延迟未指定数值选择上限，保留候选，无唯一最优宣称。",
        "",
        "![固定组比较](ppa-comparison.png)",
    ]
    (ROOT / "reports/ppa-report.md").write_text("\n".join(lines) + "\n")
    (ROOT / "reports/ppa-results.json").write_text(json.dumps(d, indent=2) + "\n")
    groups = {}
    for r in measured:
        groups.setdefault(
            (r["configuration"]["INPUT_WIDTH"], r["configuration"]["LATENCY"]), []
        ).append(r)
    fig, axes = plt.subplots(2, len(groups), figsize=(12, 7), squeeze=False)
    colors = {"NATIVE": "#264653", "BINARY": "#2a9d8f", "CSD": "#e9c46a", "ADDER_GRAPH": "#e76f51"}
    for column, (group, rs) in enumerate(groups.items()):
        names = [r["configuration"]["IMPL"].replace("ADDER_GRAPH", "GRAPH") for r in rs]
        for row, (key, label) in enumerate([("area", "Cell area"), ("arrival_ns", "Arrival (ns)")]):
            ax = axes[row, column]
            bars = ax.bar(
                names, [r[key] for r in rs], color=[colors[r["configuration"]["IMPL"]] for r in rs]
            )
            ax.bar_label(bars, fmt="%.2f", fontsize=8, padding=3)
            coeff = rs[0]["configuration"]["COEFF"]
            coeff_label = "-(2^127-1)" if coeff == str(-((1 << 127) - 1)) else coeff
            ax.set(title=f"W={group[0]}, L={group[1]}, C={coeff_label}", ylabel=label)
            ax.margins(y=0.18)
            ax.tick_params(axis="x", labelrotation=35)
            ax.grid(axis="y", alpha=0.2)
    missing = [
        r["tag"] + ": " + r.get("status", "not_run")
        for r in d["points"]
        if r.get("maturity") != "synthesized"
    ]
    if missing:
        fig.suptitle("Unavailable: " + "; ".join(missing), fontsize=11)
    fig.tight_layout()
    fig.savefig(ROOT / "reports/ppa-comparison.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    main()
