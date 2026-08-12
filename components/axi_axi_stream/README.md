# axi_axi_stream — AXI4/AXI4-Lite/AXI-Stream 构件

对应 cbb_repo_list.md 第 15 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| AXI-001 | AXI Channel Register Slice | A3 | P0 | 五通道独立切时序 |
| AXI-002 | AXI-Lite Register Slice | A3 | P0 | 小面积低延迟 |
| AXI-003 | AXI Buffer | A3 | P1 | Outstanding与背压 |
| AXI-004 | AXI Data Width Converter | A3 | P1 | Burst、strobe、unaligned |
| AXI-005 | AXI Address Width Adapter | A3 | P1 | 地址合法性 |
| AXI-006 | AXI ID Width Converter | A3 | P1 | ID表面积和并发 |
| AXI-007 | AXI User Signal Adapter | A3 | P2 | 固定字段裁剪 |
| AXI-008 | AXI Burst Splitter | A3 | P1 | 状态与吞吐 |
| AXI-009 | AXI Burst Merger/Coalescer | A3 | P2 | 比较、Buffer、顺序 |
| AXI-010 | AXI Burst Length Adapter | A3 | P2 | 地址推进 |
| AXI-011 | AXI Outstanding Limiter | A3 | P1 | 计数器和阻塞 |
| AXI-012 | AXI ID Remapper | A3 | P2 | 表容量与匹配 |
| AXI-013 | AXI Transaction Serializer | A3 | P1 | 面积换并发 |
| AXI-014 | AXI Read/Write Interleaver | A3 | P3 | 顺序规则复杂度 |
| AXI-015 | AXI Clock Converter | A3 | P0 | 全通道CDC正确性 |
| AXI-016 | AXI Protocol Converter | A3 | P1 | Burst拆分与错误 |
| AXI-017 | AXI-to-APB Bridge | A3/A4 | P1 | 队列、译码、时钟 |
| AXI-018 | AXI-to-AHB Bridge | A3/A4 | P2 | 顺序和响应映射 |
| AXI-019 | AXI Address Decoder | A3 | P0 | 比较和路由关键路径 |
| AXI-020 | AXI Demux | A3 | P1 | 响应路由状态 |
| AXI-021 | AXI Mux | A3 | P1 | 五通道仲裁与锁定 |
| AXI-022 | AXI Crossbar | A4 | P2 | 面积、布线、并发 |
| AXI-023 | AXI Default Slave | A3 | P0 | 无目标响应 |
| AXI-024 | AXI Timeout Monitor | A3 | P1 | 表项和恢复策略 |
| AXI-025 | AXI Firewall/Region Filter | A3 | P2 | 安全策略与关键路径 |
| AXI-026 | AXI Exclusive Access Monitor | A3 | P3 | 表项与一致性范围 |
| AXI-027 | AXI Atomic Adapter | A3 | P3 | 原子性和锁定 |
| AXI-028 | AXI QoS Mapper | A3 | P2 | 配置和仲裁衔接 |
| AXI-029 | AXI Performance Monitor | A3 | P1 | 被动观测开销 |
| AXI-030 | AXI Error Injector | A3 | P2 | 验证模式隔离 |
| AXIS-001 | AXI-Stream Register Slice | A3 | P0 | Ready路径 |
| AXIS-002 | AXI-Stream Width Converter | A3 | P1 | TKEEP/TLAST对齐 |
| AXIS-003 | AXI-Stream Switch | A3/A4 | P2 | 包锁定与路由 |
| AXIS-004 | AXI-Stream Packet FIFO | A3 | P1 | 包边界与容量 |
| AXIS-005 | AXI-Stream Broadcaster | A3 | P2 | Ready汇聚 |
| AXIS-006 | AXI-Stream Combiner/Subset | A3 | P2 | Lane映射 |
| AXIS-007 | AXI-Stream Frame Length Monitor | A3 | P2 | 低开销检查 |
| AXIS-008 | AXI-Stream Rate Limiter | A3 | P2 | 吞吐整形 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
