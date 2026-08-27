# SpyGlass Lint Waiver — popcount 0.1.0

## 运行结论（2026-08-27, evidence/g3_static/spyglass_lint.txt）

- Goal: `lint/lint_rtl`（GuideWare rtl_handoff methodology）
- 结果: **0 Fatal / 0 Error / 0 Warning / 2 Info**
- Top: `popcount`；四文件（wrapper + 三 impl）全部解析成功
- `set_option enableSV09 yes` 已在项目文件固化（SV int 参数类型支持）

## Waiver 判定

无需 waiver —— 全量干净。2 条 information 级消息为 Design Read 的
top-module 发现提示，非设计缺陷。

## 复现

```bash
cd <cbb_root> && spyglass -project lint_work/lint.prj -batch -goals lint/lint_rtl
```
