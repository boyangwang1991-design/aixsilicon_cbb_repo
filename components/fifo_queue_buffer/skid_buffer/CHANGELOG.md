# Changelog — skid_buffer

## [0.2.0] - 2026-08-29

### Added（多实现 profile）
- 参数 `IMPL`（0=forward 简单打拍 / 1=full 满吞吐 skid，默认）与 `BYPASS`（1=组合零延迟直通）；
- RTL 拆分：wrapper（`rtl/skid_buffer.sv`）+ `rtl/impl/forward/` + `rtl/impl/full/`（各自极简单，含 SVA）；
- G4 功能仿真扩展 4 配置（full32/fwd32/bypass32/full1，tc_fwd_*/tc_bypass）；
- G6 PPA 多实现对比（run-20260829-01）：forward 面积 ≈ full 的 1/3、slack 更大，
  full 满吞吐 + 短反压路径，BYPASS 面积≈0；reg→reg worst slack 主判据；
- 契约 SSOT 更新：REQ-001..006 / INV-001..006 / config-gen 21 配置 / RTM 16 条。

## [0.1.0] - 2026-08-28

### Added
- Valid-Ready Skid Buffer（QUE-007，A3/P0）：OUT 寄存 + SKID 槽，切断 ready 组合链，
  满吞吐无气泡、FIFO 保序；
- G3 静态基线：VCS 正向编译矩阵（DATA_W∈{1,8,32,64,128}）+ 负向 `$error` 拦截；
- G4 功能仿真：tc_random / tc_backpressure / tc_edge（DATA_W∈{32,1}，固定 seed）；
- G6 PPA：DC 400MHz tt corner 真实综合（DATA_W∈{8,32,128}），面积线性、时序余量充裕；
- 契约 SSOT：`cbb.yaml` / `behavior.yaml` / `profiles`（内嵌）/ RTM（11 条）；
- 配置集由 `config-gen` 确定性生成（verification/configs/）。
