# accumulator — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无（无软件可见寄存器体系） |
| 独立驱动 / 固件 / 复杂系统状态机 | 无（单状态数据通路，无完整事务状态机） |
| 定制方式 | 参数与端口（INPUT_WIDTH/ACC_WIDTH/SIGNED/OP_MODE/OVERFLOW_MODE/LOAD_EN/STATUS_EN/OPERAND_ISOLATION） |
| 复用面 | DSP/NPU 部分和累加、事件求和、积分/误差累计、NCO 相位累加（被多个 IP 用作内部核心） |
| 行为契约 + 有限属性可否完整描述 | 是（INV-001..005 完整描述状态与事件语义） |
| **判定** | **CBB，抽象粒度 A2**（参数化数据通路构件，带状态） |

> 无 CBB→IP 升级趋势：不引入软件寄存器、总线事务或中断，保持局部累加核心边界。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| ARI-001 incrementer_decrementer | 不同——±1 专用模回绕，无任意加数/装载/饱和/状态；累加器为通用 A±X |
| ARI-002 adder_subtractor | 不同——纯组合任意 A/B 加减，无状态反馈、无溢出 sticky |
| ARI-011 saturating_add_sub | 不同——组合饱和加减，无累加状态、无 II=1 逐拍语义 |
| **结论** | **新增**（registry 已有 ARI-006 planned 条目，无同族已实现构件重叠） |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| （无） | — | V1.0 基线单实现，不嵌套调用其它 CBB；MAC 乘法前级、reduction tree 为外部组合，不进入核心边界 |

> 依赖方向单向、防环（domain-rules §4.1）；本 CBB 无运行时子依赖，`implementations[].dependencies[]` 为空。

## 4. 消费者与使用场景

| 场景 | 说明 |
|---|---|
| DSP/NPU 部分和累加 | 乘积先扩位、小数点对齐后作为 data_i |
| 事件权重/字节数/能量求和 | 通用 A±X 累加（单纯 +1 用专用 counter） |
| 有符号积分/误差累计 | 需明确饱和（SATURATE）与回绕（WRAP）行为 |
| NCO 相位累加 | 模 2^W 回绕，无符号，可关状态输出（STATUS_EN=false） |

## 5. 风险与成熟度

| 项 | 值 |
|---|---|
| 风险等级 | P0（核心数据通路，被多消费者复用） |
| 起始成熟度 | E0 |
| 主要风险 | A→A 反馈路径时序（进位传播+饱和+选择）；由 G4 功能/等价 + G6 PPA 消解 |

## 6. Owner / 审批

- Owner：`aixsilicon:cbb`
- approvals：rtl-owner（RTL 修改）、dv-owner（验证计划）

## 7. 执行深度

- Loop：standard（`workflow-plan` 依据 stateful 族 + P0 risk 判定）
- 执行模式：full-flow（C0 Intake → C1 Specify → C2 Architect → C3 Implement → C4 Verify 已完成）
