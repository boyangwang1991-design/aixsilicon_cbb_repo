# interrupt_safety — 中断、错误与功能安全公共构件

对应 cbb_repo_list.md 第 13 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| SAF-001 | Parity-protected Register | A2 | P1 | 面积与读写延迟 |
| SAF-002 | ECC-protected Memory Shell | A2 | P1 | 纠错路径和带宽 |
| SAF-003 | Dual Modular Comparator | A2 | P2 | 比较覆盖与延迟 |
| SAF-004 | Lockstep Alignment Buffer | A2 | P2 | 双核对齐与状态 |
| SAF-005 | Lockstep Comparator | A2 | P2 | 比较宽度与错误延迟 |
| SAF-006 | Temporal Redundancy Controller | A2 | P3 | 性能开销 |
| SAF-007 | TMR Voter | A1/A2 | P3 | 面积、共因失效边界 |
| SAF-008 | Safety Mechanism Bypass/Mode | A2 | P2 | 安全状态与测试 |
| SAF-009 | Fault Injection Point | A1/A2 | P1 | 综合隔离和验证 |
| SAF-010 | Error Status Latch | A2 | P0 | 信息保留与面积 |
| SAF-011 | Error Aggregator | A2 | P0 | 扇入、延迟、去重 |
| SAF-012 | Error Router | A2 | P1 | 高扇出和配置 |
| SAF-013 | Error Escalation Controller | A2 | P2 | 状态和响应延迟 |
| SAF-014 | Alarm Handler Core | A4 | P2 | 接近IP，需边界治理 |
| SAF-015 | Bus Transaction Monitor | A3 | P1 | 插入延迟与观测覆盖 |
| SAF-016 | End-to-end Protection Codec | A3 | P2 | 带宽、延迟、标准配置 |
| SAF-017 | Duplicate/Sequence Checker | A2/A3 | P2 | 窗口容量 |
| SAF-018 | Alive/Heartbeat Monitor | A2 | P1 | 误报和监控时钟 |
| SAF-019 | Clock Monitor Digital Shell | A2 | P2 | 参考时钟与计数误差 |
| SAF-020 | Reset Monitor | A2 | P2 | RDC与安全状态 |
| SAF-021 | Voltage/Temperature Monitor Wrapper | A0/A2 | P3 | 模拟监控器接口 |
| SAF-022 | Safe-state Controller | A2/A4 | P2 | 失效响应时间 |
| SAF-023 | Memory Address/Data Protection | A2 | P2 | 存储与延迟开销 |
| SAF-024 | Latent Fault Test Controller | A2 | P3 | 业务中断与覆盖 |
| SAF-025 | Safety Counter Checker | A1/A2 | P2 | 诊断覆盖与面积 |
| SAF-026 | Safety FSM Checker | A1/A2 | P1 | 编码与综合保持 |
| SAF-027 | Interrupt Source Conditioner | A2 | P0 | PIC前端复用重点 |
| SAF-028 | Interrupt Aggregator | A2 | P0 | 大位宽扇入 |
| SAF-029 | Interrupt Router | A2/A3 | P1 | 到CLIC/安全岛双送 |
| SAF-030 | Interrupt Rate Limiter | A2 | P2 | 中断风暴控制 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
