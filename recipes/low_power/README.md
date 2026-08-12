# Recipe：低功耗

面向空闲/低活动场景的功耗优化。

## 场景

- 数据不变检测、Operand Isolation、输入保持
- 无效流水级冻结、FIFO 空闲门控、Memory Bank 休眠
- 分层时钟门控、局部更新、Gray 编码状态/计数传递、Toggle-aware 编码

## 涉及构件（规划）

- TEC-005 ICG Wrapper、TEC-015 SRAM Macro Wrapper
- CRP-016 Power-domain Handshake、QUE-001 Synchronous FIFO
- CRP-002 Hierarchical Clock Gating、CTL-008 FSM Shell

## 当前状态

空（规划中）。待补充：适用条件、组合方式、PPA 收益证据。
