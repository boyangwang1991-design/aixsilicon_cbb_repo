# apb_ahb_register — APB/AHB/寄存器接口构件

对应 cbb_repo_list.md 第 14 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| BUS-001 | Generic CSR Bus Adapter | A3 | P0 | 内部统一接口 |
| BUS-002 | APB Slave Adapter | A3 | P0 | 低面积与时序 |
| BUS-003 | APB Register Slice | A3 | P1 | PREADY返回路径 |
| BUS-004 | APB Decoder | A3 | P0 | 地址译码与PREADY Mux |
| BUS-005 | APB Mux/Interconnect | A3/A4 | P1 | 规模与共享路径 |
| BUS-006 | APB CDC Bridge | A3 | P1 | 低吞吐CDC优化 |
| BUS-007 | APB Width Adapter | A3 | P2 | Byte strobe与跨拍 |
| BUS-008 | APB Timeout/Default Slave | A3 | P0 | 防挂死与低开销 |
| BUS-009 | AHB-Lite Slave Adapter | A3 | P1 | 地址/数据相位 |
| BUS-010 | AHB-Lite Register Slice | A3 | P1 | HREADY路径 |
| BUS-011 | AHB-Lite Decoder/Mux | A3 | P2 | 响应Mux时序 |
| BUS-012 | AHB-Lite CDC Bridge | A3 | P2 | 相位与响应 |
| BUS-013 | AHB↔APB Bridge | A3/A4 | P1 | Buffer与时钟比 |
| BUS-014 | CSR Shadow/Commit Adapter | A3 | P1 | 配置一致性 |
| BUS-015 | CSR Access Policy Filter | A3 | P1 | 译码与安全策略 |
| BUS-016 | Register Broadcast Adapter | A3 | P2 | 高扇出优化 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
