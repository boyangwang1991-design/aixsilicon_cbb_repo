# recipes — 参考架构与优化配方

描述多个 CBB 如何组合、以及在什么条件下采用何种结构的**配方资产**（非可实例化 CBB）。

## 配方目录

| 配方 | 说明 |
| --- | --- |
| [`resource_sharing/`](resource_sharing/README.md:1) | 资源共享：共享乘法器/除法器、多端口访问单口 SRAM、时分复用 |
| [`width_optimization/`](width_optimization/README.md:1) | 位宽优化：最小位宽推导、位宽裁剪、符号扩展消除 |
| [`fanout_optimization/`](fanout_optimization/README.md:1) | 高扇出优化：控制复制、分层广播、Enable Tree、分区 Reset |
| [`low_power/`](low_power/README.md:1) | 低功耗：Operand Isolation、流水级冻结、Bank 休眠、分层门控 |
| [`high_performance/`](high_performance/README.md:1) | 高性能：长路径切分、Balanced Tree、Speculative Ready、预授权 |
| [`storage_auto_selection/`](storage_auto_selection/README.md:1) | 存储自动选型：Register / Shift / SRAM FIFO 切换边界 |

## 配方形态

每个配方应说明：

- 适用条件与组合的 CBB
- 选型/优化规则
- 预期 PPA 收益与验证证据
- 风险与失败边界

## 当前状态

各配方目录为空（规划中）。开发时按各配方 README 补充，配方内容也可由 AI PPA Advisor 驱动生成。
