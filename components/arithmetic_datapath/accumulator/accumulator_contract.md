---
document_type: cbb-requirements
registry_id: ARI-006
name: accumulator
display_name: Accumulator
registry_status: planned
registry_classification: A2
priority: P0
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 1d8e53867643116505e1b2c1a24aa21519b89fda642d8fc4ddc7e7730e7c35bc
  behavior.yaml: 092b182e4893e305d6c24747811a5d54a9882e71bd26e23e3eed199265a76f1f
focus: 反馈路径与门控
research_date: 2026-09-14
---

# accumulator 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准（[`cbb.yaml`](cbb.yaml)、[`behavior.yaml`](behavior.yaml)）。
本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。架构与调研论证见 [`docs/design.md`](docs/design.md)。

| 字段 | 内容 |
|---|---|
| 索引 ID | ARI-006 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/arithmetic_datapath / components/arithmetic_datapath/accumulator |
| 功能家族 | Accumulator |
| 优先级 | P0 |
| 当前登记状态 | planned |

## 1. 定位与使用场景

参数化整数/定点累加器 CBB：`A_next = A ± X`，支持清零、初值装载、有效使能、回绕/饱和与溢出状态；重点优化单周期反馈路径、操作数隔离与 ICG 映射（A2 数据通路构件，stateful 族）。

拟复用场景：DSP/NPU 部分和累加、事件权重/字节数/能量求和、有符号积分/误差累计、NCO 相位累加（模 2^W 回绕）。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文要点） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 核心功能——按 ACC-CTL-001 优先级实现 A_next=A±X，支持清零/装载/使能/回绕饱和 | tc_exhaust_w8, tc_random, tc_seq | cbb.yaml |
| REQ-002 | 数值边界——按 SIGNED 符号/零扩展，WRAP 低 W 位、SATURATE 钳位 | tc_edge, tc_random | cbb.yaml |
| REQ-003 | 溢出/状态——event 当且仅当 T 越界，signed overflow 非 carry-out，sticky 同拍优先级 | tc_edge, tc_sticky, tc_random | cbb.yaml |
| REQ-004 | 时序/接受——单状态每拍一个样本 II=1，事件每沿重赋值 | tc_seq, tc_continuous | cbb.yaml |
| REQ-005 | 复位/重启——同步复位清状态与事件，CLR/LOAD 与 valid 冲突优先级 | tc_reset, tc_seq | cbb.yaml |
| REQ-006 | 配置合法性——非法 OP_MODE/位宽 elaboration $error 拦截 | tc_negative_elab | cbb.yaml |
| REQ-007 | 实现等价——隔离/门控开关前后根时钟采样一致 | tc_iso_equiv | cbb.yaml |
| REQ-008 | 依赖与使用约束——局部累加核心逻辑边界 | — | cbb.yaml |
| REQ-009 | PPA 与可观察性能——关键路径/吞吐记录 | — | cbb.yaml |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| INPUT_WIDTH | int | 16 | 1~128 | 输入 X 位宽（PC-001/007） |
| ACC_WIDTH | int | 32 | 1~256 | 状态和输出位宽（PC-003/008） |
| SIGNED | bool | true | bool | true=符号扩展，false=零扩展 |
| OP_MODE | int | 0 | [0,1,2] | ADD_ONLY/SUB_ONLY/ADD_SUB（PC-004） |
| OVERFLOW_MODE | int | 0 | [0,1] | WRAP/SATURATE（PC-005） |
| LOAD_EN / STATUS_EN | bool | true | bool | 装载使能 / 状态输出使能 |
| OPERAND_ISOLATION | int | 0 | [0,1] | 操作数隔离（PC-006） |

现有接口、时钟域及延迟约定（cbb.yaml contract）：

```yaml
interface: native_bits_in_out
clock_domains: 1
ordering: in_order
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

不变量（behavior.yaml INV-001..005）：正确性（acc_o 与独立无限精度参考逐步一致）、
数值（符号/零扩展、WRAP/SATURATE）、溢出（event/sticky 语义与同拍优先级）、
时序（事件每沿重赋值、II=1）、复位（同步复位清状态与事件）。

环境假设（ASM-001..005）：输入 X/Z 不承诺；参数为编译期；ce=0 时 load/valid 不被接收；
LOAD_EN=false 时 load_i 绑 0、STATUS_EN=false 时状态绑 0；update_o 不是标准流 TVALID。

### 非目标

```yaml
- 乘法器、MAC 的乘法前级（可组合但非核心边界）
- APB/AXI、DMA、任务调度、软件寄存器、统计中断、存储器管理
- 浮点累加、反馈缩放、每步舍入积分器
- 多输入同拍求和归约（前置 reduction tree）
- 多上下文交织/分条、偏斜流水、carry-save 冗余反馈（独立增强探索）
- 任意 LATENCY 参数（V1.0 反馈更新即一个时钟周期）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，
本文不代表已重跑；验证证据见 [`reports/verification-report.md`](reports/verification-report.md) 与
`build/eda/evidence/{g3_static,g4_functional}/`（G4 功能仿真 4393 checks / 0 errors，G3 负向 8/8）。
修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[`docs/cbb_spec.md`](docs/cbb_spec.md)。门禁与资格结论仍由具体版本、参数和工具证据决定。
