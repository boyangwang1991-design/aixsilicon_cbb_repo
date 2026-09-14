---
document_type: cbb-requirements
registry_id: COD-001
name: parity_gen_check
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 5089ea6a6a749dc0608a9742e50b6a87f42a3ae346a2556e8570e414b61cea81
  behavior.yaml: dd4bf29d696d33d4c02d175d82959cf97eb5c057ec8a88fe9c160ebe9387baf1
---

# parity_gen_check 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | COD-001 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/coding_integrity / components/coding_integrity/parity_gen_check |
| 功能家族 | Parity Generator/Checker |
| 优先级 | P0 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

XOR树平衡

拟复用场景：存储数据保护核心；链路编解码与完整性检查叶子核。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | parity_o 恒等于 data_i 的奇偶（reduction XOR 黄金模型） | tc_exhaust_w8, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-002 | 边界正确——全 0 时 even→0/odd→1；全 1 时 even→(W%2)/odd→(1-W%2) | tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-003 | 多实现（tree/linear）共享同一可观察契约且等价 | tc_equiv | [cbb.yaml](cbb.yaml) |
| REQ-004 | 非法参数组合在 Elaboration 期被拦截 | tc_negative_elab | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| DATA_WIDTH | int | 64 | {"min": 4, "max": 512} | 输入向量位宽（XOR 归约树规模） |
| PARITY_TYPE | int | 0 | [0, 1] | 0=even 偶校验（parity_o=^data_i）；1=odd 奇校验（parity_o=~^data_i） 注：int 枚举（DC 综合不支持 string 参数，VER-700 教训） |

现有接口、时钟域及延迟约定：

```yaml
interface: native_vector
clock_domains: 0
ordering: not_applicable
throughput: combinational
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: 函数一致性——对任意合法 2-state 输入，parity_o == ^data_i（奇偶归约黄金模型）。 PARITY_TYPE=0（even）：parity_o
    == ^data_i；PARITY_TYPE=1（odd）：parity_o == ~^data_i。
  properties:
  - PROP-PG_FUNC-001
  tests:
  - tc_exhaust_w8
  - tc_random
- id: INV-002
  description: 输出值域封闭——parity_o ∈ {0,1}（单 bit 无多驱动/未定义）。
  properties:
  - PROP-PG_BOUND-002
  tests:
  - tc_edge
```

### 环境假设

```yaml
- id: ASM-001
  description: 输入 X/Z 不承诺（2-state 仿真语义；X 传播视为未定义）。
- id: ASM-002
  description: 流水化/寄存输出版本为消费侧职责（A1 保持原子性、无时钟端口）。
```

### 非目标

```yaml
- 加权/掩码奇偶（mask 交由调用方先与运算）
- CRC / 多项式校验（属 COD-002 crc_gen_check）
- 多周期/握手时序（无事务语义）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

