# flows — 表征、回归和发布流程

CBB 平台的关键流程（架构文档第 6、7、9 节）。

## 目录

| 目录 | 说明 |
| --- | --- |
| [`characterization/`](characterization/README.md:1) | PPA 表征流程：参数采样、综合、STA、功耗、结果归档 |
| [`regression/`](regression/README.md:1) | PPA 回归：与基线比较，检测面积/频率/功耗退化 |
| [`release/`](release/README.md:1) | 发布流程：SemVer、FuseSoC Core、Manifest、Catalog 更新 |

## 关键原则

- 统一基准环境，任何数据绑定 `benchmark_profile_id`
- 原始测量与拟合模型分开保存
- 工具/库版本变化时重建新基线，不与旧环境混判
- 端到端链路：资产定义 → 验证 → 表征 → 发布 → 检索 → 选型 → 集成 → PPA 回归

## 当前状态

各流程目录为空（规划中），由对应工具驱动（见 [`tools/README.md`](../tools/README.md:1)）。
