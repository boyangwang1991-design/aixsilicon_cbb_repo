# CBB Selector

硬约束过滤、候选排序、理由输出（架构文档 10.1 节，P1）。

## 规划功能

- 输入统一为选型请求（function / technology / parameters / constraints / objectives）
- 基于 Catalog 与 PPA 数据检索候选，返回 `recommended` / `alternatives` / `rejected_with_reason`
- 输出：实测/预测标识与置信信息、预期 PPA、依赖与集成清单、生成后的 FuseSoC/RTL Manifest

## 状态

规划中（空工程包）。结构：`src/`、`tests/`、`docs/`。
