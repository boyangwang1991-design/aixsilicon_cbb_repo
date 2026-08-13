# HAC-LMEM-001 SRAM/Bank/ECC Adapter

> 分组：HAC 接口适配（A3）　优先级：P1
> 状态：规划中（空工程包，仅需求说明）

## 需求说明

- 构件族：HAC-LMEM → SRAM/Bank/ECC Adapter
- 主要实现变体：LMEM-FIXED（固定 1/2 周期）、LMEM-DECOUPLED（请求/响应解耦）
- PPA 关注点：读延迟、bank 冲突、ECC 面积

### 功能契约

- HAC-LMEM `req/rsp` 到 Foundry SRAM Macro 端口适配；
- 多 Bank 映射与仲裁（可选）；
- SECDED ECC 编解码与 `ecc_corrected/ecc_uncorrectable` 上报（可选）；
- `sleep/retention` 仅在 Memory Wrapper 侧出现；
- 原则上 HAC Core 不直接绑定 Foundry Macro 端口，由本 Adapter 完成 Macro 适配、ECC 与修复控制。

### 成熟度

- [ ] E0 Concept
- [ ] E1 Functional
- [ ] E2 Verified
- [ ] E3 Characterized
- [ ] E4 Released

### PPA 表征计划

（待补充：基准环境、参数扫描计划）

> 开发时按 [docs/cbb_spec](../../../docs/cbb_spec/README.md) 展开标准工程包。
