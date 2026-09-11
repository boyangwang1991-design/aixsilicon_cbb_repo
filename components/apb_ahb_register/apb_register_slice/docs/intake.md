# apb_register_slice — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无 |
| 独立驱动 / 固件 / 复杂系统状态机 | 无（仅流水/打拍状态位） |
| 定制方式 | 参数与端口（ADDR_WIDTH/DATA_WIDTH/SLICE_MODE/RESP_STAGES） |
| 复用面 | APB interconnect、APB↔CSR bridge、远程慢速外设接入、apb_decoder/apb_mux 间物理隔离 |
| 行为契约 + 有限属性可否完整描述 | 是（相位保持/固定反馈延迟/反馈对齐/前向打拍/复位清洁，INV-001..006） |
| **判定** | **CBB，抽象粒度 A3（协议构件：APB 握手语义绑定）** |

> 无 CBB→IP 升级趋势（无 CSR/软件契约/系统生命周期）。
> 与 HWIF 边界：本构件为**信号级 APB 透传**（flattened 信号端口），不引用/不创建
> SV interface；APB 协议契约本身归 `aixsilicon_hwif_repo`（CBB 内只体现绑定语义，
> 见 [非目标](#5-非目标non-goals)）。

## 2. 查重（registry.yaml / Catalog）

| 候选 | 结论 |
|---|---|
| BUS-002 apb_slave_adapter | 不同——从侧协议适配（握手转 ready-valid 类），非返回路径打拍 |
| BUS-004 apb_decoder | 不同——地址译码与 PREADY mux |
| BUS-010 ahb_lite_register_slice | 不同——AHB-Lite 协议绑定（本构件为 APB） |
| AXI-002 axi_lite_register_slice | 不同——AXI-Lite 通道结构（5 通道 valid/ready），非 APB 相位 |
| BUS-003 apb_register_slice | **本条目（registry 已登记 planned，本次物化）** |
| **结论** | **物化已有条目（BUS-003）** |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| （无——纯打拍透传，不调用其它 CBB） | — | 无依赖（`implementations[].dependencies[]` 为空） |

## 4. Owner / 消费者 / 风险

| 项 | 值 |
|---|---|
| Owner | `aixsilicon:cbb` |
| 消费者 | APB interconnect（BUS-005）、apb_decoder（BUS-004）、AXI↔APB bridge（AXI-017）、APB 外设簇模板（TMP-012） |
| 优先级（Registry） | P1（interconnect 物理隔离/时序收敛常用件） |
| 风险 | 低——打拍透传语义明确；SLICE_MODE=0 保留主↔子组合环回路径（ASM-004 由消费方评估）；RESP_STAGES=2 仅实验性 Profile |

## 5. 非目标（non-goals）

- APB 协议检查/SVA BFM（协议 VIP → aixsilicon_vip_repo）
- 地址译码/多从 mux（BUS-004/BUS-005）
- CDC（BUS-006）、位宽转换（BUS-007）、超时保护（BUS-008）
- PPROT/AUSER 扩展信号（可后续扩展，不阻塞基础契约）
