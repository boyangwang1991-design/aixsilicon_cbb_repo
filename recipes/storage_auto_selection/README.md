# Recipe：存储自动选型

按深度/位宽/频率/延迟自动选择存储实现（架构文档 4.3 节）。

## 选型边界

| 条件 | 候选方向 |
| --- | --- |
| 小深度、小位宽、低延迟 | Register / Fall-through |
| 中等深度、无合适 Macro | Register Array 或 Shift 结构 |
| 大深度 | SRAM / Banked SRAM |
| 高频跨层接口 | 前后增加 Slice 或分离 Ready 路径 |
| 双时钟域 | 受控 Async FIFO 实现 |
| 低功耗长空闲 | Memory Sleep + 局部门控 |

## 涉及构件（规划）

- TEC-015 SRAM Macro Wrapper
- QUE-001 Synchronous FIFO、QUE-002 Asynchronous FIFO
- STR-004/005/006 Register Slice、QUE-007 Skid Buffer

## 当前状态

空（规划中）。待补充：具体阈值与 PPA 证据。
