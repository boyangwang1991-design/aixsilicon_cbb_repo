# PPA Comparator

跨实现、参数和版本比较，生成 Pareto 前沿（架构文档 10.1 节，P0）。

## 规划功能

- 先硬约束过滤（功能/协议/工艺/参数/频率/吞吐/延迟/质量门禁）
- 对可行实现计算 Area/Power/Latency 等 Pareto 前沿
- 仅在用户给出偏好后使用加权目标排序
- 输出 `recommended`、`alternatives`、`rejected_with_reason` 三组结果

## 状态

规划中（空工程包）。结构：`src/`、`tests/`、`docs/`。
