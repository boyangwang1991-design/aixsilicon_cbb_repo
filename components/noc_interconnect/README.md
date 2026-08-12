# noc_interconnect — NoC、片间与高级互联公共构件

对应 cbb_repo_list.md 第 16 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| NOC-001 | Flit Packer/Unpacker | A3 | P2 | Mux、字段映射 |
| NOC-002 | Virtual-channel FIFO | A3 | P2 | RAM利用率与头阻塞 |
| NOC-003 | VC Allocator | A3 | P3 | 仲裁规模 |
| NOC-004 | Switch Allocator | A3 | P3 | 关键路径核心 |
| NOC-005 | NoC Input Port | A3/A4 | P3 | 面积和流控 |
| NOC-006 | NoC Output Port | A3/A4 | P3 | 扇入与信用返回 |
| NOC-007 | Crossbar Fabric | A2/A3 | P2 | 布线、Mux、流水 |
| NOC-008 | Route Compute | A2/A3 | P3 | 组合延迟 |
| NOC-009 | Credit Return Channel | A3 | P2 | 反馈延迟与位宽 |
| NOC-010 | Link Register Slice | A3 | P1 | 长距离切时序 |
| NOC-011 | Link CDC Adapter | A3 | P2 | 时钟关系 |
| NOC-012 | Link Width Converter | A3 | P2 | Buffer与延迟 |
| NOC-013 | Link CRC/Replay Shell | A3 | P3 | 可靠性和Buffer |
| NOC-014 | Link Power-state Handshake | A3 | P2 | 低功耗序列 |
| NOC-015 | Deadlock/Progress Monitor | A3 | P3 | 观测开销 |
| NOC-016 | CHI/ACE Channel Slice | A3 | P3 | 一致性协议专项验证 |
| NOC-017 | Chiplet Streaming Adapter | A3 | P3 | 不替代PHY/标准协议IP |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
