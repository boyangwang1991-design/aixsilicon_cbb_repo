#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_cbb_structure.py — CBB registry.yaml 索引工具（registry-only）

自 cbb_repo_list.md 删除后，registry.yaml 成为唯一 SSOT（含 family/
implementation/description/status）。本脚本职责：

1. **校验**（默认）：加载 registry.yaml，做一致性健康检查——
   字段齐全、ID 唯一、group/abstraction/priority/status 合法、路径一致、
   implemented/released 必须有工程包；目录存在不表示验证通过。
2. **规范化**（--write）：修复可自动纠正的问题（排序稳定、去除空字段），重写 registry.yaml。
3. **重建空工程包**（--rebuild-dirs）：可选，按 registry 条目重建 adapters/components
   下的占位目录（仅 README，不生成 Core 或工程元数据）。默认不触碰文件系统。

用法:
  python3 scripts/build_cbb_structure.py             # 校验（只读）
  python3 scripts/build_cbb_structure.py --write     # 校验并规范化重写
  python3 scripts/build_cbb_structure.py --rebuild-dirs   # 同时重建空工程包目录
"""
import os
import shutil
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY_PATH = os.path.join(ROOT, "registry.yaml")

# 合法的枚举域（与 schemas/cbb.schema.yaml / 原清单保持一致）
VALID_ABSTRACTION = {"A0", "A1", "A2", "A3", "A4",
                     "A1/A0", "A1/A2", "A2/A3", "A2/A4", "A3/A4", "A0/A2"}
VALID_PRIORITY = {"P0", "P1", "P2", "P3"}
VALID_GROUP_TOPS = {"adapters", "components"}
VALID_STATUS = {"planned", "implemented", "released", "deprecated"}

REQUIRED_FIELDS = ["id", "name", "family", "group", "abstraction",
                   "priority", "implementation", "description", "status", "version", "path"]


def load_registry(path=REGISTRY_PATH):
    """加载 registry.yaml（无 pyyaml 依赖时用极简降级：仅能读而不校验）。"""
    try:
        import yaml
    except ImportError:
        print("警告: 未找到 pyyaml —— 退出（本脚本依赖 yaml 模块）。请用 workflow 根 uv 环境运行。")
        raise SystemExit(3)
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def validate(reg, root=None):
    """返回 (errors, warnings)。errors 非空 → 校验失败。"""
    errors, warnings = [], []
    root = Path(root or ROOT).resolve()
    if not isinstance(reg, dict):
        return ["registry 必须是 object"], warnings
    if (root / "reports").exists():
        errors.append("仓库根 reports/ 非法：CBB 报告须位于具体工程；历史材料请归档到 docs/archive")
    cbbs = reg.get("cbbs", [])
    if not isinstance(cbbs, list):
        errors.append("cbbs 必须是列表")
        return errors, warnings

    ids = {}
    names, paths = set(), set()
    for i, e in enumerate(cbbs):
        if not isinstance(e, dict):
            errors.append("[%d] 条目不是 object" % i)
            continue
        cid = e.get("id")
        for field, seen in (("name", names), ("path", paths)):
            value = e.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append("[%s] %s 必须是非空字符串" % (cid, field))
            elif value in seen:
                errors.append("%s 重复: %s" % (field, value))
            else:
                seen.add(value)
        if not cid:
            errors.append("[%d] 缺 id" % i)
        elif cid in ids:
            errors.append("id 重复: %s（第 %d / %d 条）" % (cid, ids[cid], i))
        else:
            ids[cid] = i

        for field in REQUIRED_FIELDS:
            v = e.get(field)
            if v is None or (isinstance(v, str) and not v.strip()):
                errors.append("[%s] 缺必填字段: %s" % (cid or "?", field))

        ab = e.get("abstraction")
        if ab and ab not in VALID_ABSTRACTION:
            errors.append("[%s] abstraction 非法: %s" % (cid, ab))
        pr = e.get("priority")
        if pr and pr not in VALID_PRIORITY:
            errors.append("[%s] priority 非法: %s" % (cid, pr))
        st = e.get("status")
        if st and st not in VALID_STATUS:
            errors.append("[%s] status 非法: %s" % (cid, st))

        gp = e.get("group", "")
        top = gp.split("/")[0] if gp else ""
        if top not in VALID_GROUP_TOPS:
            errors.append("[%s] group 顶层非法: %s" % (cid, gp))

        p = e.get("path", "")
        if not isinstance(p, str):
            continue
        target = (root / p).resolve()
        if Path(p).is_absolute() or ".." in Path(p).parts or not target.is_relative_to(root):
            errors.append("[%s] path 越出仓库: %s" % (cid, p))
            continue
        # path 必须位于 group 顶层目录下（adapters|components/<category>/<name> 或本顶层/<name>）
        if p:
            parts = p.split("/")
            if len(parts) < 2 or parts[0] not in VALID_GROUP_TOPS or p == gp or not p.startswith(gp + "/"):
                errors.append("[%s] path(%s) 与 group(%s) 不一致" % (cid, p, gp))

        # implemented ↔ 物理目录实态
        if st in ("implemented", "released"):
            if not target.is_dir():
                errors.append("[%s] status=implemented 但目录不存在: %s" % (cid, p))
            elif not (target / "cbb.yaml").is_file():
                errors.append("[%s] implemented 缺 cbb.yaml: %s" % (cid, p))
        elif st == "planned":
            pass  # planned 可以是正在开发的工程包，目录本身不是质量证据。

        if (target / "cbb.yaml").is_file():
            try:
                import yaml
                doc = yaml.safe_load((target / "cbb.yaml").read_text(encoding="utf-8"))
                meta = doc.get("cbb", {}) if isinstance(doc, dict) else {}
                for field in ("name", "version"):
                    if str(meta.get(field, "")) != str(e.get(field, "")):
                        errors.append("[%s] cbb.yaml %s 与 registry 不一致" % (cid, field))
                if meta.get("id") != "aixsilicon:cbb:%s" % e.get("name"):
                    errors.append("[%s] cbb.yaml 资产 ID 不一致" % cid)
            except (ValueError, AttributeError, OSError, yaml.YAMLError) as exc:
                errors.append("[%s] 无法读取 cbb.yaml: %s" % (cid, exc))

    # Preserve historical identity across migration, withdrawal and reordering.
    history = root / "governance/reserved-ids.yaml"
    if history.is_file():
        import yaml
        reserved = yaml.safe_load(history.read_text(encoding="utf-8"))["ids"]
        owners = {value: name for name, value in reserved.items()}
        if len(owners) != len(reserved):
            errors.append("历史编号重复")
        for entry in reg.get('cbbs', []):
            name, cid = entry.get("name"), entry.get("id")
            if name not in reserved:
                errors.append("[%s] 新资产须追加历史编号预留表" % name)
            if name in reserved and reserved[name] != cid:
                errors.append("[%s] 不得改变历史编号" % name)
            if cid in owners and owners[cid] != name:
                errors.append("[%s] 不得复用历史编号 %s" % (name, cid))
    retired = root / "governance/retired-assets.yaml"
    if retired.is_file():
        import yaml
        inactive = {e["original"]["name"] for e in yaml.safe_load(retired.read_text(encoding="utf-8"))["records"]
                    if e["disposition"] != "restored"}
        for entry in reg.get('cbbs', []):
            if entry.get("name") in inactive:
                errors.append("[%s] 恢复前须更新退役记录为 restored" % entry["name"])
    return errors, warnings


def rebuild_dirs(reg):
    """按 registry 条目重建空工程包目录（只影响 planned 且目录缺失的条目）。
    已实现构件目录（status=implemented）不做任何操作，避免覆盖真实 RTL/证据。"""
    cbb_doc = "见 registry.yaml（SSOT）。CBB 工程包规范见 cbb-development-suite。"
    created = 0
    for e in reg.get("cbbs", []):
        if e.get("status") != "planned":
            continue
        cbb_dir = os.path.join(ROOT, e["path"])
        if os.path.isdir(cbb_dir):
            continue
        os.makedirs(cbb_dir, exist_ok=True)
        readme = os.path.join(cbb_dir, "README.md")
        if not os.path.exists(readme):
            with open(readme, "w", encoding="utf-8") as f:
                f.write("# %s\n\n%s （%s, %s）\n\n%s\n" % (
                    e["name"], e.get("family", ""), e.get("abstraction", ""),
                    e.get("priority", ""), cbb_doc))
        created += 1
    return created


def write_registry(reg):
    """规范化唯一事实源，保留扩展字段及安全 YAML 转义。"""
    import yaml
    from datetime import datetime, timezone
    reg["updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    reg["cbbs"].sort(key=lambda e: e["id"])
    Path(REGISTRY_PATH).write_text(yaml.safe_dump(reg, allow_unicode=True, sort_keys=False), encoding="utf-8")


def main():
    import argparse
    ap = argparse.ArgumentParser(description="CBB registry.yaml 索引工具（SSOT 校验/规范化）")
    ap.add_argument("--check", action="store_true", help="只读校验（默认）")
    ap.add_argument("--write", action="store_true", help="校验通过后规范化重写 registry.yaml")
    ap.add_argument("--rebuild-dirs", action="store_true",
                    help="按 registry 重建缺失的空工程包目录（不触碰 implemented 构件）")
    args = ap.parse_args()

    reg = load_registry()
    errors, warnings = validate(reg)
    cbbs = reg.get("cbbs", [])
    implemented = sum(1 for e in cbbs if e.get("status") == "implemented")

    print("registry.yaml: 共 %d 条（implemented=%d）" % (len(cbbs), implemented))
    for w in warnings:
        print("  WARN: %s" % w)
    for e in errors:
        print("  ERROR: %s" % e)

    if errors:
        print("==> 校验失败（%d 个错误）。不做任何写入。" % len(errors))
        raise SystemExit(10)

    if args.rebuild_dirs:
        n = rebuild_dirs(reg)
        print("==> 已重建 %d 个缺失空工程包目录" % n)

    if args.write:
        write_registry(reg)
        print("==> registry.yaml 已规范化重写")
    else:
        print("==> 校验通过（只读，未写入）。加 --write 规范化，或 --rebuild-dirs 重建空目录。")


if __name__ == "__main__":
    main()
