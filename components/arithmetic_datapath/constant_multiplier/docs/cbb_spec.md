# constant_multiplier 规格说明（G1 可读视图）

> **派生视图**：SSOT 为 [`cbb.yaml`](../cbb.yaml)（+[`behavior.yaml`](../behavior.yaml)），本文件仅为人工程序可读副本，**语义以 YAML 为准**（不双维护）。

## 1. 定位

<一句话定位 + 分类>

- 抽象粒度：`<A?>（<A2/A3 组合可写组合值>）`
- 技术域：`<primary_domain>`（次：`<secondary_domains>`）
- Registry ID：`<QUE-xxx / SEL-xxx / ...>`

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） |
|---|---|---|---|
| REQ-001 | <一句话> | `PROP-<NAME>-001` | tc_xxx |
| REQ-002 | <一句话> | `PROP-<NAME>-002` | tc_xxx |

> 完整映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)（工具生成）。

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `<PARAM_A>` | int | `<default>` | `<min~max>` | <一句话> |
| `<PARAM_B>` | enum | `<default>` | `[<v1>, <v2>]` | <一句话> |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | `<expr>` | <防什么，如 防零宽/防死锁/防越界> |
| PC-00x | `<expr>` | <…> |

> 非法组合在 Elaboration 前被拦截（`cbb_tool.py check` + RTL `$error` generate 双拦截）。

## 4. 行为不变量（INV）与假设（ASM）

- 不变量：`INV-001` <无丢失> / `INV-00x` <…>
- 时序：首拍延迟 `<N>`；满吞吐 `<是/否 + 条件>`；背压传播 `<N>` 拍
- 假设：`ASM-001` <无界背压> / `ASM-00x` <…>
- 异常：复位释放后 <行为>；满/空时 <行为>

## 5. 接口与时钟复位

- 接口：`<ready_valid / AXI / APB ...>`（引用 HWIF 契约 `<aixsilicon:hwif:*>`）
- 端口：<简要列出关键端口组>
- 时钟：`<N>` 个（`clk`）；复位：`<sync/async> rst_n`（低有效）

## 6. 假设与非目标（non-goals）

| 项 | 内容 |
|---|---|
| 非目标 1 | <如 非整比 gearbox / 多时钟域 CDC / 乱序> |
| 非目标 2 | <…> |

## 7. 集成限制

- 限制 1：<如 `DEPTH>=RATIO` 强制>
- 限制 2：<宽侧位宽 ≤ N bit>
- 用途建议：<consumer 场景 1 / 场景 2>

## 8. 追踪

需求→属性→测试→配置映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)；验证形态与矩阵见
[`verification/plan.yaml`](../verification/plan.yaml) 与 [`verification/configs/`](../verification/configs/)。
## 编码、同时事件与采样审查

| 审查项 | 应明确的契约 |
|---|---|
| 资产/顶层 | cbb.name、registry 路径、contract.top_module、source_contract 的对应关系 |
| 控制编码 | 位宽是否足以编码全部目标；enable/保留值/关闭语义 |
| 同拍事件 | reset、clear、新 fault 的优先级以及历史状态保留策略 |
| 比较时刻 | 输入、mask、valid 的所属时刻，延迟与启动窗口 |
| 结果流水 | 采样相位和延迟，enable 撤销/复位对已捕获结果的处理 |
| 负向参数 | 宿主原始值校验、SV 转换后可诊断范围及资源安全边界 |

只对构件实际存在的机制填写；无关项注明不适用，不为模板新增功能。
