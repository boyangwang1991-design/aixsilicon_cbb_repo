# accumulator 规格说明（G1 可读视图）

> **派生视图**：SSOT 为 [`cbb.yaml`](../cbb.yaml)（+[`behavior.yaml`](../behavior.yaml)），本文件仅为人工程序可读副本，**语义以 YAML 为准**（不双维护）。

## 1. 定位

参数化整数/定点累加器 CBB：`A_next = A ± X`，具备清零、初值装载、有效使能、回绕/饱和与溢出状态；重点优化单周期反馈路径、操作数隔离与 ICG 映射。

- 抽象粒度：`A2`（参数化数据通路构件，带状态）
- 技术域：`arithmetic_datapath`（次：`control_event_status`）
- Registry ID：`ARI-006`

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） |
|---|---|---|---|
| REQ-001 | 核心功能（清零/装载/使能/回绕饱和） | `PROP-ACC_CORRECT-001` | tc_exhaust_w8, tc_random, tc_seq |
| REQ-002 | 数值边界（符号/零扩展、WRAP/SATURATE） | `PROP-ACC_NUM-002` | tc_edge, tc_random |
| REQ-003 | 溢出/状态（event/sticky、同拍优先级） | `PROP-ACC_OVERFLOW-003` | tc_edge, tc_sticky, tc_random |
| REQ-004 | 时序/接受（II=1、每拍更新、事件重赋值） | `PROP-ACC_TIMING-004` | tc_seq, tc_continuous |
| REQ-005 | 复位/重启（同步复位、冲突优先级） | `PROP-ACC_RESET-005` | tc_reset, tc_seq |
| REQ-006 | 配置合法性（elaboration 拦截非法组合） | — | tc_negative_elab |
| REQ-007 | 实现等价（隔离/门控前后采样等价） | `PROP-ACC_EQV-007` | tc_equiv, tc_iso_equiv |
| REQ-008 | 依赖与使用约束（局部核心逻辑边界） | — | — |
| REQ-009 | PPA 与可观察性能（关键路径/吞吐记录） | — | — |

> 完整映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)（工具生成）。

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| INPUT_WIDTH | int | 16 | 1~128 | 输入 X 位宽 |
| ACC_WIDTH | int | 32 | 1~256 | 状态和完整输出位宽 |
| SIGNED | bool | true | true/false | true=有符号（符号扩展），false=无符号（零扩展） |
| OP_MODE | int | 0 | [0,1,2] | 0=ADD_ONLY、1=SUB_ONLY、2=ADD_SUB |
| OVERFLOW_MODE | int | 0 | [0,1] | 0=WRAP（低 W 位回绕）、1=SATURATE（钳位） |
| LOAD_EN | bool | true | true/false | 支持全 ACC_WIDTH 位初值装载 |
| STATUS_EN | bool | true | true/false | 生成事件与 sticky 溢出状态 |
| OPERAND_ISOLATION | int | 0 | [0,1] | 1=仅算术时屏蔽无效输入翻转 |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | INPUT_WIDTH >= 1 | 防零宽输入 |
| PC-002 | INPUT_WIDTH <= ACC_WIDTH | 防输入位宽超过状态位宽 |
| PC-003 | ACC_WIDTH >= 1 | 防零宽状态 |
| PC-004 | OP_MODE >= 0 and OP_MODE <= 2 | OP_MODE 编码合法域 |
| PC-005 | OVERFLOW_MODE >= 0 and OVERFLOW_MODE <= 1 | OVERFLOW_MODE 编码合法域 |
| PC-006 | OPERAND_ISOLATION >= 0 and OPERAND_ISOLATION <= 1 | 隔离开关编码合法域 |
| PC-007 | INPUT_WIDTH <= 128 | RTL 平面/时序上界 |
| PC-008 | ACC_WIDTH <= 256 | RTL 平面/时序上界 |

> 非法组合在 Elaboration 前被拦截（`cbb_tool.py check` + RTL `$error` generate 双拦截）。

## 4. 行为不变量（INV）与假设（ASM）

- 不变量：
  - `INV-001` 正确性——acc_o 与独立无限精度参考模型逐步一致（含控制优先级）
  - `INV-002` 数值——符号/零扩展、WRAP 低 W 位、SATURATE 钳位范围
  - `INV-003` 溢出——event 当且仅当 T 越界；sticky 置位/清除/同拍优先级
  - `INV-004` 时序——事件每沿重新赋值、II=1、acc_o 即时体现
  - `INV-005` 复位——同步复位清状态与事件；CLR/LOAD 与 valid 同拍优先级
- 时序：首拍延迟 1（状态反馈更新就是一个时钟周期）；满吞吐 `是（ce_i=1 且 valid_i=1 时每拍一个样本，II=1）`；无 ready、无内部排队
- 假设：
  - `ASM-001` 输入 X/Z 不承诺（2-state）
  - `ASM-002` 参数为编译期，不运行时切换
  - `ASM-003` ce_i=0 时 load/valid 不被接收
  - `ASM-004` LOAD_EN=false 时 load_i 绑 0；STATUS_EN=false 时状态绑 0
  - `ASM-005` update_o 不是标准流协议 TVALID
- 异常：复位释放后 acc_o=0；ce=0 时 A 保持

## 5. 接口与时钟复位

- 接口：`native_bits_in_out`（原生位向量 + 控制，无总线协议语义；不引用 HWIF——纯位级数据通路）
- 端口：
  - 时钟/复位：`clk_i`（单时钟、上升沿）、`rst_ni`（低有效同步复位）
  - 控制：`ce_i`、`clear_i`、`load_i`、`load_data_i[ACC_WIDTH-1:0]`、`valid_i`、`data_i[INPUT_WIDTH-1:0]`、`sub_i`、`status_clear_i`
  - 数据/状态：`acc_o[ACC_WIDTH-1:0]`
  - 事件：`update_o`、`overflow_event_o`、`overflow_sticky_o`
- 时钟：1 个（`clk_i`）；复位：`sync rst_ni`（低有效）

## 6. 假设与非目标（non-goals）

| 项 | 内容 |
|---|---|
| 非目标 1 | 乘法器、MAC 的乘法前级（可组合但非核心边界） |
| 非目标 2 | APB/AXI、DMA、任务调度、软件寄存器、统计中断、存储器管理 |
| 非目标 3 | 浮点累加、反馈缩放、每步舍入积分器 |
| 非目标 4 | 多输入同拍求和归约（前置 reduction tree） |
| 非目标 5 | 多上下文交织/分条、偏斜流水、carry-save 冗余反馈（独立增强探索） |
| 非目标 6 | 任意 LATENCY 参数（V1.0 反馈更新即一个时钟周期） |

## 7. 集成限制

- 限制 1：`INPUT_WIDTH <= ACC_WIDTH` 强制（PC-002）
- 限制 2：INPUT_WIDTH ≤ 128、ACC_WIDTH ≤ 256（PC-007/008 平面/时序上界）
- 限制 3：LOAD_EN=false 时 load_i 必须由集成绑 0；STATUS_EN=false 时状态输出绑 0
- 用途建议：DSP/NPU 部分和累加、事件权重/字节数/能量求和、有符号积分/增减平衡、NCO 相位累加（模 2^W 回绕）

## 8. 追踪

需求→属性→测试→配置映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)；验证形态与矩阵见
[`verification/plan.yaml`](../verification/plan.yaml) 与 [`verification/configs/`](../verification/configs/)。

## 编码、同时事件与采样审查

| 审查项 | 应明确的契约 |
|---|---|
| 资产/顶层 | cbb.name=accumulator、registry.path=components/arithmetic_datapath/accumulator、contract.top_module=accumulator |
| 控制编码 | ce/clear/load/valid/status_clear 为单 bit 控制；OP_MODE/OVERFLOW_MODE/OPERAND_ISOLATION 编码合法域见 §3；LOAD_EN/STATUS_EN 关闭语义见 ASM-004 |
| 同拍事件 | 更新优先级 rst_ni > clear_i > ce_i=0 > LOAD > valid（ACC-CTL-001）；sticky 清除与新生溢出同拍时置位优先（ACC-CTL-003）；CLR 与 valid 同拍只清零 |
| 比较时刻 | data_i/sub_i/valid_i 在根时钟沿采样；接收边沿后 acc_o 立即体现本次更新 |
| 结果流水 | 单拍组合反馈（A→A 路径）；无输出额外寄存器（由独立包装处理，不改变核心反馈延迟） |
| 负向参数 | 参数域校验由 check 约束求值 + RTL generate $error 双拦截；非法组合 elaboration 期拒绝，不以工具崩溃代替诊断 |

只对构件实际存在的机制填写；无关项注明不适用，不为模板新增功能。
