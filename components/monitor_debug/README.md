# monitor_debug — 监控、调试、性能与可观测性

对应 cbb_repo_list.md 第 17 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| MON-001 | Event Counter | A1/A2 | P0 | 位宽和门控 |
| MON-002 | Multi-event Counter Bank | A2 | P1 | 多事件更新与面积 |
| MON-003 | Cycle/Busy/Idle Counter | A2 | P0 | 时钟功耗 |
| MON-004 | Latency Monitor | A2/A3 | P1 | 表项和量化 |
| MON-005 | Bandwidth Monitor | A2/A3 | P1 | 计数位宽 |
| MON-006 | Occupancy Monitor | A2 | P1 | 除法与采样近似 |
| MON-007 | Stall/Backpressure Monitor | A3 | P1 | 信号扇入 |
| MON-008 | Activity/Toggle Sampler | A2 | P2 | PPA数据采集开销 |
| MON-009 | Trace Event Encoder | A2 | P2 | 编码与带宽 |
| MON-010 | Trace FIFO | A2 | P2 | 容量和观测影响 |
| MON-011 | Trace Funnel | A3 | P2 | 仲裁与排序 |
| MON-012 | Trigger/Qualifier | A2 | P2 | 比较网络 |
| MON-013 | Snapshot Register Bank | A2 | P1 | 面积和采样一致性 |
| MON-014 | Protocol Progress Monitor | A3 | P2 | 误报和状态开销 |
| MON-015 | Performance Counter CSR Adapter | A3 | P1 | 统一软件接口 |
| MON-016 | Lightweight Logic Analyzer Shell | A4 | P3 | 调试配置按需裁剪 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
