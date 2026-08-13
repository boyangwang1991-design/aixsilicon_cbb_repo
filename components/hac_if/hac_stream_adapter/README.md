# HAC-STRM-001 HAC-STREAM 到 AXI4-Stream Adapter

> 分组：HAC 接口适配（A3）　优先级：P1
> 状态：规划中（空工程包，仅需求说明）

## 需求说明

- 构件族：HAC-STREAM → AXI4-Stream Adapter
- 主要实现变体：input adapter / output adapter / credit-based
- PPA 关注点：背压处理、keep 映射、包边界

### 功能契约

- HAC-STREAM `valid/ready/data/keep/last/id/user` 与 AXI4-Stream `TVALID/TREADY/TDATA/TKEEP/TLAST/TID/TUSER` 语义映射；
- 支持独立输入和输出通道；
- Credit-based Adapter（可选）；
- 多虚通道（可选）；
- CRC/Parity 旁带状态（可选）。

### 成熟度

- [ ] E0 Concept
- [ ] E1 Functional
- [ ] E2 Verified
- [ ] E3 Characterized
- [ ] E4 Released

### PPA 表征计划

（待补充：基准环境、参数扫描计划）

> 开发时按 [docs/cbb_spec](../../../docs/cbb_spec/README.md) 展开标准工程包。
