# 仓库管理元数据

- `reserved-ids.yaml`：名称与稳定 ID 预留表，校验器用于阻止改号和编号复用。
- `retired-assets.yaml`：退出/迁移条目的最小运行索引，校验器与 cbb-development-suite scaffold 用于阻止误恢复；保留身份、处置、文件位置和迁移目标。

完整旧规划已移至 [历史快照](../docs/archive/2026-09-cbb-materials-review/retired-assets.full.yaml)，仅在显式恢复时按 original.name 查找。恢复必须先复核需求及归属，再同步处置状态和 registry；归档记录不会自动重新生成资产。

这两个 YAML 是有效管理输入，不是实现清单；当前资产清单只有根 registry.yaml。
