---
document_type: cbb-requirements
registry_id: SEL-014
name: popcount
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 4c8e9044bbb7b3344c64dbcd1d81f0abce6efffe7ee73fe52f0704ee9a72dff8
  behavior.yaml: 7bd63e0f8ae06879c36511cd51908463ea476afc359655966667a0fd53f4a532
---

# popcount 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | SEL-014 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/selection_decode / components/selection_decode/popcount |
| 功能家族 | Population Count |
| 优先级 | P1 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

面积/时序Pareto（直接加法基线 + 平衡树 + Wallace + 4:2 compressor + LUT）

拟复用场景：控制路径选择与译码；地址匹配及位向量扫描。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 正确性——popcnt 等于 din 中 1 的个数（黄金模型逐位扫描一致；五实现同契约） | tc_exhaust_w4, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-002 | 边界——全 0 → 0；全 1 → DATA_W；单热 → 1 | tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-003 | 结果上界——popcnt ≤ DATA_W（NBITS=clog2(DATA_W+1) 不溢出） | tc_edge, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-004 | 多实现等价——direct/tree/wallace/comp4_2/lut 可互换（同可观察契约） | tc_equiv, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-005 | 非法参数在 Elaboration 期被拦截 | tc_negative_elab | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| DATA_W | int | 32 | {"min": 2, "max": 1024} | 输入数据位宽（位计数宽度）；输出位宽 NBITS=clog2(DATA_W+1) |
| PC_IMPL | int | 1 | [0, 1, 2, 3, 4] | 微架构选择（挂实现/Profile，不进公共功能语义）： 0=direct 直接加法基线（O(W) 级加法器链，最直观，PPA 参照）； 1=tree 平衡归约树（O(log W) 级，全并行，时序最优）； 2=wallace Wallace tree（3:2 FA + 2:1 HA 归约，生成器展开，归约级数少）； 3=comp4_2 4:2 compressor（cin/cout 列间链）+FA/HA 归约（生成器展开）； 4=lut 4bit 子块 LUT 查表 + 小加法树（结构规整，面积可控） |

现有接口、时钟域及延迟约定：

```yaml
interface: native_bits_in_count_out
clock_domains: 0
ordering: not_applicable
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: 正确性——对任意合法 2-state 输入 din，popcnt 等于 din 中 1 的个数 （与独立黄金模型逐位扫描一致）。五实现（direct/tree/wallace/comp4_2/lut）
    共享同一可观察契约。
  properties:
  - PROP-POPCOUNT_CORRECT-001
  tests:
  - tc_exhaust_w4
  - tc_random
- id: INV-002
  description: 上界——popcnt ≤ DATA_W；输出位宽 NBITS=$clog2(DATA_W+1) 精确覆盖 0..DATA_W， 不溢出、无饱和截断错误。
  properties:
  - PROP-POPCOUNT_BOUND-003
  tests:
  - tc_edge
  - tc_random
- id: INV-003
  description: 边界——din=0 → popcnt=0；din=全1 → popcnt=DATA_W；单热 → popcnt=1； 0101 交错
    → DATA_W/2。
  properties:
  - PROP-POPCOUNT_EDGE-002
  tests:
  - tc_edge
```

### 环境假设

```yaml
- id: ASM-001
  description: 输入 X/Z 不承诺（2-state 仿真语义；X 传播视为未定义，断言以 $isunknown 规避）。
- id: ASM-002
  description: DATA_W 与 PC_IMPL 为编译期参数，不运行时切换（生成/参数化语义）。
- id: ASM-003
  description: PC_IMPL∈{2,3}（Wallace/compressor）仅支持 DATA_W∈{8,16,32,64} （生成器位宽集，PC-004）；其余位宽用
    direct/tree/lut。
- id: ASM-004
  description: 纯组合，无时钟/复位；调用方负责输入稳定窗口与输出采样时序。
```

### 非目标

```yaml
- 带时钟/寄存的周期计数或累加（见 CTL-* 计数器、MON-* 事件计数器）
- 任意位宽 Wallace/compressor 通用生成（当前生成器仅 {8,16,32,64}；扩展位宽 需重新运行 tools/gen_popcount.py
  并更新 PC-004 合法域）
- 动态/可编程位宽（参数固定，编译期确定）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

