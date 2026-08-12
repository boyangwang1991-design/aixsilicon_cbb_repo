# streaming_pipeline — 流水、Ready/Valid 与流处理

对应 cbb_repo_list.md 第 8 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| STR-001 | Fixed Delay Line | A1/A2 | P0 | 延迟、面积、初始化 |
| STR-002 | Enable Delay Line | A1/A2 | P1 | 空闲功耗 |
| STR-003 | Data/Control Aligner | A2 | P0 | 控制数据一致性 |
| STR-004 | Forward Register Slice | A3 | P0 | 数据关键路径 |
| STR-005 | Backward Register Slice | A3 | P0 | 反压关键路径 |
| STR-006 | Full Register Slice | A3 | P0 | 双向切时序 |
| STR-007 | Bypassable Register Slice | A3 | P1 | 模式Mux与验证 |
| STR-008 | Stream Mux | A3 | P0 | 选择与反压 |
| STR-009 | Stream Demux | A3 | P0 | 输出Ready聚合 |
| STR-010 | Stream Fork | A3 | P1 | 复制和阻塞语义 |
| STR-011 | Stream Join | A3 | P1 | 同步等待与Buffer |
| STR-012 | Stream Merge | A3 | P1 | 仲裁与包锁定 |
| STR-013 | Stream Split | A3 | P2 | 状态与边界 |
| STR-014 | Stream Width Converter | A3 | P1 | Gearbox与跨拍状态 |
| STR-015 | Stream Gearbox | A3 | P2 | 相位、吞吐、布线 |
| STR-016 | Stream Rate Matcher | A3 | P2 | 速率与Buffer深度 |
| STR-017 | Stream Packetizer | A3 | P2 | 包头Mux与CRC衔接 |
| STR-018 | Stream Depacketizer | A3 | P2 | 解析关键路径 |
| STR-019 | Stream Arbiter | A3 | P1 | 公平性和切换气泡 |
| STR-020 | Stream Multicast | A3 | P2 | Ready汇聚与复制 |
| STR-021 | Stream Broadcaster | A3 | P1 | 高扇出与物理距离 |
| STR-022 | Stream Throttler | A3 | P2 | 控制翻转和精度 |
| STR-023 | Stream Traffic Shaper | A3 | P3 | 速率状态和突发 |
| STR-024 | Stream Monitor Tap | A3 | P2 | 零干扰与观测开销 |
| STR-025 | Bubble Inserter/Remover | A3 | P3 | 时序整形 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
