# Changelog — skid_buffer

## [0.1.0] - 2026-08-28

### Added
- Valid-Ready Skid Buffer（QUE-007，A3/P0）：OUT 寄存 + SKID 槽，切断 ready 组合链，
  满吞吐无气泡、FIFO 保序；
- G3 静态基线：VCS 正向编译矩阵（DATA_W∈{1,8,32,64,128}）+ 负向 `$error` 拦截；
- G4 功能仿真：tc_random / tc_backpressure / tc_edge（DATA_W∈{32,1}，固定 seed）；
- G6 PPA：DC 400MHz tt corner 真实综合（DATA_W∈{8,32,128}），面积线性、时序余量充裕；
- 契约 SSOT：`cbb.yaml` / `behavior.yaml` / `profiles`（内嵌）/ RTM（11 条）；
- 配置集由 `config-gen` 确定性生成（verification/configs/）。
