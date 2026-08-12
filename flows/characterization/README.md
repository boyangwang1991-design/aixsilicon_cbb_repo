# 表征流程（Characterization）

PPA 表征端到端流程（架构文档第 6 节），由 `Characterization Runner` 驱动。

## 步骤

1. 读取 CBB 的 `characterization/plan.yaml`（参数采样 + 基准环境）
2. 锚点扫描 → 边界扫描 → 自适应补点
3. 综合 / STA / 功耗分析，绑定 `benchmark_profile_id`
4. 结果归档到 `characterization/baselines/`（原始数据经 `run_id` 关联）

## 当前状态

空（规划中）。基准环境定义见 [`docs/ppa/README.md`](../../docs/ppa/README.md:1)。
