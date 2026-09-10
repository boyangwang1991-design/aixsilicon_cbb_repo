#!/usr/bin/env python3
"""Check independent evidence and produce local acceptance/release-candidate artifacts.

No registry maturity upgrade, publication or Git operation is performed.
"""

from __future__ import annotations

import hashlib
import json
import tarfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports"
DEP = ROOT.parent / "fixed_priority_arbiter"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def load(name):
    return json.loads((REPORT / name).read_text())


def main():
    if not __debug__:
        raise RuntimeError("Evidence validation must run without Python -O")
    rtl_hash = sha(ROOT / "rtl/packet_locking_arbiter.sv")
    dep_hash = sha(DEP / "rtl/fixed_priority_arbiter.sv")
    sim = load("verification-sim.json")
    neg = load("verification-negative.json")
    mut = load("verification-mutation.json")
    lint = load("verification-lint.json")
    formal = load("formal-summary.json")
    ppa = load("ppa-summary.json")
    contract = json.loads((ROOT / "build/eda/spec-check.json").read_text())
    assert len(contract["cbbs"]) == 1
    assert not contract["cbbs"][0]["errors"] and not contract["cbbs"][0]["warnings"]
    (REPORT / "contract-summary.json").write_text(
        json.dumps(
            dict(
                status="pass",
                strict=True,
                errors=[],
                warnings=[],
                raw_sha256=sha(ROOT / "build/eda/spec-check.json"),
            ),
            indent=2,
        )
        + "\n"
    )
    for record in [sim, neg, mut, lint, formal]:
        assert record["status"] == "pass"
        assert record["rtl_sha256"] == rtl_hash and record["dependency_sha256"] == dep_hash, (
            "Stale evidence"
        )
    assert len(sim["matrix"]) == 29 and sum(len(x["runs"]) for x in sim["matrix"]) == 87
    assert len(neg["negative"]) == 5 and all(
        x["status"] == "rejected_at_elaboration" for x in neg["negative"]
    )
    assert len(mut["mutations"]) == 4 and all(x["status"] == "killed" for x in mut["mutations"])
    assert len(formal["rows"]) == 10 and len(ppa["rows"]) == 10
    assert (
        ppa["context"]["rtl_sha256"] == rtl_hash
        and ppa["context"]["dependency"]["sha256"] == dep_hash
    )
    corelog = ROOT / "build/eda/fusesoc/replay.txt"
    assert "PLA_PASS" in corelog.read_text() and "Failed to build" not in corelog.read_text()
    childlog = ROOT / "build/eda/dependency-replay.txt"
    assert "FPA_TB PASS: all scenarios clean" in childlog.read_text()
    assert (
        "FPA_TB FAIL" not in childlog.read_text() and "FPA_TB TIMEOUT" not in childlog.read_text()
    )
    points = [x["parameters"] for x in ppa["rows"]]
    assert all(row["parameters"] in points for row in formal["rows"])
    cycles = sum(r["cycles"] for c in sim["matrix"] for r in c["runs"])
    constrained = all(r["worst_slack_ns"] >= 0 for r in ppa["rows"])
    results = dict(
        status="accepted_local_candidate",
        rtl_sha256=rtl_hash,
        dependency_sha256=dep_hash,
        configurations=29,
        seeds_per_configuration=3,
        cycles=cycles,
        negative_rejected=5,
        mutations_killed=4,
        formal_equivalence_points=10,
        synthesis_points=10,
        all_points_meet_400mhz_constraints=constrained,
        consumer="Real synthesizable example mux, not production axis_mux or stream_interconnect",
        limitations=[
            "Simulation SVA does not constitute unbounded liveness proof",
            "No production consumer signoff",
            "Vectorless power estimates",
            "No formal publication",
        ],
        fusesoc_log_sha256=sha(corelog),
        dependency_regression_log_sha256=sha(childlog),
    )
    (REPORT / "acceptance.json").write_text(json.dumps(results, indent=2) + "\n")
    lines = [
        "# Packet locking arbiter 验收报告",
        "",
        f"结论：本地实现候选验收完成；29配置×3seed、{cycles}周期通过。正式发布和生产消费者签核不在本次结论范围。",
        "",
        "| 项目 | 结果与证据 |",
        "|---|---|",
        "| G0–G2 | 规格确认、依赖查重、单实现详设；契约strict/RTM检查通过 |",
        "| G3 | 所有功能点VCS编译；5个非法参数按PC诊断拒绝；两模式SpyGlass 0 Fatal/0 Error；warning审查见lint_waivers |",
        "| G4–G5 | 87次仿真、4个变异杀死；20生成配置+9风险配置；独立模型+消费者mux数据/顺序检查 |",
        "| Formal | 10个参数点RTL到真实映射网表的Formality等价通过；非无界活性证明 |",
        "| G6 | 10点DC工艺绑定PPA，面积/时序/功耗/漏电和父子贡献见ppa-report |",
        "| 构建 | FuseSoC实际依赖闭包setup/build/run通过，使用包内VCS时间尺度选项 |",
        "| G7 | 参数抽样范围验收；非生产消费者完整签核、非Stable产品认定 |",
        "| G8 | 仅本地SemVer/SBOM/hash候选包，不发布Catalog或远端 |",
        "",
        "## 验证矩阵",
        "",
        "| 配置 | 集合 | seeds | 结果 |",
        "|---|---|---|---|",
    ]
    for c in sim["matrix"]:
        lines.append(f"| {c['config_id']} | {c['kind']} | 101,2027,65537 | pass |")
    lines += [
        "",
        "## 限制与验收范围",
        "",
        "- NUM_REQ=1..64、LEN_W=1..16是合法参数域；上表是实测功能域，其他组合保持experimental，不能将抽样声明为全笛卡尔验证。",
        "- 生产axis_mux/stream_interconnect仍为planned。本次独立可综合示例实际例化本CBB，且核对数据来源、序号与接受顺序；不宣称两个独立IP消费者通过。",
        "- 公平性按完成包数计，依赖owner/下游最终进展；无超时恢复或按字节公平。",
        "- 工具探测未发现VC Formal/Jasper/SymbiYosys；实际执行Formality等价和VCS关键SVA，未把等价工具冒称性质证明器。",
        "- 本地working tree以输入SHA绑定；正式clean Git基线、生产消费者与Catalog发布由后续发布流程完成。",
        "- 集成Owner负责同步释放reset；lint waiver在参数配置、依赖、状态结构或reset契约改变时失效。",
        "- 生产消费者缺口由integration-owner负责，首次生产IP集成时必须重跑smoke并关闭；替代证据为本次真实例化mux及数据scoreboard。",
        "",
        "资产cbb.yaml成熟度保持E0候选元数据，独立证据可供Workflow评定E2；不由SKILL自动提升为qualified/released。",
        "",
        "可复现入口见README；JSON报告提供具体配置、seed、输入和原始日志SHA。",
    ]
    (REPORT / "qualification-report.md").write_text("\n".join(lines) + "\n")
    lines = [
        "# PPA表征报告",
        "",
        f"Run `{ppa['context']['run_id']}`；DC {ppa['tool_version']}；TT 1.00V/25C，400MHz，输入/输出延迟0.5ns、uncertainty 0.1ns、负载0.01pF。",
        "",
        "PPA-E2工艺绑定表征，活动为输入概率0.5、toggle rate 0.1的vectorless传播估计，非实测工作负载功耗；资产成熟度独立。",
        "",
        "| N | 模式 | LEN_W | 总面积 um² | 父级自身 | 子级合计 | 最差slack ns | reg→reg ns | 动态 µW | 漏电 nW |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in ppa["rows"]:
        p = r["parameters"]
        rr = r["reg_to_reg_slack_ns"]
        rr = "N/A" if rr is None else f"{rr:.3f}"
        lines.append(
            f"| {p['NUM_REQ']} | {p['LOCK_MODE']} | {p['LEN_W']} | {r['area_um2']:.3f} | {r['parent_local_area_um2']:.3f} | {r['child_area_um2']:.3f} | {r['worst_slack_ns']:.3f} | {rr} | {r['dyn_power_uW']:.3f} | {r['leak_power_nW']:.3f} |"
        )
    lines += [
        "",
        "![PPA sweep](ppa-sweep.png)",
        "",
        (
            "本次全部10点满足所列400MHz约束。"
            if constrained
            else "部分配置未满足初始400MHz探索约束，必须按表中slack调整集成频率/约束；不能宣称全域400MHz。"
        ),
        "组合输入/输出路径与reg→reg路径分别报告，未以第一条arrival替代时序结论。",
        "部分slack显示0.000是原始DC报告的显示精度；报告状态为MET，不代表存在可外推的时序裕量，生产签核需高精度多角STA。",
        "父级面积由total减去两个直接子实例的层级面积计算；不重复累计孙级，不将子CBB面积算作父逻辑收益。",
        "单实现、不同请求数量提供不同容量，不能据此宣布一个容量点支配另一个；EOP与长度模式功能不同，不作等价实现Pareto优劣排行。",
        "主要结构优化为并行优先编码、显式回绕替代取模、EOP模式裁剪计数器和N=1特化。结果不外推到未扫参数、其他工艺角或真实布线。",
        "详设的PPA-E0推导现由本表实测补充；保存层级area/power、全路径/寄存器/输出timing、clock/check/constraints和SVF/DDC/netlist。",
        "失败run-01由冗余current_design原始名引起，已按工具诊断拒绝，最终仅消费修复后的run-02；report_power总量从保存DDC重放，不重复综合。",
        "原始报告留build/eda/ppa，公开摘要只含库/corner标识、输入和证据hash。",
    ]
    (REPORT / "ppa-report.md").write_text("\n".join(lines) + "\n")
    meta = yaml.safe_load((ROOT / "cbb.yaml").read_text())
    paths = [
        p
        for p in ROOT.rglob("*")
        if p.is_file()
        and not any(
            part in ["build", "__pycache__", ".ruff_cache", "release"]
            for part in p.relative_to(ROOT).parts
        )
    ]
    artifacts = [dict(path=str(p.relative_to(ROOT)), sha256=sha(p)) for p in sorted(paths)]
    manifest = dict(
        schema_version="1.0",
        release=dict(
            cbb=meta["cbb"]["id"],
            version="0.1.0",
            status="candidate",
            maturity="E0",
            candidate_maturity="E2",
        ),
        artifacts=artifacts,
        sbom=dict(
            license="Apache-2.0",
            dependencies=[
                dict(
                    vlnv="aixsilicon:cbb:fixed_priority_arbiter:0.1.0",
                    rtl_sha256=dep_hash,
                    core_sha256=sha(DEP / "fusesoc/aixsilicon_cbb_fixed_priority_arbiter.core"),
                )
            ],
        ),
        known_limits=results["limitations"],
    )
    (ROOT / "release").mkdir(exist_ok=True)
    (ROOT / "release/manifest.yaml").write_text(
        yaml.safe_dump(manifest, sort_keys=False, allow_unicode=True)
    )
    out = ROOT / "build/releases"
    out.mkdir(parents=True, exist_ok=True)
    archive = out / "packet-locking-arbiter-0.1.0-candidate.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        for p in sorted(paths) + [ROOT / "release/manifest.yaml"]:
            tar.add(p, arcname=str(Path(ROOT.name) / p.relative_to(ROOT)), recursive=False)
        for rel in [
            "rtl/fixed_priority_arbiter.sv",
            "fusesoc/aixsilicon_cbb_fixed_priority_arbiter.core",
        ]:
            tar.add(DEP / rel, arcname=str(Path(DEP.name) / rel), recursive=False)
        tar.add(ROOT / "LICENSE", arcname=str(Path(DEP.name) / "LICENSE"), recursive=False)
    (out / "sha256.txt").write_text(sha(archive) + "  " + archive.name + "\n")
    print(json.dumps(results, indent=2))
    print("Candidate archive:", archive)


if __name__ == "__main__":
    main()
