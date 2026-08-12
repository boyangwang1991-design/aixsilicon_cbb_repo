# arbitration_scheduling — 仲裁、调度、共享与流控

对应 cbb_repo_list.md 第 9 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| ARB-001 | Fixed-priority Arbiter | A2 | P0 | 优先级链 |
| ARB-002 | Round-robin Arbiter | A2 | P0 | 规模扩展、翻转 |
| ARB-003 | Weighted RR Arbiter | A2 | P2 | 权重状态与公平性 |
| ARB-004 | Deficit RR Arbiter | A2 | P3 | 加法状态与包长 |
| ARB-005 | Age-based Arbiter | A2 | P3 | 比较网络面积 |
| ARB-006 | Lottery/Random Arbiter | A2 | P3 | 随机质量与验证 |
| ARB-007 | Multi-grant Arbiter | A2 | P2 | 多授权组合复杂度 |
| ARB-008 | Hierarchical Arbiter | A2 | P1 | 大规模请求时序 |
| ARB-009 | Pipelined Arbiter | A2 | P1 | 延迟与满吞吐 |
| ARB-010 | Packet-locking Arbiter | A2/A3 | P1 | 锁定状态与公平性 |
| ARB-011 | Credit Manager | A2 | P0 | 计数一致性和位宽 |
| ARB-012 | Token Allocator | A2 | P1 | 分配/回收时序 |
| ARB-013 | Resource Pool Manager | A2 | P2 | 容量、并行分配 |
| ARB-014 | Request Coalescer | A2 | P2 | 比较网络和Buffer |
| ARB-015 | Request Distributor | A2 | P2 | 均衡度与路由逻辑 |
| ARB-016 | Shared Operator Scheduler | A2/A4 | P1 | 资源面积与排队延迟 |
| ARB-017 | Bank Conflict Resolver | A2 | P1 | 冲突率和吞吐 |
| ARB-018 | Outstanding Tracker | A2 | P1 | 容量与匹配逻辑 |
| ARB-019 | Reservation/Lock Manager | A2 | P3 | 死锁与状态开销 |
| ARB-020 | Barrier/Join Controller | A2 | P2 | 参与者数量与扇入 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
