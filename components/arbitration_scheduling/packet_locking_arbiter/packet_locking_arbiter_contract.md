---
document_type: cbb-requirements
registry_id: ARB-010
name: packet_locking_arbiter
version: 0.1.0
status: derived
basis: existing_yaml
source_hashes:
  cbb.yaml: 6eed77edc75a8d44ab93e19001a5d444c68863bc1653aa07bad51f648d7a9e9a
  behavior.yaml: 74504d874b2d003264c2f521b8bb99829b2905246504f1c396ecfdd4ba46ebea
---

# packet_locking_arbiter 需求合同

本文是现有工程 YAML 的可读需求视图，参数/行为以所链接源文件为准。本文不引入新实现要求、不更新 Gate，也不把历史验证推广到全部配置。

| 字段 | 内容 |
|---|---|
| 索引 ID | ARB-010 |
| 资产版本 | 0.1.0 |
| 分类/路径 | components/arbitration_scheduling / components/arbitration_scheduling/packet_locking_arbiter |
| 功能家族 | Packet-locking Arbiter |
| 优先级 | P1 |
| 当前登记状态 | implemented |

## 1. 定位与使用场景

锁定状态与公平性

拟复用场景：DMA 多请求共享端口；多 Bank 数据通路资源分配。这些是需求场景，不表示已有消费者依赖或完成集成。

## 2. 已有需求与行为基线

| 原需求 ID | 源契约条目（保留原文） | 已有测试映射 | 来源 |
|---|---|---|---|
| REQ-001 | Grant is one-hot-or-zero; reset forces grant zero; initially requester zero has highest priority. | tc_reset_mutex | [behavior.yaml](behavior.yaml) |
| REQ-002 | First visible grant reserves owner across sampled backpressure and request bubbles; no competing source may interleave. | tc_stall_bubble | [behavior.yaml](behavior.yaml) |
| REQ-003 | EOP mode releases only on ready_i and selected req_i and selected eop_i; single-beat packets release immediately. | tc_eop, tc_single_beat | [behavior.yaml](behavior.yaml) |
| REQ-004 | Length mode samples selected length on reservation, counts accepted beats including first beat, ignores EOP, and releases exactly at sampled length. | tc_length, tc_length_stall | [behavior.yaml](behavior.yaml) |
| REQ-005 | Priority rotates only after packet completion to successor of owner modulo NUM_REQ; consecutive packets have no required bubble. | tc_rr_order, tc_back_to_back, tc_random | [behavior.yaml](behavior.yaml) |
| REQ-006 | With eventual owner progress and completion, a continuously eligible requester waits at most NUM_REQ-1 other completed packets. | tc_fairness | [behavior.yaml](behavior.yaml) |
| REQ-007 | Length zero is ineligible before reservation in length mode; legal contenders continue; invalid elaboration parameters are rejected. | tc_zero_length, tc_negative_params | [behavior.yaml](behavior.yaml) |

## 3. 参数与接口契约

| 参数 | 类型 | 默认值 | 合法域 | 语义 |
|---|---|---|---|---|
| NUM_REQ | int | 4 | {"min": 1, "max": 64} | Number of requesters; arbitrary non-power-of-two counts supported. |
| LOCK_MODE | int | 0 | [0, 1] | 0 releases on accepted EOP; 1 releases after sampled packet length accepted beats. |
| LEN_W | int | 8 | {"min": 1, "max": 16} | Packet length width; legal runtime length is 1 through 2**LEN_W-1; ignored in EOP mode. |

现有接口、时钟域及延迟约定：

```yaml
interface: request_grant_packet_control
hwif_binding: none
hwif_rationale: Control-only arbiter, no payload or AXI/Stream interface; consumer
  binds protocol valid/ready/last.
clock_domains: 1
ordering: packet_atomic_round_robin
throughput: 1_accepted_beat_per_cycle
reset: asynchronous_active_low_assert_synchronous_external_release
```

## 4. 不变量、复位与异常

### 不变量

```yaml
- id: INV-001
  description: fire = ready_i and OR(grant_o and req_i); grant denotes ownership,
    not accepted data.
- id: INV-002
  description: Locked owner is unchanged until packet completion or reset, including
    cycles with its req_i low.
- id: INV-003
  description: Idle request eligibility is req_i and (LOCK_MODE equals zero or packet
    length is nonzero).
```

### 环境假设

```yaml
- id: ASM-001
  description: All inputs are synchronous 2-state values; reset deassertion is synchronized
    externally.
- id: ASM-002
  description: Unaccepted valid beat and its EOP metadata remain stable; packet length
    is stable until reservation. After a beat is accepted, owner may insert arbitrary
    valid bubbles.
- id: ASM-003
  description: Consumer muxes payload using grant_o and gates outgoing valid with
    OR(grant_o and req_i); ready_i reflects downstream acceptance capacity without
    a combinational loop.
- id: ASM-004
  description: Fairness requires eventual downstream acceptance, resumed owner valid,
    and EOP or sufficient declared-length beats; no cycle-bound or byte-weight fairness
    is promised.
```

### 时序

```yaml
first_grant_latency_cycles: 0
reservation: First rising edge with visible eligible grant, even if ready_i is low.
length_sampling: At reservation edge, including a first-beat handshake on that edge.
completion: Rising edge accepting final beat; next cycle may grant next packet.
reset: Asynchronous reset clears ownership and resets round-robin priority; all outputs
  masked during reset.
```

### 异常

```yaml
- id: EXC-001
  description: Missing EOP or truncated declared-length packet retains ownership indefinitely;
    reset is recovery.
- id: EXC-002
  description: Zero runtime length receives no grant in length mode and must be repaired
    by producer; no hardware error port.
```

### 非目标

```yaml
- Payload multiplexing, buffering, CSR, CDC, abort, watchdog or automatic packet discard.
- Weighted, byte-fair or deficit scheduling; registered output and multiple implementation
  profiles in version 0.1.0.
```

## 5. 验收与变更边界

按上述原需求 ID、测试与配置映射执行验收，完整约束和验证配置见已有工程。原需求表中的测试名是源模型声明，本文不代表已重跑。修改这些行为须先修改 owner YAML，重建追踪与证据，再刷新本文。

设计规格入口：[docs/cbb_spec.md](docs/cbb_spec.md)。门禁与 PPA 结论仍由具体版本、参数和工具证据决定。

