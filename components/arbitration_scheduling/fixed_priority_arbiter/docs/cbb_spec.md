# fixed_priority_arbiter 规格说明（G1 可读视图）

> **派生视图**：SSOT 为 [`cbb.yaml`](../cbb.yaml)（+[`behavior.yaml`](../behavior.yaml)），本文件仅为人工程序可读副本，**语义以 YAML 为准**（不双维护）。

## 1. 定位

固定优先级仲裁器：对请求向量按固定优先级选出唯一授权（授权互斥 + 优先级链语义），支持
LSB/MSB 优先、锁存请求（latched）、寄存授权（FAST_GRANT）与三种微架构。

- 抽象粒度：`A2`（通用复合：仲裁机制，非协议绑定）
- 技术域：`arbitration_scheduling`（次：`selection_decode`）
- Registry ID：`ARB-001`

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） | 配置（cfg_*） |
|---|---|---|---|---|
| REQ-001 | 授权互斥——最多一个 grant_o 有效 | `PROP-FPA_MUTEX-001` | tc_mutex, tc_random, tc_exhaust_w4 | cfg_num_req2/8/64_...pc_impl0 |
| REQ-002 | 优先级语义——LSB/MSB 优先扫描首个置位 | `PROP-FPA_PRIO-002` | tc_priority, tc_edge | cfg_num_req8_priority0/1_... |
| REQ-003 | 无请求→grant=0；有请求必有且仅有一个授权 | `PROP-FPA_NONE-003` | tc_edge | cfg_num_req4_...pc_impl0 |
| REQ-004 | REQ_TYPE=1 锁存：grant 保持至 ack 后清除 | `PROP-FPA_LATCH-004` | tc_latched | cfg_num_req8_...req_type1_... |
| REQ-005 | FAST_GRANT=1：寄存授权延迟 1 拍且与组合一致 | `PROP-FPA_REG-005` | tc_registered, tc_equiv | cfg_num_req8_...fast_grant1_... |
| REQ-006 | 多实现（linear/tree/grouped）共享契约且等价 | `PROP-FPA_EQV-006` | tc_equiv | cfg_num_req8/32_...pc_impl0 |
| REQ-007 | 非法参数组合在 Elaboration 期被拦截 | （负向编译证据） | tc_negative_elab | cfg_num_req1/65_...（negative） |

> 完整映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)（工具生成）。

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `NUM_REQ` | int | 8 | 2..64 | 请求端数（请求向量位宽） |
| `PRIORITY` | int | 0 | {0,1} | 0=LSB 优先；1=MSB 优先 |
| `REQ_TYPE` | int | 0 | {0,1} | 0=level 纯组合；1=latched 锁存 |
| `FAST_GRANT` | int | 0 | {0,1} | 0=组合授权；1=寄存授权（1 拍） |
| `PC_IMPL` | int | 0 | {0,1,2} | 微架构：0=linear/1=tree/2=grouped |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | `NUM_REQ >= 2` | 防单路无仲裁语义 |
| PC-002 | `NUM_REQ <= 64` | 防超宽优先链（RTL 平面/时序上界） |
| PC-003 | `PRIORITY ∈ {0,1}` | 枚举合法域 |
| PC-004 | `REQ_TYPE ∈ {0,1}` | 枚举合法域 |
| PC-005 | `FAST_GRANT ∈ {0,1}` | 枚举合法域 |
| PC-006 | `PC_IMPL ∈ {0,1,2}` | 枚举合法域 |

> 非法组合在 Elaboration 前被拦截（`cbb_tool.py check` + RTL `$error` generate 双拦截）。

## 4. 行为不变量（INV）与假设（ASM）

- 不变量：`INV-001` 授权互斥 / `INV-002` 优先级语义（授权为请求子集 + 更高优先级段无请求）
  / `INV-003` 无请求→grant=0、有请求→恰一授权 / `INV-004` 锁存保持 / `INV-005` 寄存授权 1 拍
- 时序：组合授权零延迟（FAST_GRANT=0）；寄存授权 1 拍延迟（FAST_GRANT=1）
- 假设：`ASM-001` 输入 X/Z 不承诺；`ASM-002` latched 活锁由消费方保证（ack 必须应答）；
  `ASM-003` 编译期参数不运行时切换；`ASM-004` FAST_GRANT=1 需 clk/rst_n
- 异常：复位释放后 grant=0（寄存输出清零）

## 5. 接口与时钟复位

- 接口：`native_req_grant`（request/grant 位向量，无总线协议语义；不引用 HWIF——无 AXI/APB/Stream 契约）
- 端口：`req_i[NUM_REQ-1:0]`、`grant_ack_i`（REQ_TYPE=1 应答）、`grant_o[NUM_REQ-1:0]`
- 时钟：1 个（`clk`，FAST_GRANT/REQ_TYPE=1 时使用）；复位：`rst_n` 低有效异步复位

## 6. 假设与非目标（non-goals）

| 项 | 内容 |
|---|---|
| 非目标 1 | 轮转/加权/公平性调度（RR/WRR/Deficit，ARB-002/003/004） |
| 非目标 2 | 多授权（top-K，ARB-007 multi_grant_arbiter） |
| 非目标 3 | 层次化跨模块仲裁（ARB-008 hierarchical_arbiter） |
| 非目标 4 | 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍） |

## 7. 集成限制

- 限制 1：`REQ_TYPE=1`（latched）时消费方必须在授权保持期间应答 `grant_ack_i`，否则授权保持（防活锁由消费方保证，ASM-002）
- 限制 2：`FAST_GRANT=1` 需要提供 `clk`/`rst_n`（异步复位清零）
- 限制 3：非目标调度语义（RR/WRR 等）请用对应 CBB（ARB-002/003）
