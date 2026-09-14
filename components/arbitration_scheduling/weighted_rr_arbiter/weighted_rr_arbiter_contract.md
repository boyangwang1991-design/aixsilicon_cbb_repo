---
document_type: cbb-requirements
registry_id: ARB-003
name: weighted_rr_arbiter
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 5c4a5cf59c45497d3c481a39d556e7c77d4c26971299a5c247f988039fb5ebb7
  behavior.yaml: 51f9335cede388914bfc402960cc34c4168e0fce4e564b393d14139219009dbd
---

# weighted_rr_arbiter 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | ARB-003 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/arbitration_scheduling / components/arbitration_scheduling/weighted_rr_arbiter |
| 功能家族 | Weighted RR Arbiter |
| 优先级 | P2 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

权重状态与公平性（quota_counter/deficit_rotate 双实现 + G3/G4/G5 证据）

拟复用场景：DMA 多请求共享端口；多 Bank 数据通路资源分配。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | 授权互斥——任意合法请求组合最多一个 grant_o 有效（无多授权/无授权冲突） | tc_mutex, tc_random, tc_quota_window | [cbb.yaml](cbb.yaml) |
| REQ-002 | 权重公平（quota）——每轮配额窗口内，各有效请求的授权次数不超过其权重； 连续满请求下，授权次数比例趋近权重比例（无超发、不饿死） | tc_quota_window, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-003 | 无请求时 grant 全零；有请求必有且仅有一个授权（活性） | tc_edge, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-004 | smooth WRR（WMODE=1）——按 credit 最大且有权重的请求动态选择， 剩余 credit 跨轮累计；权重比例正确且无负 credit（不超发） | tc_smooth_ratio, tc_random | [cbb.yaml](cbb.yaml) |
| REQ-005 | FAST_GRANT=1（registered）——grant_o 比组合授权延迟 1 拍，且与组合授权（考虑延迟）一致 | tc_registered, tc_equiv | [cbb.yaml](cbb.yaml) |
| REQ-006 | 多实现（quota_counter/deficit_rotate）共享同一可观察契约且等价 | tc_equiv, tc_quota_window | [cbb.yaml](cbb.yaml) |
| REQ-007 | GRANT_ACK_EN=1——grant 锁定到 ack 应答后才轮转；ack 应答后按权重 RR 顺序移动到下一请求 | tc_ack_lock | [cbb.yaml](cbb.yaml) |
| REQ-008 | 非法参数组合在 Elaboration 期被拦截 | tc_negative_elab | [cbb.yaml](cbb.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| NUM_REQ | int | 8 | {"min": 2, "max": 64} | 请求输入端数（请求向量位宽） |
| WEIGHT_WIDTH | int | 4 | {"min": 2, "max": 16} | 每路权重值的位宽（weight_i 各路的编码宽度）。决定权重上限 2^WEIGHT_WIDTH-1， 也决定配额计数器的位宽（配额窗口 = 各权重之和，上界 N*(2^W-1)） |
| WMODE | int | 0 | [0, 1] | 0=quota（配额计数）：每路独立计数已授权次数，达到权重即退出本轮，全部达到后整轮重置   （实现简单、行为直观；调度=按轮内剩余配额比例）； 1=smooth（credit 平滑）：统一 credit 减法 WRR，按"当前 credit 最大且有权重"动态选择，   剩余 credit 跨轮累计（更平滑、更接近理想权重比例，但状态/逻辑更重） |
| FAST_GRANT | int | 0 | [0, 1] | 0=combinational（grant_o 与 req_i 同拍组合输出，零延迟）； 1=registered（grant_o 输出寄存，1 拍授权延迟；关键路径从 req_i→grant_o 变为   reg→grant_o，时序更优；时钟复位：异步复位有效） |
| GRANT_ACK_EN | int | 0 | [0, 1] | 0=grant 每拍按当前请求重新决策（纯加权轮转，无锁定，公平窗口=每拍一授权）； 1=grant 锁定到 grant_ack_i 应答后轮转（消费方背压感知；防授权在未被消费前   反复切换；适合慢速/需稳定授权场景） |
| PC_IMPL | int | 0 | [0, 1] | 微架构选择（挂实现/Profile，不进公共功能语义）： 0=quota_counter 每路独立配额计数器 + RR 选择（实现简单，面积/时序折中）； 1=deficit_rotate 统一 credit 减法 + 旋转选择（平滑 WRR，时序优，状态集中） |

现有接口、时钟域及延迟约定：

```yaml
interface: native_req_grant
clock_domains: 1
ordering: weighted_round_robin
throughput: 1_per_cycle
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: 授权互斥——对任意合法 2-state 请求向量，grant_o 中至多一位有效 （无多授权、无授权冲突）。对 WMODE=0/1 与所有微架构均成立。
  properties:
  - PROP-WRRA_MUTEX-001
  tests:
  - tc_mutex
  - tc_random
  - tc_quota_window
- id: INV-002
  description: quota 权重公平（WMODE=0）——每轮配额窗口内，每路有效请求的授权次数不超过其权重值； 所有未饱和路授权完成后整轮重置（各计数清零）；连续满请求下授权比例趋近权重比例，
    不超发、不饿死（每轮至少授予每路一次，若其权重>0 且有请求）。
  properties:
  - PROP-WRRA_QUOTA-002
  tests:
  - tc_quota_window
  - tc_random
- id: INV-003
  description: 无请求 → grant_o 全零；有请求 → 恰好一个授权（活性：不丢授权）。 权重为 0 的请求不参与选择（视为无资格，不阻塞其它请求）。
  properties:
  - PROP-WRRA_NONE-003
  tests:
  - tc_edge
  - tc_random
- id: INV-004
  description: smooth WRR（WMODE=1，credit 平滑）——每轮按"credit 最大且有资格（权重>0 且有请求）" 的路动态选择；被授权路
    credit 减少 1，未授权路不变；所有资格路 credit 耗尽后统一回补 （各加权重），实现跨轮累计、比例趋近权重且无负 credit（不超发）。
  properties:
  - PROP-WRRA_SMOOTH-004
  tests:
  - tc_smooth_ratio
  - tc_random
- id: INV-005
  description: FAST_GRANT=1（registered）——grant_o 相对组合参考模型延迟 1 拍， 且每周期组合参考（req_i/weight_i
    经加权 RR 选择）等于寄存 grant 一拍前的期望。
  properties:
  - PROP-WRRA_REG-005
  tests:
  - tc_registered
  - tc_equiv
- id: INV-006
  description: GRANT_ACK_EN=1（ack 锁定）——grant 在未被 grant_ack_i 应答前保持锁定不变； ack 应答后按加权
    RR 顺序移动到下一请求（或重新选择）。此模式要求消费方应答， 否则授权不轮转（防活锁由消费方保证）。
  properties:
  - PROP-WRRA_ACK-007
  tests:
  - tc_ack_lock
```

### 环境假设

```yaml
- id: ASM-001
  description: 输入 X/Z 不承诺（2-state 仿真语义；X 传播视为未定义）。
- id: ASM-002
  description: GRANT_ACK_EN=1 时，grant_ack_i 必须在 grant_o 有效后的下一拍内拉高 （或在授权保持期间），否则授权保持（防活锁由消费方保证）。
- id: ASM-003
  description: WMODE / FAST_GRANT / GRANT_ACK_EN / PC_IMPL 为编译期参数，不运行时切换 （生成/参数化语义）。
- id: ASM-004
  description: FAST_GRANT=1 或 GRANT_ACK_EN=1 需要 clk/rst_n；纯组合配置 （FAST_GRANT=0 且 GRANT_ACK_EN=0）可不接时钟（RTL
    仍保留端口，接 clk 亦可）。
- id: ASM-005
  description: 权重端口 weight_i 由上游静态/低频配置提供（每路独立编码）；WRR 公平语义建立在 权重比例之上，权重为 0 的路永不被授权（除非
    WMODE=1 且其为唯一资格路，见 INV-004）。
- id: ASM-006
  description: quota 窗口重置时机为"本轮所有未饱和资格路授权完成后的下一拍"；窗口内授权不保证 连续（若某路无请求或权重为 0，其配额不消耗、直接跳过）。
```

### 非目标

```yaml
- 包长/字节感知的 Deficit RR（ARB-004 deficit_rr_arbiter，量子粒度）。
- 年龄/时间戳公平（ARB-005 age_based_arbiter）。
- 随机/抽奖调度（ARB-006 lottery_arbiter，LFSR 加权）。
- 多授权（top-K 同时授权，ARB-007 multi_grant_arbiter）。
- 层次化跨模块仲裁（ARB-008 hierarchical_arbiter）。
- 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍）。
- 运行时权重热更新（weight_i 变化视作上游配置约束，窗口内不原子切换）。
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

