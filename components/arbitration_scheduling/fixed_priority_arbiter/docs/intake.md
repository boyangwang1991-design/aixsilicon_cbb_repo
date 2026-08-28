# fixed_priority_arbiter — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无 |
| 独立驱动 / 固件 / 复杂系统状态机 | 无 |
| 定制方式 | 参数与端口（NUM_REQ/PRIORITY/REQ_TYPE/FAST_GRANT/PC_IMPL） |
| 复用面 | SoC interconnect / axi_mux / request arbiter / 多路资源共享仲裁 |
| 行为契约 + 有限属性可否完整描述 | 是（授权互斥/优先级/无请求→0/锁存/寄存，INV-001..005） |
| **判定** | **CBB，抽象粒度 A2（通用复合：仲裁机制，非协议绑定）** |

> 无 CBB→IP 升级趋势（无 CSR/软件契约/系统生命周期）。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| ARB-002 round_robin_arbiter | 不同——轮转公平调度（本 CBB 为固定优先级） |
| ARB-007 multi_grant_arbiter | 不同——top-K 多授权（本 CBB 单授权互斥） |
| ARB-008 hierarchical_arbiter | 不同——跨模块层次仲裁（本 CBB 单级） |
| ARB-001 fixed_priority_arbiter | **本条目（registry 已登记 planned，本次物化）** |
| **结论** | **物化已有条目（ARB-001）** |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| （无——A2 原子仲裁器，不调用其它 CBB） | — | 无依赖（`implementations[].dependencies[]` 为空） |

## 4. Owner / 消费者 / 风险

| 项 | 值 |
|---|---|
| Owner | `aixsilicon:cbb` |
| 消费者 | SoC interconnect、axi_mux（AXI-021）、request arbiter、多路资源共享调度 |
| 优先级（Registry） | P0（基础构件，被多 IP 复用） |
| 风险 | 低-中——组合仲裁语义明确；latched 活锁由消费方保证（ASM-002）；REQ_TYPE/FAST_GRANT 时序需验证 |

## 5. 非目标（non-goals）

- 轮转/加权/公平性调度（RR/WRR/Deficit，ARB-002/003/004）
- 多授权（top-K，ARB-007）、层次仲裁（ARB-008）
- 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍）
