# register_memory — 寄存器、存储器与存储映射

对应 cbb_repo_list.md 第 6 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| MEM-001 | Parameter Register | A1 | P0 | Enable推断与时钟功耗 |
| MEM-002 | Shadowed Register | A2 | P1 | 安全一致性与面积 |
| MEM-003 | Sticky/W1C/W1S Register | A1/A2 | P0 | 软件语义与门数 |
| MEM-004 | Register Array | A2 | P0 | 推断RAM或FF阵列 |
| MEM-005 | 1R1W Register File | A2 | P1 | 读延迟、RAW bypass |
| MEM-006 | Multi-read Register File | A2 | P1 | 面积与端口冲突 |
| MEM-007 | Multi-write Register File | A2 | P2 | 写冲突与旁路 |
| MEM-008 | SRAM Width Composer | A2 | P0 | Macro利用率与mask |
| MEM-009 | SRAM Depth Composer | A2 | P0 | 译码/输出Mux关键路径 |
| MEM-010 | SRAM Bank Mapper | A2 | P1 | 冲突率、地址逻辑 |
| MEM-011 | SRAM Port Adapter | A2 | P1 | 冲突语义与吞吐 |
| MEM-012 | Memory RAW Bypass | A2 | P0 | 数据一致性与Mux延迟 |
| MEM-013 | Memory Byte-write Adapter | A2 | P1 | RMW周期与功耗 |
| MEM-014 | Memory Init/Load Adapter | A2 | P2 | 仿真与综合一致性 |
| MEM-015 | Memory Sleep/Retention Controller | A2 | P2 | break-even时间、唤醒 |
| MEM-016 | Memory ECC Shell | A2 | P1 | 延迟、容量、可靠性 |
| MEM-017 | Memory Scrubber | A2 | P2 | 带宽占用、功耗 |
| MEM-018 | Memory BIST Interface Adapter | A2 | P2 | DFT接口与功能隔离 |
| MEM-019 | Multi-bank Access Scheduler | A2 | P2 | Bank冲突与吞吐 |
| MEM-020 | Ping-pong Buffer | A2 | P1 | 读写重叠与容量 |
| MEM-021 | Line Buffer | A2 | P2 | 图像/卷积带宽 |
| MEM-022 | Circular Buffer | A2 | P1 | 地址简化与满空判定 |
| MEM-023 | Lookup Table/ROM | A1/A2 | P1 | 深宽映射与推断 |
| MEM-024 | CAM | A2 | P3 | 并行比较功耗 |
| MEM-025 | Content Tag Array | A2 | P3 | Cache/TLB公共结构 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
