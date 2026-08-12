# Recipe：资源共享

多通道/多请求方共享昂贵资源（架构文档 4.x 与 plan.md 第三节）。

## 场景

- 多通道共享乘法器、多请求方共享除法器
- 多端口访问单口 SRAM、运算单元时分复用
- 控制逻辑复用、配置寄存器共享与影子寄存器
- 并行处理与串行复用的可切换架构

## 涉及构件（规划）

- ARB-002 Round-robin Arbiter、ARI-017 Integer Multiplier、QUE-001 Synchronous FIFO
- STR-008 Stream Mux / STR-009 Stream Demux

## 当前状态

空（规划中）。待补充：适用条件、组合方式、PPA 收益证据。
