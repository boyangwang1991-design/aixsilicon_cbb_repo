# Schema Validator

校验元数据、参数域、依赖和发布信息（架构文档 10.1 节，P0）。

## 规划功能

- 校验 `cbb.yaml` 符合 [`schemas/`](../../schemas/README.md:1) 定义的 Schema
- 校验参数合法域（支持的参数组合、禁止组合、最大推荐规模）
- 校验依赖（FuseSoC 约束语法）与发布信息
- 校验 `registry.yaml` 索引一致性

## 状态

规划中（空工程包）。结构：`src/`、`tests/`、`docs/`。
