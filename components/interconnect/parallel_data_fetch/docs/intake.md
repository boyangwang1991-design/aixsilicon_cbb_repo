# Intake（C0）— parallel_data_fetch（INT-001）

## 1. 需求来源与范围

需求输入见 [`../parallel_data_fetch_contract.md`](../parallel_data_fetch_contract.md)（G0 需求意图合同）
与本文档配套的 [`cbb_spec.md`](cbb_spec.md)（G1 派生规格视图）。本轮范围：完成 C0–C4
（契约、架构论证、RTL、静态基线、同步模式功能验证），异步模式结构实现并在 profiles 标注 experimental。

## 2. CBB / IP 边界判定

| 判定维度 | 本构件 | 结论 |
|---|---|---|
| 功能边界 | 单次请求的远端原子快照 + 并行转窄 + 重组 + 校验/超时/错误返回 | 一项可复用**核心逻辑能力**（非独立集成功能） |
| 接口特点 | 两端为原生 ready-valid 业务接口；链路为 1 bit 请求 + 窄 bundle | 局部握手，不承载标准总线协议事务 |
| 软件管理 | 无 CSR/中断/驱动接口 | 不构成产品级寄存器图 |
| 协议责任 | 不承担地址选择、burst、多 outstanding、重传 | 不承担完整协议事务 |

**结论：CBB（A3 局部握手构件）**。理由：只提供可参数化复用的核心逻辑与局部握手，不定义
总线协议契约（→ 非 HWIF）、不提供协议验证资产（→ 非 VIP）、不承担独立 SoC 集成功能（→ 非 IP）。
SoC 集成所需的“功能完整、可整体配置”的部分由上层 IP/集成层承担，本构件通过两个端点模块提供分区集成能力。

## 3. 查重结论（registry / Catalog）

| 候选 | 契约差异 | 结论 |
|---|---|---|
| STR-008 stream_mux / STR-014 stream_width_converter | 逐拍流式宽度转换，无远端请求与原子快照语义 | 不复用 |
| STR-021 stream_broadcaster | 高扇出复制，无窄链回传与重组 | 不复用 |
| QUE-008 pipeline_fifo | 分布式条目存储/吞吐，无请求-快照-重组事务 | 不复用 |
| CDC-007 bus_snapshot_cdc | 静态总线原子采样，不承载传输事务与窄链连续发送 | 不复用 |
| MON-013 snapshot_register_bank | 采样寄存器组，无链路协议与重构 | 不复用 |

**结论：新增条目**（registry `INT-001`，新类别 `components/interconnect`，用户指定）。

## 4. 可复用子构件判定

| 子能力 | registry 候选 | 状态 | 本轮处理 |
|---|---|---|---|
| 每 beat 奇偶校验 | COD-001 parity_gen_check | implemented | 校验逻辑为单表达式（异或），内联实现；不引入跨包依赖以保持极简单文件 |
| 请求 toggle 跨域 | CDC-004 toggle_synchronizer | planned（无实现） | 内联同构私有实现 `pdf_sync_ff`；待其实现并通过 G3/G4 后可改为 VLNV 依赖 |
| 返回 beat 跨域 | QUE-002 async_fifo | planned（无实现） | 内联同构私有实现 `pdf_async_fifo`（Gray 指针）；后续可替换为 VLNV 依赖 |
| 长线 bundle 流水 | STR-004/006 register_slice | planned | 内联私有实现 `pdf_link_pipe`（同级 bundle） |

**纪律**：未实现子核不得作为运行时 VLNV 依赖声明；均在 `implementations[].dependencies[]` 留空，
并在 [`../profiles.yaml`](../profiles.yaml) 的 `implementation_notes` 记录替换路径。

## 5. Owner、消费者与风险

- Owner：`aixsilicon:cbb`；
- 消费者（需求场景，非已完成集成）：安全模块远端密钥派生/随机数块读取；DFX trace entry 读取；
  调度器描述符/资源状态读取；低占空比宽数据跨远区读取；DFX/计数器快照读取；
- 风险级别：**P2**（无总线协议语义、无安全机制冗余结构；风险集中在 CDC 结构与参数域规模）；
- 关键风险：异步模式 CDC 正确性、超时后迟到数据污染、参数域过大导致的覆盖率抽样取舍（见 §7）。

## 6. 非目标

地址选择/命令字段、AXI/APB 等标准总线事务、连续流高带宽数据面、多 outstanding、多 lane、
packet/credit/路由/QoS、CRC 与链路重传、软件 CSR/DFX 寄存器、中断产生、PLL/CDR 与芯片间 PHY。

## 7. 本轮范围决策记录（partial-task 边界）

1. **文档/方案先行**：按 workflow-execution DOC-02，先完成契约（C1）与设计论证（C2）再写 RTL。
2. **双端点模块**：物理集成需要把 A 端与 B 端分别放在相距较远的区域，故公开交付
   `parallel_data_fetch_requester` / `parallel_data_fetch_provider` 两个端点模块，窄链路作为模块边界；
   `parallel_data_fetch` 仅作为仿真/同层集成的便利封装（见 [`design.md`](design.md)）。
3. **CDC 单元归属**：返回方向的异步 FIFO 需要写端口在 B 域、读端口在 A 域，无法拆入单侧端点；
   因此它作为独立库单元 `pdf_async_fifo`（同级于端点之上）由集成方/mux 封装实例化，
   与 toggle 同步器（随请求方向落在 B 端）共同构成链路跨域结构。
4. **配置集抽样**：13 个参数的采样域乘积远超 `config-gen` 有界枚举上限（10000），
   故不声明 `random` 配置策略；约束随机激励由 `tc_random` 在 TB 内完成（见
   [`../verification/plan.yaml`](../verification/plan.yaml)）。
5. **G6 PPA**：本机无可提交的标准单元库快照，`characterization.status: OPTIONAL_UNAVAILABLE`，
   不伪造门级数据；PPA 推理见 [`design.md`](design.md) 与 [`detail-design/`](detail-design/)。