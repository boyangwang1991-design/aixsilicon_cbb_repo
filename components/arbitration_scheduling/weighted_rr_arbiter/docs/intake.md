# weighted_rr_arbiter — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无 |
| 独立驱动 / 固件 / 复杂系统状态机 | 无 |
| 定制方式 | 参数与端口（NUM_REQ/WEIGHT_WIDTH/WMODE/FAST_GRANT/GRANT_ACK_EN/PC_IMPL） |
| 复用面 | 带宽分配调度、流量整形、多路 QoS 仲裁、共享资源加权公平访问、SoC interconnect 加权轮转 |
| 行为契约 + 有限属性可否完整描述 | 是（授权互斥/权重公平/quota 窗口/smooth credit/无请求→0/寄存/ack 锁定，INV-001..006） |
| **判定** | **CBB，抽象粒度 A2（通用复合：加权仲裁机制，非协议绑定）** |

> 无 CBB→IP 升级趋势（无 CSR/软件契约/系统生命周期）。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| ARB-001 fixed_priority_arbiter | 不同——固定优先级（本 CBB 按权重公平，无静态固定优先） |
| ARB-002 round_robin_arbiter | 不同——等权轮转（本 CBB 带权，按权重比例公平） |
| ARB-004 deficit_rr_arbiter | 不同——Deficit RR（包长/字节量子；本 CBB 单请求粒度 + 权重） |
| ARB-005 age_based_arbiter | 不同——年龄/时间戳公平（本 CBB 权重比例） |
| ARB-006 lottery_arbiter | 不同——随机/抽奖（本 CBB 确定性加权） |
| ARB-008 hierarchical_arbiter | 不同——跨模块层次仲裁（本 CBB 单级） |
| ARB-003 weighted_rr_arbiter | **本条目（registry 已登记 planned，本次物化）** |
| **结论** | **物化已有条目（ARB-003）** |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| （无——A2 原子加权仲裁器，不调用其它 CBB） | — | 无依赖（`implementations[].dependencies[]` 为空） |

## 4. Owner / 消费者 / 风险

| 项 | 值 |
|---|---|
| Owner | `aixsilicon:cbb` |
| 消费者 | 带宽分配调度、流量整形、多路 QoS 仲裁、共享资源加权公平访问、SoC interconnect 加权轮转 |
| 优先级（Registry） | P2（可复用构件，带宽/QoS 场景） |
| 风险 | 中——权重公平语义（quota vs smooth）需明确界定；quota 窗口重置时机、平滑 credit 跨轮累计的正确性需证明；权重 0/无请求边界需覆盖 |

## 5. 非目标（non-goals）

- Deficit RR（包长量子，ARB-004）、年龄/时间戳公平（ARB-005）、随机/抽奖（ARB-006）
- 多授权（top-K，ARB-007）、层次仲裁（ARB-008）
- 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍）
- 运行时权重热更新（weight_i 静态/低频配置）
