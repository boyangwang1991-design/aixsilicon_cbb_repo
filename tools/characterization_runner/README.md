# Characterization Runner

参数采样、综合、STA、功耗、结果归档（架构文档 10.1 节，P0）。

## 规划功能

- 三阶段采样：锚点扫描 → 边界扫描 → 自适应补点
- 调用综合/STA/功耗工具，绑定 `benchmark_profile_id`
- 结果归档到 CBB 的 `characterization/baselines/`，原始数据通过 `run_id` 关联

## 状态

规划中（空工程包）。结构：`src/`、`tests/`、`docs/`。
