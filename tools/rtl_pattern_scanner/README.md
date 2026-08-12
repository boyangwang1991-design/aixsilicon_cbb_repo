# RTL Pattern Scanner

识别可替换热点并匹配 CBB（架构文档 10.1 节，P2）。

## 规划功能

- 解析 RTL，识别大 Mux、深优先级链、Ready 长链、高扇出、重复运算、可共享资源
- 匹配 CBB 库并给出替换/重构建议（replacement proposals）
- 为 AI PPA Advisor 提供输入

## 状态

规划中（空工程包）。结构：`src/`、`tests/`、`docs/`。
