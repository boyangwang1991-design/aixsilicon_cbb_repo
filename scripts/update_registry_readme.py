#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
update_registry_readme.py — 将 registry.yaml（SSOT）中的 CBB/IP 状态可视化刷新到 README.md

职责：
1. 加载 registry.yaml，统计 status / group / abstraction / priority 分布；
2. 生成「状态总览」 Markdown 区块（含已实现构件表 + 类别/抽象/优先级统计）；
3. 就地替换 README.md 中
   `<!-- REGISTRY-STATUS:BEGIN -->` 与 `<!-- REGISTRY-STATUS:END -->` 之间的内容；
   （无 marker 时退出并给出提示，避免破坏手工维护的其它 README 内容。）

与 build_cbb_structure.py 的关系：
- build_cbb_structure.py 负责 registry.yaml 本身的一致性校验/规范化（SSOT 写权限）；
- 本脚本负责**派生视图**（README.md 状态总览）的同步，属于『改 registry.yaml 后必须重跑的刷新脚本』。

用法:
  python3 scripts/update_registry_readme.py           # 校验并就地刷新 README.md
  python3 scripts/update_registry_readme.py --dry-run # 仅打印将写入的区块，不写文件
  python3 scripts/update_registry_readme.py --check   # 只读检查 README 是否与 registry 一致（退出码 1=不一致）

退出码：0=通过/已刷新；10=校验失败；20=用法错误；40=内部错误。
"""
import argparse
import os
import sys

try:
    import yaml
except ImportError:
    print("错误: 未找到 pyyaml —— 请用 workflow 根 uv 环境运行（本脚本依赖 yaml 模块）。")
    raise SystemExit(3)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY_PATH = os.path.join(ROOT, "registry.yaml")
README_PATH = os.path.join(ROOT, "README.md")

BEGIN_MARKER = "<!-- REGISTRY-STATUS:BEGIN -->"
END_MARKER = "<!-- REGISTRY-STATUS:END -->"

# 合法的枚举域（与 build_cbb_structure.py / schemas 保持一致）
VALID_ABSTRACTION = {"A0", "A1", "A2", "A3", "A4",
                     "A1/A0", "A1/A2", "A2/A3", "A2/A4", "A3/A4", "A0/A2"}
VALID_PRIORITY = {"P0", "P1", "P2", "P3"}
VALID_GROUP_TOPS = {"adapters", "components", "templates"}
VALID_STATUS = {"planned", "implemented"}

REQUIRED_FIELDS = ["id", "name", "family", "group", "abstraction",
                   "priority", "implementation", "description", "status", "version", "path"]


def _disp_width(s: str) -> int:
    """估算字符串显示宽度（中日韩全角按 2 计），用于 Markdown 表格源码对齐。"""
    width = 0
    for ch in s:
        if ord(ch) > 0x2E7F:  # CJK 等全角区
            width += 2
        else:
            width += 1
    return width


def _pad(s: str, width: int) -> str:
    """按显示宽度右补空格。"""
    return s + " " * max(0, width - _disp_width(s))


def load_registry(path=REGISTRY_PATH):
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict) or not isinstance(data.get("cbbs"), list):
        raise ValueError("registry.yaml 为空或缺少 cbbs 列表（文件可能损坏或未正确加载）")
    return data


def validate(reg):
    """轻量一致性校验（复用 build_cbb_structure 的规则子集），返回 (errors, warnings)。"""
    errors, warnings = [], []
    cbbs = reg.get("cbbs", [])
    if not isinstance(cbbs, list):
        errors.append("cbbs 必须是列表")
        return errors, warnings
    ids = set()
    for i, e in enumerate(cbbs):
        if not isinstance(e, dict):
            errors.append("[%d] 条目不是 object" % i)
            continue
        cid = e.get("id")
        if not cid:
            errors.append("[%d] 缺 id" % i)
        elif cid in ids:
            errors.append("id 重复: %s" % cid)
        else:
            ids.add(cid)
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
        if p:
            parts = p.split("/")
            if len(parts) < 2 or parts[0] not in VALID_GROUP_TOPS or p == gp or not p.startswith(gp + "/"):
                errors.append("[%s] path(%s) 与 group(%s) 不一致" % (cid, p, gp))
        if st == "implemented" and not os.path.isdir(os.path.join(ROOT, p)):
            errors.append("[%s] status=implemented 但目录不存在: %s" % (cid, p))
    return errors, warnings


def _md_table(headers, rows):
    """生成 Markdown 表格源码（按显示宽度对齐）。headers: list[str]; rows: list[list[str]]。"""
    cols = list(zip(headers, *rows))
    widths = [max(_disp_width(str(c)) for c in col) for col in cols]
    sep = "|" + "|".join("-" * (w + 2) for w in widths) + "|"
    lines = ["|" + "|".join(" %s " % _pad(str(c), w) for c, w in zip(headers, widths)) + "|",
             sep]
    for r in rows:
        lines.append("|" + "|".join(" %s " % _pad(str(c), w) for c, w in zip(r, widths)) + "|")
    return "\n".join(lines)


def build_status_section(reg):
    """从 registry 生成状态总览 Markdown 区块（不含 BEGIN/END marker）。"""
    cbbs = reg.get("cbbs", [])
    total = len(cbbs)
    impl = [e for e in cbbs if e.get("status") == "implemented"]
    planned = [e for e in cbbs if e.get("status") == "planned"]
    updated = reg.get("updated", "未知")

    lines = []
    lines.append("> 本节由 `scripts/update_registry_readme.py` 依据 `registry.yaml`（SSOT）自动生成。")
    lines.append("> 修改 `registry.yaml` 后必须运行 `python3 scripts/update_registry_readme.py` 刷新本节；勿手工编辑。")
    lines.append("> 最后更新：`%s`" % updated)
    lines.append("")
    lines.append("### 总览")
    lines.append("")
    lines.append(_md_table(
        ["指标", "数量"],
        [["总条目（cbbs）", str(total)],
         ["implemented（已实现/已交付）", str(len(impl))],
         ["planned（规划候选）", str(len(planned))],
         ["实现率", "%.1f%%" % (100.0 * len(impl) / total if total else 0.0)]],
    ))
    lines.append("")

    # 已实现构件表
    lines.append("### 已实现 / 已交付构件（%d）" % len(impl))
    lines.append("")
    if impl:
        impl_sorted = sorted(impl, key=lambda e: e.get("id", ""))
        rows = []
        for e in impl_sorted:
            rel = e.get("path", "")
            link = ("[%s](%s/README.md)" % (e.get("name", ""), rel)) if rel else e.get("name", "")
            rows.append([e.get("id", ""), link, e.get("family", ""),
                         e.get("abstraction", ""), e.get("priority", ""),
                         e.get("version", ""), e.get("group", "")])
        lines.append(_md_table(["ID", "构件", "构件族", "抽象", "优先级", "版本", "类别"], rows))
    else:
        lines.append("（当前无已实现构件）")
    lines.append("")

    # 按类别统计
    lines.append("### 按类别分布（implemented / planned）")
    lines.append("")
    cat_rows = []
    cats = {}
    for e in cbbs:
        cat = e.get("group", "(未分类)")
        cats.setdefault(cat, [0, 0])
        if e.get("status") == "implemented":
            cats[cat][0] += 1
        else:
            cats[cat][1] += 1
    for cat in sorted(cats):
        imp, pla = cats[cat]
        cat_rows.append([cat, str(imp), str(pla), str(imp + pla)])
    lines.append(_md_table(["类别", "implemented", "planned", "合计"], cat_rows))
    lines.append("")

    # 按抽象粒度统计
    lines.append("### 按抽象粒度分布")
    lines.append("")
    abs_rows = []
    abs_map = {}
    for e in cbbs:
        ab = e.get("abstraction", "?")
        abs_map.setdefault(ab, 0)
        abs_map[ab] += 1
    for ab in sorted(abs_map):
        abs_rows.append([ab, str(abs_map[ab])])
    lines.append(_md_table(["抽象", "数量"], abs_rows))
    lines.append("")

    # 按优先级统计
    lines.append("### 按优先级分布（implemented / planned）")
    lines.append("")
    pr_rows = []
    pr_map = {}
    for e in cbbs:
        pr = e.get("priority", "?")
        pr_map.setdefault(pr, [0, 0])
        if e.get("status") == "implemented":
            pr_map[pr][0] += 1
        else:
            pr_map[pr][1] += 1
    for pr in sorted(pr_map):
        imp, pla = pr_map[pr]
        pr_rows.append([pr, str(imp), str(pla), str(imp + pla)])
    lines.append(_md_table(["优先级", "implemented", "planned", "合计"], pr_rows))
    lines.append("")

    # 全部 CBB 明细表（覆盖每个 CBB：名称 / 状态 / 功能 等信息）
    # 按类别（group）拆分为多个子表格，便于阅读与导航。
    lines.append("### 全部 CBB 明细（%d，按类别拆分）" % total)
    lines.append("")
    by_group = {}
    for e in cbbs:
        by_group.setdefault(e.get("group", "(未分类)"), []).append(e)
    for group in sorted(by_group):
        entries = sorted(by_group[group], key=lambda x: x.get("id", ""))
        impl_n = sum(1 for x in entries if x.get("status") == "implemented")
        lines.append("#### %s（%d，implemented=%d）" % (group, len(entries), impl_n))
        lines.append("")
        rows = []
        for e in entries:
            rel = e.get("path", "")
            name_cell = ("[%s](%s/README.md)" % (e.get("name", ""), rel)) if rel else e.get("name", "")
            # 转义表格分隔符与换行，避免破坏 Markdown 表格
            desc = str(e.get("description", "") or "").replace("|", "\\|").replace("\n", " ")
            rows.append([
                e.get("id", ""),
                name_cell,
                e.get("family", ""),
                e.get("status", ""),
                e.get("abstraction", ""),
                e.get("priority", ""),
                e.get("version", ""),
                desc,
            ])
        lines.append(_md_table(
            ["ID", "名称", "构件族", "状态", "抽象", "优先级", "版本", "功能/描述"], rows))
        lines.append("")

    return "\n".join(lines) + "\n"


def refresh_readme(reg, readme_path=README_PATH, dry_run=False):
    """就地替换 README.md 中 marker 之间的状态总览。返回 (changed, new_readme)。"""
    with open(readme_path, encoding="utf-8") as f:
        readme = f.read()
    section = build_status_section(reg)
    block = "%s\n%s\n%s" % (BEGIN_MARKER, section, END_MARKER)

    if BEGIN_MARKER in readme and END_MARKER in readme:
        start = readme.index(BEGIN_MARKER)
        end = readme.index(END_MARKER) + len(END_MARKER)
        new_readme = readme[:start] + block + readme[end:]
    else:
        print("错误: README.md 中缺少 %s / %s marker，无法安全定位刷新区。" % (BEGIN_MARKER, END_MARKER))
        print("请在 README.md 中放置该 marker（建议放在「当前已交付构件」章节内）。")
        raise SystemExit(20)

    changed = new_readme != readme
    if not dry_run:
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(new_readme)
    return changed, new_readme


def main():
    ap = argparse.ArgumentParser(description="将 registry.yaml 状态可视化同步到 README.md（派生视图刷新脚本）")
    ap.add_argument("--dry-run", action="store_true", help="只打印将写入的区块，不写文件")
    ap.add_argument("--check", action="store_true", help="只读检查 README 是否与 registry 一致（退出码 1=不一致）")
    args = ap.parse_args()

    try:
        reg = load_registry()
    except (yaml.YAMLError, ValueError) as exc:
        print("ERROR: %s" % exc)
        raise SystemExit(10)
    errors, warnings = validate(reg)
    for w in warnings:
        print("  WARN: %s" % w)
    for e in errors:
        print("  ERROR: %s" % e)
    if errors:
        print("==> registry.yaml 校验失败（%d 个错误），不刷新 README。" % len(errors))
        raise SystemExit(10)

    if args.dry_run:
        print(build_status_section(reg))
        return

    changed, _ = refresh_readme(reg, dry_run=args.dry_run)
    if args.check:
        if changed:
            print("==> README.md 状态总览与 registry.yaml 不一致（需要刷新）。")
            raise SystemExit(1)
        print("==> README.md 状态总览与 registry.yaml 一致。")
        return

    if changed:
        print("==> README.md 状态总览已刷新（%d 条，implemented=%d）。" % (
            len(reg.get("cbbs", [])),
            sum(1 for e in reg.get("cbbs", []) if e.get("status") == "implemented")))
    else:
        print("==> README.md 状态总览已是最新，无需变更。")


if __name__ == "__main__":
    main()
