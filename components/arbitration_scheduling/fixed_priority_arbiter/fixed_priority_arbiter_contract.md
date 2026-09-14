---
document_type: cbb-requirements
registry_id: ARB-001
name: fixed_priority_arbiter
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 38057ec825728c182757fe6ee97e7f9dd41d07a32b115512b995f663dc2016a5
  behavior.yaml: 39c319d7cd2a168bb4f86bea029c80f6a7e5236897a44d86c3e7e79228193063
---

# fixed_priority_arbiter 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | ARB-001 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/arbitration_scheduling / components/arbitration_scheduling/fixed_priority_arbiter |
| 功能家族 | Fixed-priority Arbiter |
| 优先级 | P0 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

优先级链（授权互斥 + LSB/MSB 优先；支持 latched/registered 授权）

拟复用场景：DMA 多请求共享端口；多 Bank 数据通路资源分配。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 授权互斥——任意合法请求组合最多一个 grant_o 有效（无多授权/无授权冲突） | tc_mutex, tc_random, tc_exhaust_w4 | [cbb.yaml](cbb.yaml) |
| REQ-002 | 优先级语义——PRIORITY=0 时 grant 为 req 中最低有效位（LSB 优先）；PRIORITY=1 时最高有效位（MSB 优先） | tc_priority, tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-003 | 无请求时 grant 全零；有请求必有且仅有一个授权 | tc_edge | [cbb.yaml](cbb.yaml) |
| REQ-004 | REQ_TYPE=1（latched）——请求被寄存，grant 保持直到 grant_ack_i 应答后清除；应答无请求时清除为 0 | tc_latched | [cbb.yaml](cbb.yaml) |
| REQ-005 | FAST_GRANT=1（registered）——grant_o 比组合授权延迟 1 拍，且与组合授权（考虑延迟）一致 | tc_registered, tc_equiv | [cbb.yaml](cbb.yaml) |
| REQ-006 | 多实现（linear/tree/grouped）共享同一可观察契约且等价 | tc_equiv | [cbb.yaml](cbb.yaml) |
| REQ-007 | 非法参数组合在 Elaboration 期被拦截 | tc_negative_elab | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| NUM_REQ | int | 8 | {"min": 2, "max": 64} | 请求输入端数（请求向量位宽） |
| PRIORITY | int | 0 | [0, 1] | 0=lowest_index_first（req[0] 最高优先级，回绕递减；经典最低位优先）； 1=highest_index_first（req[N-1] 最高优先级，回绕递减）。 注：int 枚举（DC 综合不支持 string 参数，VER-700 教训） |
| REQ_TYPE | int | 0 | [0, 1] | 0=level（组合，每周期按当前 req_i 决策，不锁定）； 1=latched（内部寄存输入请求，直到 grant 被消费方以 grant_ack_i 应答后清除；   多拍保持授权，适合慢速/需稳定授权的场景） |
| FAST_GRANT | int | 0 | [0, 1] | 0=combinational（grant_o 与 req_i 同拍组合输出，零延迟）； 1=registered（grant_o 输出寄存，1 拍授权延迟；关键路径从 req_i→grant_o 变为   reg→grant_o，时序更优；时钟复位：异步复位有效） |
| PC_IMPL | int | 0 | [0, 1, 2] | 微架构选择（挂实现/Profile，不进公共功能语义）： 0=linear 显式优先级链（O(N) 深度，最小面积，适合小 N）； 1=tree 折半并行前缀/树（O(log N) 深度，时序优，面积略增）； 2=grouped 分组并行（N 分组树 + 组内链，面积/时序折中） |

现有接口、时钟域及延迟约定：

```yaml
interface: native_req_grant
clock_domains: 1
ordering: not_applicable
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: 授权互斥——对任意合法 2-state 请求向量，grant_o 中至多一位有效 （无多授权、无授权冲突）。
  properties:
  - PROP-FPA_MUTEX-001
  tests:
  - tc_mutex
  - tc_random
  - tc_exhaust_w4
- id: INV-002
  description: 优先级语义——PRIORITY=0 时 grant 为请求向量中最低有效位（LSB 优先，即 req[0] 最高优先级）；PRIORITY=1
    时 grant 为最高有效位（MSB 优先，req[N-1] 最高优先级）。 与黄金模型（从高到低扫描首个置位）一致。
  properties:
  - PROP-FPA_PRIO-002
  tests:
  - tc_priority
  - tc_edge
- id: INV-003
  description: 无请求 → grant_o 全零；有请求 → 恰好一个授权（活性：不丢授权）。
  properties:
  - PROP-FPA_NONE-003
  tests:
  - tc_edge
- id: INV-004
  description: REQ_TYPE=1（latched）——请求被内部寄存；grant 保持至 grant_ack_i 上升沿后清除； 清除后若原请求仍有效则重新授权（或按当前优先级重选）；ack
    时无保持请求 → grant=0。
  properties:
  - PROP-FPA_LATCH-004
  tests:
  - tc_latched
- id: INV-005
  description: FAST_GRANT=1（registered）——grant_o 相对组合参考模型延迟 1 拍， 且每周期组合参考（req_i 经优先级选择）等于寄存
    grant 一拍前的期望。
  properties:
  - PROP-FPA_REG-005
  tests:
  - tc_registered
  - tc_equiv
```

### 环境假设

```yaml
- id: ASM-001
  description: 输入 X/Z 不承诺（2-state 仿真语义；X 传播视为未定义）。
- id: ASM-002
  description: REQ_TYPE=1 时 grant_ack_i 必须在 grant_o 有效后的下一拍内拉高（或在授权 保持期间），否则授权保持（防活锁由消费方保证）。
- id: ASM-003
  description: PRIORITY 与 PC_IMPL 为编译期参数，不运行时切换（生成/参数化语义）。
- id: ASM-004
  description: FAST_GRANT=1 需要 clk/rst_n；纯组合配置（FAST_GRANT=0 且 REQ_TYPE=0） 可不接时钟（RTL
    仍保留端口，接 clk 亦可）。
```

### 非目标

```yaml
- 轮转/加权/公平性调度（RR/WRR/Deficit，见 ARB-002/003/004）
- 多授权（top-K 同时授权，见 ARB-007 multi_grant_arbiter）
- 层次化跨模块仲裁（见 ARB-008 hierarchical_arbiter）
- 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍延迟）
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

