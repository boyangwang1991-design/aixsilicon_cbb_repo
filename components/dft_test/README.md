# dft_test — DFT、测试与可制造性辅助

对应 cbb_repo_list.md 第 18 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| DFT-001 | Test-mode Synchronizer | A1 | P1 | 功能/测试模式隔离 |
| DFT-002 | Scan-enable Distribution Helper | A2 | P2 | 高扇出与CTS |
| DFT-003 | Clock-control Test Override | A0/A2 | P1 | DFT与无毛刺 |
| DFT-004 | Reset-control Test Override | A2 | P1 | RDC与测试顺序 |
| DFT-005 | MBIST Port Arbiter | A2 | P2 | Mux延迟和隔离 |
| DFT-006 | LBIST/MISR | A2 | P3 | 面积和切换峰值 |
| DFT-007 | PRPG | A2 | P3 | 随机模式与功耗 |
| DFT-008 | Signature Comparator | A1/A2 | P3 | 测试数据路径 |
| DFT-009 | Test Access Mux | A3 | P2 | 功能路径零影响目标 |
| DFT-010 | Memory Repair Data Adapter | A2 | P3 | 工艺相关元数据 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
