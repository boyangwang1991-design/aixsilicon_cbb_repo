#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_cbb_structure.py — CBB registry.yaml 索引工具（registry-only）

自 cbb_repo_list.md 删除后，registry.yaml 成为唯一 SSOT（410 条，含 family/
implementation/description/status）。本脚本职责：

1. **校验**（默认）：加载 registry.yaml，做一致性健康检查——
   字段齐全、ID 唯一、group/abstraction/priority/status 合法、路径一致、
   implemented 状态与物理目录实态一致（目录存在 ↔ status=implemented）。
2. **规范化**（--write）：修复可自动纠正的问题（排序稳定、去除空字段），重写 registry.yaml。
3. **重建空工程包**（--rebuild-dirs）：可选，按 registry 条目重建 adapters/components/templates
   下的空工程包目录（README/fusesoc core/ip-package）。默认不触碰文件系统。

用法:
  python3 scripts/build_cbb_structure.py             # 校验（只读）
  python3 scripts/build_cbb_structure.py --write     # 校验并规范化重写
  python3 scripts/build_cbb_structure.py --rebuild-dirs   # 同时重建空工程包目录
"""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY_PATH = os.path.join(ROOT, "registry.yaml")

# 合法的枚举域（与 schemas/cbb.schema.yaml / 原清单保持一致）
VALID_ABSTRACTION = {"A0", "A1", "A2", "A3", "A4",
                     "A1/A0", "A1/A2", "A2/A3", "A2/A4", "A3/A4", "A0/A2"}
VALID_PRIORITY = {"P0", "P1", "P2", "P3"}
VALID_GROUP_TOPS = {"adapters", "components", "templates"}
VALID_STATUS = {"planned", "implemented"}

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


def validate(reg):
    """返回 (errors, warnings)。errors 非空 → 校验失败。"""
    errors, warnings = [], []
    cbbs = reg.get("cbbs", [])
    if not isinstance(cbbs, list):
        errors.append("cbbs 必须是列表")
        return errors, warnings

    ids = {}
    for i, e in enumerate(cbbs):
        if not isinstance(e, dict):
            errors.append("[%d] 条目不是 object" % i)
            continue
        cid = e.get("id")
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
        # path 必须位于 group 顶层目录下（adapters|components|templates/<category>/<name> 或本顶层/<name>）
        if p:
            parts = p.split("/")
            if len(parts) < 2 or parts[0] not in VALID_GROUP_TOPS or p == gp or not p.startswith(gp + "/"):
                errors.append("[%s] path(%s) 与 group(%s) 不一致" % (cid, p, gp))

        # implemented ↔ 物理目录实态
        if st == "implemented":
            if not os.path.isdir(os.path.join(ROOT, p)):
                errors.append("[%s] status=implemented 但目录不存在: %s" % (cid, p))
        elif st == "planned":
            if os.path.isdir(os.path.join(ROOT, p)):
                warnings.append("[%s] status=planned 但目录存在（可能已实现未更新状态）: %s" % (cid, p))

    return errors, warnings


def rebuild_dirs(reg):
    """按 registry 条目重建空工程包目录（只影响 planned 且目录缺失的条目）。
    已实现构件目录（status=implemented）不做任何操作，避免覆盖真实 RTL/证据。"""
    cbb_doc = "见 registry.yaml（SSOT）。CBB 工程包规范见 cbb-development-suite。"
    created = 0
    for e in reg.get("cbbs", []):
        if e.get("status") == "implemented":
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
    """重写 registry.yaml（稳定排序 + 去除空字段 + 生成头注释）。"""
    from datetime import datetime, timezone
    reg["updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    reg["cbbs"].sort(key=lambda e: e["id"])
    lines = []
    lines.append('schema_version: "%s"' % reg.get("schema_version", "2.0"))
    lines.append('updated: "%s"' % reg["updated"])
    lines.append("# 本文件是 CBB 目录唯一 SSOT（由 scripts/build_cbb_structure.py 治理）。")
    lines.append("# 字段: id/name/family/group/abstraction/priority/implementation/description/status/version/path")
    lines.append("# 修改入口: 直接编辑本文件后运行 'python3 scripts/build_cbb_structure.py' 校验。")
    lines.append("# status=implemented 表示物理目录存在且通过验证；未实现条目无物理目录。")
    lines.append("vendor: aixsilicon")
    lines.append("library: cbb")
    lines.append("")
    lines.append("cbbs:")
    for e in reg["cbbs"]:
        lines.append("  - id: %s" % e["id"])
        for f in REQUIRED_FIELDS[1:]:
            v = e.get(f)
            if f in ("version",):
                lines.append("    %s: \"%s\"" % (f, v))
            else:
                lines.append("    %s: %s" % (f, v))
    with open(REGISTRY_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    import argparse
    ap = argparse.ArgumentParser(description="CBB registry.yaml 索引工具（SSOT 校验/规范化）")
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
