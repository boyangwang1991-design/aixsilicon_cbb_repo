# cdc_rdc — CDC、RDC 与多时钟域

对应 cbb_repo_list.md 第 10 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| CDC-001 | Single-bit Synchronizer | A1 | P0 | MTBF、属性、布局 |
| CDC-002 | Multi-bit Static Synchronizer | A1/A2 | P0 | 仅适用于静态配置总线 |
| CDC-003 | Pulse Synchronizer | A2 | P0 | 脉宽与连续脉冲间隔 |
| CDC-004 | Toggle Synchronizer | A2 | P0 | 事件丢失边界 |
| CDC-005 | Handshake Synchronizer | A2 | P0 | 延迟、吞吐、复位 |
| CDC-006 | Bundled-data CDC | A2 | P1 | 数据稳定窗口和约束 |
| CDC-007 | Bus Snapshot CDC | A2 | P1 | 原子采样 |
| CDC-008 | Gray Counter CDC | A2 | P0 | 最大跳变与约束 |
| CDC-009 | Async FIFO | A2 | P0 | 指针、满空、复位 |
| CDC-010 | Mesochronous Elastic Buffer | A2 | P3 | 同频异相场景 |
| CDC-011 | Plesiochronous Rate Matcher | A2 | P3 | 频偏吸收 |
| CDC-012 | Clock-domain Event Aggregator | A2 | P1 | 同时事件和扇入 |
| CDC-013 | Clock-domain Config Bridge | A2/A3 | P1 | 一致性与低频配置 |
| RDC-001 | Async Assert/Sync Release Reset | A1 | P0 | 复位恢复/移除时间 |
| RDC-002 | Fully Synchronous Reset Bridge | A2 | P1 | 域间顺序 |
| RDC-003 | Reset Pulse Stretcher | A1/A2 | P0 | 最短复位周期 |
| RDC-004 | Reset Domain Isolation | A2 | P1 | 失复位域影响隔离 |
| RDC-005 | Reset Sequencer | A2/A4 | P1 | 扇出、启动延迟 |
| RDC-006 | Warm/Cold Reset Controller | A2/A4 | P2 | 状态保留边界 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
