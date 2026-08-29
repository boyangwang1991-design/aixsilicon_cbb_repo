# round_robin_arbiter — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无 |
| 独立驱动 / 固件 / 复杂系统状态机 | 无 |
| 定制方式 | 参数与端口（NUM_REQ/REQ_TYPE/FAST_GRANT/PC_IMPL/GUARANTEED_FAIRNESS 等） |
| 复用面 | SoC interconnect、axi_mux（AXI-021）、request arbiter、多路资源共享调度、TDMA 式轮转 |
| 行为契约 + 有限属性可否完整描述 | 是（授权互斥/轮转公平/无请求→0/锁存/寄存/无饿死，INV-001..006） |
| **判定** | **CBB，抽象粒度 A2（通用复合：仲裁机制，非协议绑定）** |

> 无 CBB→IP 升级趋势（无 CSR/软件契约/系统生命周期）。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| ARB-001 fixed_priority_arbiter | 不同——固定优先级（本 CBB 为轮转公平调度，无静态优先） |
| ARB-003 weighted_rr_arbiter | 不同——带权轮转（quota/WRR；本 CBB 等权公平） |
| ARB-004 deficit_rr_arbiter | 不同——Deficit RR（包长量子；本 CBB 单请求粒度） |
| ARB-008 hierarchical_arbiter | 不同——跨模块层次仲裁（本 CBB 单级） |
| ARB-002 round_robin_arbiter | **本条目（registry 已登记 planned，本次物化）** |
| **结论** | **物化已有条目（ARB-002）** |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| （无——A2 原子仲裁器，不调用其它 CBB） | — | 无依赖（`implementations[].dependencies[]` 为空） |

## 4. Owner / 消费者 / 风险

| 项 | 值 |
|---|---|
| Owner | `aixsilicon:cbb` |
| 消费者 | SoC interconnect、axi_mux（AXI-021）、request arbiter、多路资源共享调度、TDMA 轮转 |
| 优先级（Registry） | P0（基础构件，被多 IP 复用） |
| 风险 | 低-中——轮转状态机语义明确；REQ_TYPE/FAST_GRANT 时序需验证；指针回绕与寄存器授权结合时的公平窗口需证明 |

## 5. 非目标（non-goals）

- 带权轮转（WRR/quota，ARB-003）、Deficit RR（包长量子，ARB-004）
- 多授权（top-K，ARB-007）、层次仲裁（ARB-008）
- 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍）
- 年龄/时间戳公平（ARB-005 age_based_arbiter）
