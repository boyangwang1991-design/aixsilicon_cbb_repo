# clock_reset_power — 时钟、复位、功耗与高扇出优化

对应 cbb_repo_list.md 第 11 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| CRP-001 | Local Clock Enable | A1/A0 | P0 | 门控粒度与工具识别 |
| CRP-002 | Hierarchical Clock Gating Controller | A2 | P1 | ICG共享与扇出 |
| CRP-003 | Auto Clock Gating Detector | A2 | P2 | 收益阈值与唤醒 |
| CRP-004 | Clock Divider | A2 | P1 | 占空比与毛刺 |
| CRP-005 | Clock Switch Controller | A2 | P1 | 切换握手和无时钟场景 |
| CRP-006 | Clock Request/Acknowledge | A2 | P1 | 启停延迟 |
| CRP-007 | Reset Synchronizer | A1 | P0 | RDC签核属性 |
| CRP-008 | Reset Filter/Deglitch | A2 | P2 | 外部复位噪声 |
| CRP-009 | Reset Cause Collector | A2 | P1 | 软件可观测性 |
| CRP-010 | Reset Distribution Helper | A2 | P1 | 高扇出和局部化 |
| CRP-011 | Operand Isolation | A1/A2 | P1 | 动态功耗与时序代价 |
| CRP-012 | Data Gating | A1/A2 | P1 | 毛刺和翻转抑制 |
| CRP-013 | Pipeline Freeze Controller | A2 | P1 | 状态一致性与唤醒 |
| CRP-014 | Idle Detector | A2 | P1 | 检测功耗和误判 |
| CRP-015 | Activity Detector | A2 | P1 | 监控开销 |
| CRP-016 | Power-domain Handshake | A2 | P2 | UPF状态序列 |
| CRP-017 | Isolation Control Sequencer | A2 | P2 | 安全时序 |
| CRP-018 | Retention Control Sequencer | A2 | P2 | 数据完整性 |
| CRP-019 | Memory Sleep Controller | A2 | P2 | break-even与唤醒 |
| CRP-020 | High-fanout Replicator | A2 | P1 | 功能等价与物理收益 |
| CRP-021 | Config Mirror/Local Decode | A2 | P1 | 布线与寄存器面积 |
| CRP-022 | Enable Tree Helper | A2 | P1 | 时钟周期与控制对齐 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
