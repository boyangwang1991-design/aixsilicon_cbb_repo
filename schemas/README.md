# schemas — 元数据与结果 Schema

定义 `cbb.yaml` 与 PPA 结果数据的 Schema，作为机器可读 SSOT 的权威来源
（架构文档第 8 节）。

## 规划内容

| 文件 | 说明 |
| --- | --- |
| `cbb.schema.yaml` | `cbb.yaml` 的 JSON/YAML Schema（分类、契约、参数、实现、质量、表征、发布） |
| `characterization.schema.yaml` | 表征计划（`plan.yaml`）Schema：参数采样、基准环境、扫描策略 |
| `result.schema.yaml` | PPA 结果 Schema：`run_id`、`dataset_version`、面积/时序/功耗、置信信息 |
| `recipe.schema.yaml` | 优化配方 Schema：条件、组合、规则、证据 |
| `registry.schema.yaml` | `registry.yaml` 索引条目 Schema |

## 说明

- 模板参考：[`docs/cbb_spec/template/cbb.yaml`](../docs/cbb_spec/template/cbb.yaml:1)
- Schema 由 `Schema Validator` 工具消费（见 [`tools/README.md`](../tools/README.md:1)）
- 当前各 Schema 文件待开发时填充
