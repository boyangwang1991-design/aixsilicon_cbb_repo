# incrementer_decrementer — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无 |
| 独立驱动 / 固件 / 复杂系统状态机 | 无（纯组合 ±1 运算器，无状态机） |
| 定制方式 | 参数（位宽、微架构）+ 端口（递增/递减使能） |
| 复用面 | Counter/地址发生器/指针递增、循环索引更新、步进计数器；被多 IP/Subsystem 复用 |
| 行为契约 + 有限属性可否完整描述 | 是（±1 模回绕运算，有限属性可证） |
| **判定** | **CBB，抽象粒度 A1（原子数据通路算子，纯组合）** |

> 无 CBB→IP 升级趋势（无寄存器模型/事务管理/中断/软件契约）。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| `ARI-002 adder_subtractor` | 不同——通用加/减法器（任意加数）；本构件为 **±1 专用**，Counter 场景面积/时序更优 |
| `ARI-005 adder_tree` | 不同——多操作数归约树；本构件单操作数 ±1 |
| `CTL-*/MON-* counter` | 不同——带时钟/寄存的周期计数（有状态）；本构件为纯组合 ±1 原语，供 Counter 调用 |
| **结论** | **新增**（ARI-001 在 registry 中为 planned 独立条目，无既有实现） |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| 无 | — | 纯组合单算子，无嵌套子 CBB 依赖 |

> 无运行时子依赖；`implementations[].dependencies[]` 为空。

## 4. 消费者与使用场景

| 场景 | 说明 |
|---|---|
| Counter 步进 | 每周期 +1/-1 的计数器状态更新（Counter 专用优化，替代通用加法器） |
| 指针/索引 | 环形缓冲读写指针、FIFO 地址步进 |
| 循环控制 | 循环计数、饱和计数前的溢出/借位判定（carry_out 供级联/饱和） |

## 5. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| 递增到全 1 或递减到 0 的回绕语义被误用 | 低 | 契约明确定义模回绕 + carry_out 溢出/借位标志 |
| inc_en 与 dec_en 同时断言 | 低 | 行为假设 ASM-003 + TB 激励约束 |
| ripple 关键路径 O(W) 长 | 中 | segmented 分段进位实现提供时序更优变体，G6 综合实证 Pareto |
| 多实现等价性 | 低 | ripple/segmented 共享契约，等价仿真 + 参考模型 |

## 6. Gate 判定

- **G0 通过**：边界清晰（A1 CBB）、查重无重复、无嵌套依赖、消费者明确、风险可控。
