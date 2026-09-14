---
document_type: cbb-requirements
registry_id: SAF-005
name: lockstep_comparator
version: 1.0.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: b2ab96a4b8c0fd62cc973b612ded3a982709f3b2261db3239047702f3f12d3fe
  behavior.yaml: ebf4d6ad027df6966284e838906bad1aff98a381d30be89d666970e5f1e65e68
---

# lockstep_comparator 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | SAF-005 |
| 资产版本 | 1.0.0 |
| 分类/路径 | components/interrupt_safety / components/interrupt_safety/lockstep_comparator |
| 功能家族 | Lockstep Comparator |
| 优先级 | P2 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

比较宽度与错误延迟

拟复用场景：IP 内局部故障检查；中断前端和安全数据路径保护。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | Delay fill, zero-delay bypass, guard and reset restart; CC-005/006 | tc_alignment | [behavior.yaml](behavior.yaml) |
| REQ-002 | Qualified masked comparison, fail-safe OR and separate internal XOR; CC-001/002/007/008 | tc_compare | [behavior.yaml](behavior.yaml) |
| REQ-003 | Independent A/B comparator and delay corruption; CC-003/004/009/010 | tc_injection | [behavior.yaml](behavior.yaml) |
| REQ-004 | Sticky classes/vector, event pulse, clear and set priority; CC-011/012 | tc_sticky | [behavior.yaml](behavior.yaml) |
| REQ-005 | Comparator stage latency and immediate reset suppression | tc_pipeline | [behavior.yaml](behavior.yaml) |
| REQ-006 | Cycle-accurate seeded stream, masks, controls, resets and injections | tc_random | [behavior.yaml](behavior.yaml) |
| REQ-007 | Single comparator stuck low cannot suppress divergence | tc_stuck | [behavior.yaml](behavior.yaml) |
| REQ-008 | Enabled X/Z data raises assertion, masked X/Z ignored | tc_unknown | [behavior.yaml](behavior.yaml) |
| REQ-009 | Illegal configuration rejected during elaboration | tc_negative | [behavior.yaml](behavior.yaml) |
| REQ-010 | Inverted safety assertion and broken fault OR are detected | tc_mutation | [behavior.yaml](behavior.yaml) |
| REQ-011 | 参数关闭时逻辑裁剪、独立延迟状态与比较流水结构通过映射报告核验 | tc_synthesis_structure | [behavior.yaml](behavior.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| WIDTH | int | 32 | {"min": 1} | Comparison bit width; no architectural upper bound. |
| LOCKSTEP_DELAY | int | 2 | {"min": 0} | Main input delay in complete rising-edge samples. |
| STARTUP_GUARD_CYCLES | int | 0 | {"min": 0} | Extra rising edges after delay fill. |
| CMP_PIPE_STAGES | int | 0 | {"min": 0, "max": 1} | Zero or one registered comparator result stage. |
| LCL_REDUNDANCY_LEVEL | int | 2 | {"min": 0, "max": 2} | Single/shared-delay dual/full dual paths. |
| STATIC_COMPARE_MASK | int | -1 | {"min": -1} | WIDTH-bit mask; -1 denotes all bits, nonnegative masks must fit WIDTH. |
| SUPPORT_RUNTIME_MASK | bool | True | 见源约束 | SUPPORT_RUNTIME_MASK compile-time enable |
| SUPPORT_VALID_MASK | bool | True | 见源约束 | SUPPORT_VALID_MASK compile-time enable |
| SUPPORT_FAULT_INJECTION | bool | True | 见源约束 | SUPPORT_FAULT_INJECTION compile-time enable |

现有接口、时钟域及延迟约定：

```yaml
interface: synchronous_observation
clock_domains: 1
throughput: 1_per_cycle
top_module: lockstep_comparator_logic
source_contract: ../SAF-005-CONTRACT.MD
hwif_rationale: Scalar/vector observation ports, no bus or shared protocol interface.
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: Safety output includes every live detected fault.
  properties:
  - PROP-LCL_SAFE-001
- id: INV-002
  description: Reset immediately suppresses live mismatch and alignment.
  properties:
  - PROP-LCL_RESET-002
```

### 环境假设

```yaml
- id: ASM-001
  description: Inputs synchronous to clk_i; rst_ni asynchronous assertion, synchronous
    deassertion supplied by integration.
- id: ASM-002
  description: Current masks qualify the aligned comparison epoch; upstream aligns
    masks if necessary.
```

### 时序

```yaml
alignment: After D+G rising edges following reset release (immediate if both zero).
pipeline: P=1 samples qualified diff at rising edge; status remains until next edge.
  Reset suppresses immediately.
sticky: Capture live result on rising edge. New result OR preserved status; clear
  discards history but never a current fault.
```

### 复位

```yaml
rst_ni clears all local state, including sticky. Warm-reset retention requires external
  safety-domain capture.
...
```

### 非目标

```yaml
- Control consistency checker
- Voting or reset generation
- Autonomous self-test
- Physical functional-safety certification
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

