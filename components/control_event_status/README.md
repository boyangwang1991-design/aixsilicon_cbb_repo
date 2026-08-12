# control_event_status — 控制、计数、事件与状态管理

对应 cbb_repo_list.md 第 12 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| CTL-001 | Up/Down Counter | A1 | P0 | 最小位宽、切换功耗 |
| CTL-002 | Modulo Counter | A1 | P0 | 比较与回绕 |
| CTL-003 | Timestamp Counter | A1/A2 | P1 | 位宽、跨域采样 |
| CTL-004 | Timer | A2 | P0 | Prescaler共享 |
| CTL-005 | Timeout Monitor | A2 | P0 | 监控开销与恢复 |
| CTL-006 | Watchdog | A2 | P1 | 安全诊断覆盖 |
| CTL-007 | Prescaler/Rate Divider | A1/A2 | P1 | 精度和切换 |
| CTL-008 | FSM Shell | A1/A2 | P0 | 编码按表征选型 |
| CTL-009 | Hierarchical FSM | A2 | P2 | 状态爆炸控制 |
| CTL-010 | Micro-sequencer | A2 | P2 | 控制ROM与可配置性 |
| CTL-011 | Command Sequencer | A2 | P2 | 状态与Buffer |
| CTL-012 | Retry Controller | A2 | P2 | 活锁与计数器 |
| CTL-013 | Event Edge Detector | A1 | P0 | CDC前后使用约束 |
| CTL-014 | Pulse Stretcher/Compressor | A1 | P0 | 最小脉宽 |
| CTL-015 | Event Collector | A2 | P0 | 事件丢失语义 |
| CTL-016 | Event Router | A2 | P1 | Mux、扇出和配置 |
| CTL-017 | Event Debouncer/Filter | A2 | P2 | 延迟和外部输入 |
| CTL-018 | Token/Credit Counter | A2 | P0 | 上下溢保护 |
| CTL-019 | Sequence Number Manager | A2 | P2 | 回绕比较 |
| CTL-020 | Bitmap Allocator | A2 | P1 | 查找与更新关键路径 |
| CTL-021 | Free-list Manager | A2 | P2 | 多分配/回收 |
| CTL-022 | Scoreboard | A2 | P2 | CAM/bitmap权衡 |
| CTL-023 | Dependency Tracker | A2 | P3 | 状态规模 |
| CTL-024 | Quiesce/Drain Controller | A2 | P1 | 低功耗与复位切换 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
