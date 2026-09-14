---
document_type: cbb-requirements
registry_id: QUE-001
name: sync_fifo
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 6fdbc6929fef22c77f1883edbb6969537c8545c905670238db159a374040ad99
  behavior.yaml: 514de4fe515a6b23ea48cf67269cf704e6afd3105641533c8b390b90542616db
---

# sync_fifo 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | QUE-001 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/fifo_queue_buffer / components/fifo_queue_buffer/sync_fifo |
| 功能家族 | Synchronous FIFO |
| 优先级 | P0 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

深宽自动映射（register/shift 已物化；SRAM 依赖 A0 wrapper 未实现，登记 non_goals）

拟复用场景：外围/DMA 的速率解耦；加速器流缓存与局部排队。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 保序与无丢无重（register, IMPL=0）——随机 push/pop（含背压）流下所有被接受 写入按序 pop 输出一次且仅一次，参考模型队列整体比对。 | tc_random, tc_backpressure | [cbb.yaml](cbb.yaml) |
| REQ-002 | 满/空/占用计数一致性（register）——full_o==(count==DEPTH)、empty_o==(count==0)； count_o 守恒（push +1、pop -1、同拍 push+pop 不变，边界不越 [0,DEPTH]）； 满时不接受写、空时不产生读（无溢出/下溢）。 | tc_random, tc_backpressure, tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-003 | 同拍 push+pop 与满写/空读并发边界——count 守恒、无上溢/下溢回绕； 满时 push 无效、空时 pop 无效。 | tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-004 | OUTPUT_REG=0（组合读出）——empty_o 拉低同拍 rd_data_o 有效（头部数据）； pop 有效条件 ~empty_o && rd_en_o 的语义（数据当拍可消费、次拍指针推进）。 | tc_out_comb, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-005 | OUTPUT_REG=1（寄存输出级）——rd_valid/rd_data 由输出 FF 驱动（1 拍读延迟）； 弹空拍允许消费缓存最后数据，空态稳定后 rd_valid 才拉低 （`empty_o \|-> ##1 ~rd_valid_o`，domain-rules §3.1.1 语义）；pop 判定 基于沿前非空，防空下溢。 | tc_outreg, tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-006 | shift 实现（IMPL=1）与 register 共享同一可观察契约——保序/满空/占用计数/ 输出语义一致（参考模型整体比对，含随机与背压场景）。 | tc_random, tc_backpressure | [cbb.yaml](cbb.yaml) |
| REQ-007 | 边界——DATA_W=1 / DEPTH=2（最小）/ 大深度 / 空流 / 满写连发 / 空读连发 场景行为正确（register 与 shift 各代表点）。 | tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-008 | 非法参数在 Elaboration 期被拦截（DATA_W/DEPTH/OUTPUT_REG/IMPL 越界 → generate $error）。 | tc_negative_elab | [cbb.yaml](cbb.yaml) |
| REQ-009 | 复位后状态清零——empty_o=1、count_o=0、full_o=0；OUTPUT_REG=1 时 rd_valid_o=0；可立即接受 push（逐拍写入恢复计数）。 | tc_reset | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| DATA_W | int | 32 | {"min": 1, "max": 1024} | 数据通路位宽（push/pop 共享） |
| DEPTH | int | 16 | {"min": 2, "max": 256} | 队列条目深度（存储单元数）。IMPL=register 支持全合法域；IMPL=shift 建议 DEPTH<=32（面积随深度线性且无译码，过深不合算，见 profiles 限制） |
| OUTPUT_REG | int | 0 | [0, 1] | 输出级模式：0=组合读出（rd_valid=~empty 同拍，rd_data 头部直读，0 读延迟）； 1=寄存输出级（输出 FF，1 拍读延迟、切输出时序路径；弹空拍可消费缓存， 空态稳定后 rd_valid 才拉低） |
| IMPL | int | 0 | [0, 1] | 存储微架构（挂实现/Profile）：0=register（读写指针 + 寄存器堆，通用深度， 默认）；1=shift（移位寄存器存储，浅深低功耗、无地址译码，建议 DEPTH<=32） |

现有接口、时钟域及延迟约定：

```yaml
interface: native_push_pop
clock_domains: 1
ordering: in_order
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: 保序与无丢无重（FIFO 语义）——所有被接受写入（push 有效且非满）按写入顺序 pop 输出一次且仅一次；参考模型队列整体比对（无丢、无重、无乱序）。适用
    register 与 shift 全模式。
  properties:
  - PROP-SYNC_ORDER-001
  tests:
  - tc_random
  - tc_backpressure
  - tc_edge
  severity: error
- id: INV-002
  description: 占用计数守恒与满/空一致性——count 反映当前占用 ∈ [0,DEPTH]；count==DEPTH ⇔ full_o、 count==0
    ⇔ empty_o；push（非满）+1、pop（非空）-1、同拍 push+pop 净 0； 无上溢（满时 push 无效不写入）无下溢（空时 pop 无效）。
  properties:
  - PROP-SYNC_CNT-002
  - PROP-SYNC_FULL-003
  - PROP-SYNC_EMPTY-004
  tests:
  - tc_random
  - tc_backpressure
  - tc_edge
  severity: error
- id: INV-003
  description: OUTPUT_REG=0（组合读出）——empty_o 拉低当拍 rd_data_o 即有效（组合头读出， 0 读延迟）；pop 事件
    = rd_en 且非空，下一拍指针推进、后续数据可见。
  properties:
  - PROP-SYNC_COMB-005
  tests:
  - tc_out_comb
  - tc_random
  severity: error
- id: INV-004
  description: 'OUTPUT_REG=1（寄存输出级）——rd_valid_o/rd_data_o 由输出 FF 驱动（1 拍读延迟）； 物理 pop
    由沿前非空判定（~empty 且 rd_en），防空下溢；弹空拍允许消费最后缓存， 空态稳定后 rd_valid_o 才拉低（`empty_o |-> ##1
    ~rd_valid_o`）。'
  properties:
  - PROP-SYNC_OUTREG-006
  tests:
  - tc_outreg
  - tc_edge
  severity: error
- id: INV-005
  description: 输出方向不引入组合环/锁存——comb 模式 rd_data 仅依赖存储与读指针（寄存）， reg 模式全部输出由 FF 驱动；full/empty/count
    由寄存 count 派生（组合深度 ≤1 级）。
  properties: []
  tests: []
  severity: info
```

### 环境假设

```yaml
- id: ASM-001
  description: push 数据在 push_i 有效周期内保持稳定；pop 方在 rd_en 有效且输出有效时取数。
- id: ASM-002
  description: 复位 `rst_n` 低有效异步拉低；释放后 count/指针/输出级清零，同步释放语义由集成层保证。
- id: ASM-003
  description: 输入 X/Z 不承诺（2-state 仿真语义）；数据路径 X 传播视为未定义。
- id: ASM-004
  description: OUTPUT_REG 与 IMPL 相互独立可组合（comb/reg × register/shift 均合法）； IMPL=shift
    建议 DEPTH<=32（见 profiles 限制，非 error 约束，超限仅面积/时序劣化）。
- id: ASM-005
  description: 不支持满时强制写入或空时强制读取（无 override/flush 语义；flush 类归 A3 包装或消费者侧控制，非本 A2 存储契约）。
```

### 时序

```yaml
first_beat_latency: 0
full_throughput: true
backpressure_propagation: 1
```

### 异常

```yaml
- id: EXC-001
  description: 复位释放后 count/读写指针/输出级清零；empty_o=1、count_o=0、rd_valid_o=0（reg）。
  handling: async_reset_low
```

### 非目标

```yaml
- 跨时钟域 / 异步复位释放同步（属 cdc_rdc 套件 QUE-002 async_fifo）
- 首拍零延迟直读透传/FWFT（QUE-003 fall_through_fifo；comb 输出仅是"非空即有头数据"，非事务透传）
- SRAM 宏存储（IMPL=sram 依赖未实现 A0 wrapper TEC-015 sram_macro_wrapper，待委派实现后扩展）
- flush/override/peek（按需由消费者侧或 A3 包装控制）
- 可配置阈值 almost_full/almost_empty 中断/水位（留 Profile 层或后续版本）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

