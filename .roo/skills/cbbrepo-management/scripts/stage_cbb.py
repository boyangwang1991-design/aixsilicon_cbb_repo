#!/usr/bin/env python3
"""Stage an external CBB deliverable into the CBB platform repo (cbbrepo).

Ownership: cbbrepo-management / stage_cbb (CBB 交付件合并入库).

Input : an externally-written CBB deliverable directory, e.g.:
          <deliverable>/
            ├── cbb.yaml                 # SSOT（name/classification/contract/...）
            ├── ip-package.yaml          # 可选（schema 2.0）
            ├── fusesoc/aixsilicon_cbb_<name>.core
            ├── rtl/{interface,impl}/
            ├── verification/{common,simulation,formal,assertions}/
            ├── constraints/  docs/  characterization/  examples/
            └── README.md  CHANGELOG.md  OWNERS

Output: merged into the CBB repo:
          components/<category>/<name>/   # A1~A3
          adapters/<name>/                # A0
          templates/<name>/               # A4
        and registry.yaml cbbs 条目 upsert；--rebuild 可全量重建 cbbs 索引。

Usage:
  python -m scripts.stage_cbb <deliverable> [--repo DIR]
              [--category CAT] [--abstraction A0..A4] [--priority P0..P3]
              [--id CBB-XXX] [--dry-run] [--rebuild]
"""

import argparse
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML required: pip install pyyaml")

VENDOR = "aixsilicon"
LIBRARY = "cbb"
DEFAULT_VERSION = "0.1.0"

# A 层级 -> 顶层目录
TOP_BY_ABSTRACTION = {"A0": "adapters", "A4": "templates"}

# 技术域 -> 类别目录（仅常用映射，缺失时需 --category 显式指定）
CATEGORY_BY_DOMAIN = {
    "selection_decode": "selection_decode",
    "arithmetic": "arithmetic_datapath",
    "coding_integrity": "coding_integrity",
    "storage_queue": "fifo_queue_buffer",
    "storage": "register_memory",
    "streaming": "streaming_pipeline",
    "arbitration": "arbitration_scheduling",
    "cdc_rdc": "cdc_rdc",
    "clock_reset_power": "clock_reset_power",
    "control": "control_event_status",
    "interrupt_safety": "interrupt_safety",
    "apb_ahb_register": "apb_ahb_register",
    "axi": "axi_axi_stream",
    "noc": "noc_interconnect",
    "monitor_debug": "monitor_debug",
    "dft": "dft_test",
    "dsp": "dsp_ai_datapath",
}

# 合并时排除的运行时/缓存内容
EXCLUDE_DIRS = {".git", ".venv", "__pycache__", ".pytest_cache", "sim_workspace", "work", "run"}


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_yaml(path: Path) -> Optional[Dict[str, Any]]:
    if not path.is_file():
        return None
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None
    return data if isinstance(data, dict) else None


def resolve_identity(deliverable: Path, args) -> Dict[str, str]:
    """从 cbb.yaml / ip-package.yaml / 目录名 解析 CBB 身份。"""
    cbb = load_yaml(deliverable / "cbb.yaml") or {}
    ipkg = load_yaml(deliverable / "ip-package.yaml") or {}

    cbb_meta = cbb.get("cbb", {}) if isinstance(cbb.get("cbb"), dict) else {}
    cls = cbb.get("classification", {}) if isinstance(cbb.get("classification"), dict) else {}

    name = cbb_meta.get("name") or ipkg.get("name") or args.name or deliverable.name
    abstraction = (args.abstraction or cls.get("abstraction")
                   or ipkg.get("classification", {}).get("abstraction") or "A1")
    priority = (args.priority or ipkg.get("classification", {}).get("priority") or "P0")
    cbb_id = args.cbb_id or ipkg.get("id") or cbb_meta.get("id") or ""
    domain = cls.get("primary_domain") or ipkg.get("classification", {}).get("primary_domain") or ""
    category = (args.category or CATEGORY_BY_DOMAIN.get(domain, "")
                or (str(ipkg.get("group", "")).split("/")[-1] if ipkg.get("group") else ""))
    version = str(cbb_meta.get("version") or ipkg.get("version") or DEFAULT_VERSION)
    description = (cbb_meta.get("description") or ipkg.get("description") or "")
    return {
        "name": name,
        "abstraction": str(abstraction),
        "priority": str(priority),
        "id": str(cbb_id),
        "category": str(category),
        "version": version,
        "description": description,
    }


def target_dir(repo: Path, ident: Dict[str, str]) -> str:
    """计算目标相对路径：adapters/<name> / templates/<name> / components/<category>/<name>。"""
    top = TOP_BY_ABSTRACTION.get(ident["abstraction"])
    if top:
        return "{top}/{name}".format(top=top, name=ident["name"])
    if not ident["category"]:
        sys.exit("无法确定类别：请用 --category <类别> 指定（如 fifo_queue_buffer），或 cbb.yaml 提供 primary_domain")
    return "components/{cat}/{name}".format(cat=ident["category"], name=ident["name"])


def merge_deliverable(deliverable: Path, target: Path) -> List[str]:
    """将交付件内容复制/合并到目标目录，返回复制文件数。"""
    if not deliverable.is_dir():
        sys.exit("交付件目录不存在: %s" % deliverable)
    target.mkdir(parents=True, exist_ok=True)
    count = 0
    for src in sorted(deliverable.iterdir()):
        if src.name in EXCLUDE_DIRS:
            continue
        dst = target / src.name
        if src.is_dir():
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
        count += 1
    return count


def write_ip_package(target: Path, ident: Dict[str, str], rel_path: str) -> None:
    """生成/刷新 ip-package.yaml（schema 2.0）。"""
    pkg = {
        "schema_version": "2.0",
        "name": ident["name"],
        "version": ident["version"],
        "vendor": VENDOR,
        "library": LIBRARY,
        "description": ident["description"],
        "license": "internal",
        "path": rel_path,
        "maturity": "E0",
        "classification": {
            "abstraction": ident["abstraction"],
            "priority": ident["priority"],
        },
        "quality": {"gates": {"G0": "pass", "G1": "unknown", "G2": "unknown",
                              "G3": "unknown", "G4": "unknown", "G5": "unknown"}},
        "fusesoc": {"core": "{v}:{l}:{n}:{ver}".format(
            v=VENDOR, l=LIBRARY, n=ident["name"], ver=ident["version"])},
    }
    if ident["id"]:
        pkg["id"] = ident["id"]
    (target / "ip-package.yaml").write_text(
        yaml.safe_dump(pkg, allow_unicode=True), encoding="utf-8")


def load_registry(repo: Path) -> Dict[str, Any]:
    p = repo / "registry.yaml"
    data = load_yaml(p) or {}
    if "cbbs" not in data:
        data["cbbs"] = []
    return data


def upsert_cbb(registry: Dict[str, Any], ident: Dict[str, str], rel_path: str) -> None:
    entry = {
        "id": ident["id"],
        "name": ident["name"],
        "group": str(Path(rel_path).parent),
        "abstraction": ident["abstraction"],
        "priority": ident["priority"],
        "status": "merged",
        "version": ident["version"],
        "path": rel_path,
    }
    cbbs = [e for e in registry.get("cbbs", []) if e.get("name") != ident["name"]]
    cbbs.append(entry)
    registry["cbbs"] = cbbs


def rebuild_cbbs(repo: Path) -> Dict[str, Any]:
    """扫描 components/adapters/templates 下的 ip-package.yaml，重建 cbbs 索引。"""
    registry = load_registry(repo)
    cbbs = []
    for ipkg in sorted(repo.glob("components/*/*/ip-package.yaml")) + \
                sorted(repo.glob("adapters/*/ip-package.yaml")) + \
                sorted(repo.glob("templates/*/ip-package.yaml")):
        d = load_yaml(ipkg) or {}
        rel = str(ipkg.parent.relative_to(repo))
        cbbs.append({
            "id": d.get("id", ""),
            "name": d.get("name", ipkg.parent.name),
            "group": str(ipkg.parent.parent.relative_to(repo)) if ipkg.parent.parent != repo else ".",
            "abstraction": d.get("classification", {}).get("abstraction", "A1"),
            "priority": d.get("classification", {}).get("priority", "P0"),
            "status": "merged",
            "version": d.get("version", DEFAULT_VERSION),
            "path": rel,
        })
    registry["cbbs"] = sorted(cbbs, key=lambda e: e["name"])
    return registry


def main() -> int:
    ap = argparse.ArgumentParser(description="Stage an external CBB deliverable into cbbrepo")
    ap.add_argument("deliverable", help="外部 CBB 交付件目录")
    ap.add_argument("--repo", default=".", help="CBB 平台仓库根目录（默认当前目录）")
    ap.add_argument("--name", help="CBB 功能名（覆盖 cbb.yaml/目录名）")
    ap.add_argument("--category", help="类别目录（如 fifo_queue_buffer），A1~A3 时使用")
    ap.add_argument("--abstraction", choices=["A0", "A1", "A2", "A3", "A4"], help="抽象层级（覆盖）")
    ap.add_argument("--priority", help="优先级 P0~P3（覆盖）")
    ap.add_argument("--id", dest="cbb_id", help="清单 ID（如 QUE-021）")
    ap.add_argument("--dry-run", action="store_true", help="只打印计划，不写盘")
    ap.add_argument("--rebuild", action="store_true", help="扫描全部 ip-package.yaml 重建 cbbs 索引")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    if not (repo / "registry.yaml").exists() and not (repo / "fusesoc.conf").exists():
        sys.exit("--repo 不是 CBB 平台仓库（缺 registry.yaml / fusesoc.conf）")

    if args.rebuild:
        registry = rebuild_cbbs(repo)
        if args.dry_run:
            print("DRY-RUN: 将重建 cbbs 索引，共 %d 个 CBB" % len(registry["cbbs"]))
            return 0
        registry["updated"] = _now()
        registry["vendor"] = VENDOR
        registry["library"] = LIBRARY
        registry["unified_repo"] = registry.get("unified_repo", "")
        (repo / "registry.yaml").write_text(
            yaml.safe_dump(registry, allow_unicode=True), encoding="utf-8")
        print("==> 重建 cbbs 索引：共 %d 个 CBB" % len(registry["cbbs"]))
        return 0

    deliverable = Path(args.deliverable).resolve()
    ident = resolve_identity(deliverable, args)
    rel = target_dir(repo, ident)
    target = (repo / rel)
    print("==> 目标: %s （抽象 %s，优先级 %s）" % (rel, ident["abstraction"], ident["priority"]))
    if ident["id"]:
        print("    ID: %s" % ident["id"])
    if args.dry_run:
        print("DRY-RUN: 将合并交付件到 %s 并 upsert cbbs 条目" % rel)
        return 0

    copied = merge_deliverable(deliverable, target)
    write_ip_package(target, ident, rel)
    registry = load_registry(repo)
    upsert_cbb(registry, ident, rel)
    registry["updated"] = _now()
    registry.setdefault("vendor", VENDOR)
    registry.setdefault("library", LIBRARY)
    registry.setdefault("unified_repo", "")
    (repo / "registry.yaml").write_text(
        yaml.safe_dump(registry, allow_unicode=True), encoding="utf-8")
    print("==> 已合并 %d 个文件/目录到 %s" % (copied, rel))
    print("    下一步: 编辑 cbb.yaml/README 补充内容，然后 publish（git commit + push）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
