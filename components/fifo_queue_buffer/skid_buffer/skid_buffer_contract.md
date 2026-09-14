---
document_type: cbb-requirements
registry_id: QUE-007
name: skid_buffer
version: 0.3.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: a3a01e3f8bfb36a7a82ec0899fda5a56698125a4c85fa8c31435a6669d1e5c9e
  behavior.yaml: f931280c018f2d66e34131e21fcda9587c7f1485ede69ef5f7c947df239f2825
---

# skid_buffer 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | QUE-007 |
| 资产版本 | 0.3.0 |
| 分类/路径 | components/fifo_queue_buffer / components/fifo_queue_buffer/skid_buffer |
| 功能家族 | Skid Buffer |
| 优先级 | P0 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

切断Ready组合链，满吞吐无气泡（OUT寄存+SKID槽）；forward/full/backward/BYPASS 多实现可对比选型

拟复用场景：外围/DMA 的速率解耦；加速器流缓存与局部排队。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 满吞吐与保序（full 实现）——随机 valid/ready/背压流下所有被接受输入按序输出， 无丢无重（参考模型队列整体比对；`in_valid&&in_ready \|-> ##1 out_valid` 无气泡）。 | tc_random, tc_backpressure | [cbb.yaml](cbb.yaml) |
| REQ-002 | 反压正确（full 实现）——全满（out_valid && ~out_ready && buf_valid）时 in_ready 拉低； 输出级空或 SKID 槽有空位时必可接受输入，数据不丢。 | tc_backpressure, tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-003 | 边界——DATA_W=1 / 极值 / 空流 / 单拍 / 连续背压场景行为正确；输出始终寄存（非 fall-through）。 | tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-004 | 非法参数在 Elaboration 期被拦截（DATA_W/BYPASS/IMPL 越界 → generate 块 $error）。 | tc_negative_elab | [cbb.yaml](cbb.yaml) |
| REQ-005 | forward 实现（IMPL=0）——data/valid 打拍 1 拍、ready 组合透传（in_ready=out_ready）， 保序无丢（背压由 ready 直接传导上游），`in_valid&&in_ready \|-> ##1 out_valid`。 | tc_fwd_random, tc_fwd_backpressure | [cbb.yaml](cbb.yaml) |
| REQ-006 | BYPASS 直通——BYPASS=1 时 out_valid=in_valid、out_data=in_data、in_ready=out_ready （零延迟组合直通，忽略 IMPL）。 | tc_bypass | [cbb.yaml](cbb.yaml) |
| REQ-007 | backward 实现（IMPL=2）——`in_ready` 由 FF 寄存（`in_ready_r`，切断反压组合链）， valid/data 组合透传（`out_valid=in_valid`、`out_data=in_data`，0 数据延迟）； 反压 1 拍延迟传导（`~out_ready && in_valid \|-> ##1 ~in_ready`）；保序无丢。 | tc_bwd_random, tc_bwd_backpressure | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| DATA_W | int | 32 | {"min": 1, "max": 1024} | 数据通路位宽（in/out 共享） |
| IMPL | int | 1 | {"min": 0, "max": 2} | 微架构选择（多实现/Profile）： 0=forward 简单打拍（data/valid 寄存，ready 组合透传，面积最小）； 1=full 满吞吐 skid（OUT 寄存 + SKID 槽，双向切时序，无气泡，默认）； 2=backward 反向打拍（in_ready 由 FF 寄存，切断反压组合链；valid/data 组合透传） |
| BYPASS | int | 0 | {"min": 0, "max": 1} | 1=组合直通（out=in 零延迟，in_ready=out_ready 直连），忽略 IMPL |

现有接口、时钟域及延迟约定：

```yaml
interface: ready_valid
clock_domains: 1
ordering: in_order
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: '满吞吐（full 实现，IMPL=1）——输入在 `in_valid && in_ready` 时每拍被接受； 被接受的输入下一拍必然在输出级可见（`in_valid
    && in_ready |-> ##1 out_valid`）， 背压不产生气泡丢拍。'
  properties:
  - PROP-SKID_ACCEPT-003
  tests:
  - tc_random
  - tc_backpressure
- id: INV-002
  description: 反压正确（full 实现，IMPL=1）——`in_ready == ~out_valid_r | out_ready | ~buf_valid_r`：
    仅当输出级满、下游未就绪且 SKID 槽满（三条件齐备）时输入才被反压； 输出级空或槽有空位时必可接受输入（数据不丢）。
  properties:
  - PROP-SKID_READY-001
  - PROP-SKID_READY-002
  tests:
  - tc_backpressure
  - tc_edge
- id: INV-003
  description: 保序——输入到输出的数据顺序不变（FIFO 语义，参考模型队列比对，适用 forward/full）。
  properties:
  - PROP-SKID_DATA-004
  - PROP-FWD_DATA-002
  tests:
  - tc_random
  - tc_fwd_random
- id: INV-004
  description: 输出为寄存（full 实现）——`out_valid`/`out_data` 由 FF 驱动，切断 valid→ready 组合路径；
    ready 方向仅组合依赖寄存状态与下游 out_ready（组合深度 ≤1 级）。
  properties: []
  tests: []
- id: INV-005
  description: 'forward 实现（IMPL=0）——`out_valid`/`out_data` 打拍 1 拍（`out_valid_r <=
    in_valid`、 `out_data_r <= in_data`），`in_ready == out_ready`（ready 组合透传，背压直接传导上游），
    `in_valid && in_ready |-> ##1 out_valid`；数据保序、无丢无重。'
  properties:
  - PROP-FWD_ACCEPT-001
  - PROP-FWD_DATA-002
  tests:
  - tc_fwd_random
  - tc_fwd_backpressure
- id: INV-006
  description: BYPASS 直通（BYPASS=1）——组合零延迟：`out_valid == in_valid`、`out_data == in_data`、
    `in_ready == out_ready`（忽略 IMPL）。
  properties:
  - PROP-BYP_DIRECT-001
  tests:
  - tc_bypass
- id: INV-007
  description: 'backward 实现（IMPL=2）——`in_ready` 由 FF 寄存（`in_ready_r`，**切断反压组合链**，
    `in_ready_r <= out_ready | ~in_valid`）；valid/data **组合透传**（`out_valid==in_valid`、
    `out_data==in_data`，0 数据延迟）；反压 1 拍延迟传导 （`~out_ready && in_valid |-> ##1 ~in_ready`）；保序无丢（ready=0
    时输入不被采样）。'
  properties:
  - PROP-BWD_READY-001
  - PROP-BWD_ACCEPT-002
  - PROP-BWD_DATA-003
  tests:
  - tc_bwd_random
  - tc_bwd_backpressure
```

### 环境假设

```yaml
- id: ASM-001
  description: 输入 valid/数据在等待 `in_ready` 期间必须保持稳定（标准 valid-ready 握手约定）。
- id: ASM-002
  description: 复位 `rst_n` 为低有效、异步拉低（FF 用 `negedge rst_n` 复位）；同步释放语义由集成层保证。
- id: ASM-003
  description: 输入 X/Z 不承诺（2-state 仿真语义；数据路径 X 传播视为未定义）。
- id: ASM-004
  description: BYPASS=1 时 IMPL 参数被忽略（直通语义优先，无微架构）；配置集不产生 BYPASS=1 与 IMPL 冲突组合。
```

### 非目标

```yaml
- 多级/可变深度打拍（属 QUE-008 pipeline_fifo）
- 跨时钟域 / 异步复位释放同步（属 cdc_rdc 套件）
- 时钟门控（ICG）数据路径（低功耗白名单结构，留 Profile 层）
- 可变延迟/流水线重排（保序 in-order 语义固定）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

