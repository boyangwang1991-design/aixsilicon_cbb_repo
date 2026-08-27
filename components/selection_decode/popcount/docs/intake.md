# popcount — Intake（G0）

> 生命周期 C0 产物。SSOT：Registry 状态见 [`registry.yaml`](../../../registry.yaml)
> （SEL-014，owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无 |
| 独立驱动 / 固件 / 复杂系统状态机 | 无（纯组合函数式构件） |
| 定制方式 | 参数与端口（INPUT_WIDTH / CHUNK_W） |
| 复用面 | ECC 编解码、性能/事件计数、调度权重、DSP 峰值检测等多 IP 内部模块 |
| 行为契约 + 有限属性可否完整描述 | 是（Hamming 权重 + 数值域边界可全枚举表述） |
| **判定** | **CBB，抽象粒度 A1（原子机制）** |

无 CBB→IP 升级趋势。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| SEL-014 popcount（registry 自身条目） | planned、无物理目录 —— 本次即为其首次物化 |
| 同组 SEL-001~020 其余 selection_decode 构件 | 无重叠（mux/decoder/checker 类，非计数原语） |
| ARI-003 carry_save_adder / ARI-004 multi_operand_adder | planned；且本构件无需嵌套调用（内部压缩属微架构细节，不外引） |
| 已实现构件（仓库当前全部 planned） | 无同名/同义已实现资产 |
| **结论** | **新增物化 SEL-014**（status planned → implemented 的路径见 CHANGELOG/Gate 流程） |

## 3. 嵌套依赖解析

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| （无）运行时依赖 | — | `dependencies: []`；验证依赖亦空（TB/SVA 随包自足，不强依赖 VIP/dv_common） |

依赖方向单向性自动满足（零依赖）。

## 4. 消费者与使用场景

| 场景 | 说明 |
|---|---|
| ECC/校验 | Hamming/ECC 编码器生成校验位前的权重计算 |
| 性能计数 | 事件向量活跃位统计（PRF 忙碌标记、credit 余量） |
| 调度/仲裁 | 权重队列占用量汇总输入 WRR/WFQ 决策 |
| DSP/AI datapath | 稀疏掩码密度估计、峰值检测前处理 |

## 5. 风险与成熟度

| 项 | 值 |
|---|---|
| 风险等级 | P1（功能性风险低——函数语义明确；主要风险在多实现等价性与综合收敛质量） |
| 起始成熟度 | E0 |
| 主要风险 | R1 大位宽 column_compress 面积失控 → G6 Sweep 实证消解；R2 三实现等价性缺口 → G4 fm_shell LEC 消解 |

## 6. Owner / 审批

- Owner：`aixsilicon:cbb`
- approvals：rtl-owner（RTL）、dv-owner（验证计划）、ppa-owner（表征结论）

## 7. 执行深度

- Loop：standard（新增 CBB、结构层面三实现，风险 P1）
- 执行模式：full-flow（G0→G8 依序，本文档阶段推进到方案冻结即为暂停点）

## 8. 冻结与评审状态（2026-08-27）

- 方案冻结稿完成于 [`design.md`](design.md)；实施等待线下评审结论；
- 用户决策记录：选项 D"先冻结为文档、评审后再动 RTL"（区别于 A/B/C 实施方案选择）；
- 评审关注点建议：
  1. 三实现是否维持或裁剪（若只保 2 个，`impl_lookup` 优先裁剪候补）；
  2. `CHUNK_W` 是否保留为公共参数或固化 8（影响 config-gen 空间）；
  3. G6 Pareto 消费场景优先级（area 优先还是 fmax 优先 → 推荐 Profile 排序）。
