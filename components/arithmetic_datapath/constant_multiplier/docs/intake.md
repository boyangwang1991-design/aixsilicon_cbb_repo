# constant_multiplier — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | <有/无> |
| 独立驱动 / 固件 / 复杂系统状态机 | <有/无> |
| 定制方式 | <参数与端口> |
| 复用面 | <被哪些 IP/Subsystem 用作内部模块> |
| 行为契约 + 有限属性可否完整描述 | <是/否> |
| **判定** | **<CBB，抽象粒度 <A?>>** |

> 若存在 CBB→IP 升级趋势（完整寄存器模型/复杂事务/独立中断/软件契约）请在此注明。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| <同族构件 1，如 QUE-003 fall_through_fifo> | <不同/复用/无重叠 + 一句理由> |
| <同族构件 2> | <…> |
| **结论** | **<新增 / 复用 / 扩展>** |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| <子 CBB 名> | <已实现 / 未命中建议新增 / 已登记未实现> | <引用 VLNV / 新增 registry 条目 / 串行实现 / 按主套件授权规则委派（记录见 run_log）> |

> 依赖方向单向、防环（domain-rules §4.1）；依赖执行和委派授权遵循主套件规则，不因缺少子代理而停止已授权实现。

## 4. 消费者与使用场景

| 场景 | 说明 |
|---|---|
| <场景 1> | <如 窄总线写宽存储> |
| <场景 2> | <如 宽读分拍窄出> |

## 5. 风险与成熟度

| 项 | 值 |
|---|---|
| 风险等级 | <P0–P3 + 一句话理由> |
| 起始成熟度 | E0 |
| 主要风险 | <风险 1 / 风险 2，及由哪个 Gate 消解> |

## 6. Owner / 审批

- Owner：`aixsilicon:cbb`
- approvals：rtl-owner（RTL 修改）、dv-owner（验证计划）、<其它按需>

## 7. 执行深度

- Loop：<fast / standard / qualification>（依据 cbb_class + risk + change_type）
- 执行模式：<full-flow / partial-task / review-only>