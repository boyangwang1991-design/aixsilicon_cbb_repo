# CBB 材料清理归档（2026-09-13）

此目录保存历史原文，不是当前开发指令或验证基线。

- `cleanup-2026-09.md`：早期 298 项清单与跨仓迁移记录；现行数量以 registry 为准。
- `cleanup-validation.md`：当时的测试与 APB 迁移验证，不能替代本仓当前验证。
- `stale-materials-audit.md`：早期混合 IP/CBB 材料排查及报告边界修复记录。
- `retired-assets.full.yaml`：精简前完整退出记录。恢复详细规划时按 records[].original.name 查找，再复核当前归属；现行处置以 governance/retired-assets.yaml 为准。
- `changes.json`：本轮移动文件的原路径、新路径和 SHA-256；删除项仅为零字节 ucli.key。

审查范围为 CBB 仓根及全部 components/adapters 工程的非构建文件（1024 个文件，排除 .git、build、缓存和已有 archive）。297 个登记目录齐全，无未登记 components 工程目录。现有需求、实现、验证/PPA 计划、发布清单和工程内证据仍有关联，保留原位；不按日期删除。构建缓存未作为文档处理。

保留 governance 的运行约束、CHANGELOG 历史、停用初始化入口的拒绝保护。分类正文已落实 AXI 单通道归 IP，现行导航不再指向旧报告路径。

## 验证

归档文件 SHA-256 一致；114 条退役记录的处置/迁移/恢复字段和保留身份逐项一致。registry、README 派生视图、297 份需求合同检查通过。额外运行当前 CBB Skill 回归得到 48 passed / 13 failed：失败均发生于其 CLI 引用缺失的 impl.execution 模块。本轮未修改 Skill 文件，不将该套件状态记为全绿。
