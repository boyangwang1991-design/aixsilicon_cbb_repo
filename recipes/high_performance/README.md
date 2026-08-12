# Recipe：高性能

面向高频/高吞吐场景的时序优化。

## 场景

- 长组合路径切分、Balanced Tree、Look-ahead 控制
- Speculative Ready、请求预测与预授权、分布式仲裁
- 地址译码流水化、输出旁路、多 Bank 并行、控制/数据路径解耦

## 涉及构件（规划）

- ARI-002 Adder/Subtractor、SEL-009 Priority Encoder、SEL-011 Leading Zero/One Count
- ARI-005 Adder Tree、ARB-002 Round-robin Arbiter
- STR-004/005/006 Register Slice、QUE-007 Skid Buffer

## 当前状态

空（规划中）。待补充：适用条件、组合方式、PPA 收益证据。
