# sync_fifo — Intake（G0）

> 生命周期 C0 产物。SSOT：本文件为 Intake 结论的记录视图；Registry 状态见
> [`registry.yaml`](../../registry.yaml)（owner `aixsilicon:cbb`）。审查依据：cbb-development-suite / domain-rules §1。

## 1. 边界判定（CBB vs IP / HWIF / VIP / Techlib）

| 维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无（纯 push/pop 数据通路，无寄存器/软件契约） |
| 独立驱动 / 固件 / 复杂系统状态机 | 无（指针 + 计数有限状态，无事务/总线协议状态机） |
| 定制方式 | 参数与端口（DATA_W / DEPTH / OUTPUT_REG / IMPL 等） |
| 复用面 | SoC/Subsystem 任意模块间深度缓冲、ready-valid 流吸收、窄宽汇聚缓冲、流水反压隔离、低风险存储内嵌队列 |
| 行为契约 + 有限属性可否完整描述 | 是（FIFO 保序/满/空/占用计数一致性/输出寄存语义，INV-001..） |
| **判定** | **CBB，抽象粒度 A2（通用复合：存储队列机制，非协议绑定）** |

> 无 CBB→IP 升级趋势（无 CSR/中断/软件契约/系统生命周期）。与 skid_buffer（QUE-007, A3
> ready-valid 打拍，深度=1）粒度不同：sync_fifo 是可变深度存储队列（A2），skid_buffer 是
> 1 级握手切片（A3）。HWIF 无独立契约（纯原生 push/pop + 可选 valid-ready 视图），
> 属 CBB 内部参数/行为契约，不触发 hwif-development-suite（负向边界见 super-skill）。

## 2. 查重（registry.yaml / cbb_repo_list / Catalog）

| 候选 | 结论 |
|---|---|
| QUE-007 skid_buffer | 不同——A3 1 级打拍（深度=1，无多字存储/占用计数）；本 CBB 深度可配存储队列（A2） |
| QUE-002 async_fifo | 不同——跨时钟域（Gray 指针 + 同步器，CDC 白名单）；本 CBB 单时钟域同步 FIFO |
| QUE-003 fall_through_fifo | 不同——FWFT 首拍零延迟直读语义；本 CBB 标准（寄存/同步读）输出 |
| QUE-004 shift_reg_fifo | 不同——专用移位寄存器存储结构 profile（本 CBB 的 IMPL=shift 复用同一契约） |
| QUE-005 sram_fifo | 不同——专用 SRAM 宏存储 profile（本 CBB 的 IMPL=sram 复用同一契约，需 A0 wrapper） |
| QUE-001 sync_fifo | **本条目（registry 已登记 planned，本次物化）** |
| **结论** | **物化已有条目（QUE-001，P0 基础构件）** |

## 3. 嵌套依赖解析（若有子 CBB）

| 需求子 CBB | 查 LIST 结果 | 决策 |
|---|---|---|
| sram 宏访问（IMPL=sram 方向） | `TEC-015 sram_macro_wrapper`（adapters, A0, planned 未实现） | **本次不实现 IMPL=sram**——依赖未实现的 A0 wrapper，超出本任务范围；在 `non_goals` 登记，后续经**用户同意**再委派子 Agent 实现 A0 wrapper 后扩展 |
| （无其它） | — | register/shift 实现无运行时子 CBB 依赖（`implementations[].dependencies[]` 为空） |

> 依赖方向单向、防环（domain-rules §4.1）；未实现子 CBB 委派前必须征求用户同意。

## 4. 消费者与使用场景

| 场景 | 说明 |
|---|---|
| 模块间深度缓冲 | 源/宿速率不匹配时用同步 FIFO 吸收突发（IP/SoC 内部通用队列） |
| ready-valid 流吸收 | 把 A3 ready-valid 流接入带深度/占用/满空的存储队列（作为上游 A2 存储） |
| 反压隔离 | 输出级寄存（OUTPUT_REG=1）切断满→上游反压组合链，隔离时序 |
| 窄宽汇聚 | 多源写入单队列、按序读出（配合 DATA_W 位宽参数） |
| 低风险内嵌队列 | 小面积寄存器堆（IMPL=register / shift）替换手工 FIFO，具备复用验证 |

## 5. 风险与成熟度

| 项 | 值 |
|---|---|
| 风险等级 | P0（基础构件，被多 IP 复用；指针/计数边界是经典风险点，需 Formal/仿真覆盖） |
| 起始成熟度 | E0 |
| 主要风险 | ① 满/空/占用计数边界（同拍 push+pop、弹空拍）——由 INV/属性 + 参考模型仿真消解；② 输出寄存（OUTPUT_REG=1）pop 判定滞后语义——由 domain-rules §3.1.1 专项对策消解；③ 参数化位宽/深度越界——由 generate `$error` + 负向编译消解 |
| 执行深度 | Standard Loop（新 CBB，多 Profile）——G3 静态 + G4 功能（Formal/仿真）为默认出口 |

## 6. Owner / 审批

- Owner：`aixsilicon:cbb`
- approvals：rtl-owner（RTL 修改）、dv-owner（验证计划）
- 任务 ID：`AIX-CBB-<分配>`

## 7. 执行深度

- Loop：**standard**（新 CBB、结构变更、Profile 化）
- 执行模式：**partial-task**（按顺序产出规格→设计→RTL→验证，依赖子 CBB 缺省不阻塞 register/shift 主干）
- 本次范围：`IMPL=register`（寄存器堆指针 FIFO，默认）+ `IMPL=shift`（移位寄存器，浅深低功耗）
  物化；`IMPL=sram` 登记非目标（依赖未实现 A0 wrapper，见 §3）。
