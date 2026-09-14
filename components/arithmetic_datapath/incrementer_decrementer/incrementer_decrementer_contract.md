---
document_type: cbb-requirements
registry_id: ARI-001
name: incrementer_decrementer
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 15621cb6dffd5cde745725083ed6f1fc633b9e0252c7b7179cf71c9f4c97134b
  behavior.yaml: ed4ebe8dfb3a7d687d55c4411d6971ec0e778fd3c476bf15d4ac564a693027ac
---

# incrementer_decrementer 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | ARI-001 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/arithmetic_datapath / components/arithmetic_datapath/incrementer_decrementer |
| 功能家族 | Incrementer/Decrementer |
| 优先级 | P0 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

Counter专用优化（±1 模回绕 + carry_out 溢出/借位）

拟复用场景：地址/计数计算数据通路；DSP 或向量运算叶子核。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 正确性——inc_en=1 时 dout=din+1，dec_en=1 时 dout=din-1（模 2^W 回绕）， 均不使能时 dout=din；与独立参考模型一致（两实现同契约） | tc_exhaust_w8, tc_random, tc_equiv | [cbb.yaml](cbb.yaml) |
| REQ-002 | 回绕边界——din=全1 且 inc → dout=0 且 carry_out=1；din=0 且 dec → dout=全1 且 carry_out=1（溢出/借位标志） | tc_edge, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-003 | 溢出/借位标志——carry_out=(inc_en & &din) \| (dec_en & ~\|din)；仅在 inc/dec 使能且到达边界时置位 | tc_edge, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-004 | 多实现等价——ripple/segmented 对同一 (din, inc_en, dec_en) 输出一致； 含 CG_EN=0 vs CG_EN=1 输出等价（tc_cg_equiv，ASM-005；自动 CG 不改变可观察契约） | tc_equiv, tc_random, tc_cg_equiv | [cbb.yaml](cbb.yaml) |
| REQ-005 | 非法参数在 Elaboration 期被拦截（DATA_W/ID_IMPL/SEG_W/CG_EN 越界） | tc_negative_elab | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| DATA_W | int | 32 | {"min": 2, "max": 1024} | 数据位宽；dout = din ± 1（模 2^W 回绕） |
| ID_IMPL | int | 0 | [0, 1] | 微架构选择（挂实现/Profile，不进公共功能语义）： 0=ripple 半加器进位链（O(W) 深，面积最小，基线）； 1=segmented 分段进位（O(SEG+W/SEG) 深，时序更优） |
| SEG_W | int | 4 | {"min": 2, "max": 16} | segmented 段位宽（仅 ID_IMPL=1 生效；ripple 忽略） |
| CG_EN | int | 1 | [0, 1] | 自动 Carry/Data Gating（2026-08-29 PPA 选项，基于已有 inc_en/dec_en，无外部 en 端口）： 0=关闭（原始结构）；1=开启（默认）——hold 模式进位链强制 0（carry gating 零翻转） + XOR 退化为直通（operand isolation/data gating），动态功耗更低；语义与 0 等价。 |

现有接口、时钟域及延迟约定：

```yaml
interface: native_bits_in_out
clock_domains: 0
ordering: not_applicable
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: 正确性——对任意合法 2-state 输入 (din, inc_en, dec_en)（inc_en 与 dec_en 不同时 断言，ASM-002），dout
    与独立参考模型一致：inc_en=1 → dout=din+1（模 2^W）， dec_en=1 → dout=din-1（模 2^W），均不使能 → dout=din。
    两实现（ripple/segmented）共享同一可观察契约。
  properties:
  - PROP-INC_DEC_CORRECT-001
  tests:
  - tc_exhaust_w8
  - tc_random
- id: INV-002
  description: 回绕——din=全1 且 inc_en=1 → dout=0（回绕）；din=0 且 dec_en=1 → dout=全1 （回绕）；无算术截断/饱和错误。
  properties:
  - PROP-INC_DEC_WRAP-002
  tests:
  - tc_edge
  - tc_random
- id: INV-003
  description: 溢出/借位标志——carry_out=(inc_en & &din) | (dec_en & ~|din)；仅在 inc/dec 使能且输入到达边界时置位，其余为
    0。
  properties:
  - PROP-INC_DEC_CARRY-003
  tests:
  - tc_edge
  - tc_random
```

### 环境假设

```yaml
- id: ASM-001
  description: 输入 X/Z 不承诺（2-state 仿真语义；X 传播视为未定义，断言以 $isunknown 规避）。
- id: ASM-002
  description: inc_en 与 dec_en 不同时断言（互斥）；同时断言行为未定义（调用方负责）。
- id: ASM-003
  description: DATA_W/ID_IMPL/SEG_W/CG_EN 为编译期参数，不运行时切换（生成/参数化语义）。
- id: ASM-004
  description: 纯组合，无时钟/复位；调用方负责输入稳定窗口与输出采样时序。
- id: ASM-005
  description: CG_EN=1（自动 Carry/Data Gating）不新增外部使能端口——基于已有 inc_en/dec_en 自动生效（active=inc_en|dec_en）；hold
    模式（active=0）下进位链强制 0、XOR 退化为直通， 输出语义与 CG_EN=0 完全等价（dout=din、carry_out=0）。
```

### 非目标

```yaml
- 带时钟/寄存的周期计数或累加（见 CTL-* 计数器、MON-* 事件计数器）
- 通用加/减法器（任意加数，见 ARI-002 adder_subtractor）
- 多操作数归约（见 ARI-005 adder_tree、ARI-003 carry_save_adder）
- 动态/可编程位宽（参数固定，编译期确定）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

