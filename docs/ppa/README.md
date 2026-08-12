# PPA 数据体系

> 核心观点（[`docs/architecture/README.md`](../architecture/README.md:1) 第 6 节）：
> **没有统一基准，跨构件或跨版本的 PPA 数据不可比较。** 任何 PPA 数据都必须绑定
> `benchmark_profile_id`（工艺/库/工具版本/PVT/约束/活动场景）。
>
> 最终目标是可靠回答：*在指定工艺、位宽、吞吐、延迟、频率、功耗模式和接口约束下，
> 哪些构件实现可行，哪几个处于 Pareto 前沿，应选择哪一个，选择依据和验证证据是什么？*

## 统一基准环境（6.1 节）

固定并版本化：

- 工艺与标准单元库代号、综合/STA/功耗工具及版本
- PVT、RC Corner、工作电压、时钟周期、uncertainty、IO delay、transition/load
- Max fanout / transition / Dont-use 列表、综合选项（retiming、physical-aware 等）
- 活动率来源与功耗窗口、测试 Harness 与约束模板

## 表征维度（6.2 节）

| 维度 | 典型取值 |
| --- | --- |
| 实现 | linear / tree / pipelined / register / sram 等 |
| 功能参数 | width / depth / ports / clients / IDs |
| 性能参数 | pipeline stages / latency / throughput |
| 工艺环境 | technology / PVT / RC corner |
| 约束 | target clock / IO delay / load |
| 活动场景 | idle / typical / stress / 业务 Trace |
| 工具环境 | tool / version / recipe / library revision |
| 结果 | area / WNS/TNS / Fmax / leakage / internal / switching |

功耗至少分 Leakage、Internal、Switching；动态功耗必须同时保存活动场景与采样窗口。

## 控制组合爆炸（6.3 节）

- 锚点扫描 → 边界扫描 → 自适应补点
- 原始测量与拟合模型分开保存；模型输出必须含误差/置信信息

## 数据存放

- 每个 CBB 的 PPA 数据在其标准工程包 `characterization/`（`plan.yaml` + `baselines/`）中
- 原始结果通过 `run_id` / `dataset_version` 关联，不塞入 `cbb.yaml`

## 工具链支撑

| 工具 | 作用 |
| --- | --- |
| Characterization Runner | 参数采样、综合、STA、功耗、结果归档 |
| PPA Comparator | 跨实现/参数/版本比较，生成 Pareto 前沿 |
| CBB Selector | 硬约束过滤、候选排序、理由输出 |
| PPA Regression Bot | 检测退化与 Pareto 变化 |
| AI PPA Advisor | 解释热点、生成方案并驱动闭环（结果须工具证据确认） |

详见 [`tools/README.md`](../../tools/README.md:1)。
