# weighted_rr_arbiter 规格说明（G1 可读视图）

> **派生视图**：SSOT 为 [`cbb.yaml`](../cbb.yaml)（+[`behavior.yaml`](../behavior.yaml)），本文件仅为人工程序可读副本，**语义以 YAML 为准**（不双维护）。

## 1. 定位

带权轮转（Weighted Round-robin）仲裁器：对请求向量按**权重比例公平**选出唯一授权（授权互斥 + 权重公平，无静态优先），
支持配额计数（quota）与平滑 credit（smooth WRR）两种公平语义，以及寄存授权（FAST_GRANT）与 ack 锁定（GRANT_ACK_EN），
并提供两种微架构（quota_counter / deficit_rotate）。

- 抽象粒度：`A2`（通用复合：加权仲裁机制，非协议绑定）
- 技术域：`arbitration_scheduling`（次：`selection_decode`）
- Registry ID：`ARB-003`

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） | 配置（cfg_*） |
|---|---|---|---|---|
| REQ-001 | 授权互斥——最多一个 grant_o 有效 | `PROP-WRRA_MUTEX-001` | tc_mutex, tc_random, tc_quota_window | cfg_num_req2/8/64_... |
| REQ-002 | 权重公平（quota）——窗口内授权次数不超权重，比例趋近权重 | `PROP-WRRA_QUOTA-002` | tc_quota_window, tc_random | cfg_num_req4/8_... |
| REQ-003 | 无请求→grant=0；有请求必有且仅有一个授权 | `PROP-WRRA_NONE-003` | tc_edge, tc_random | cfg_num_req4_... |
| REQ-004 | smooth WRR（WMODE=1）——credit 最大且有权重的请求被选，跨轮累计，无负 credit | `PROP-WRRA_SMOOTH-004` | tc_smooth_ratio, tc_random | cfg_num_req8_..._wmode1_... |
| REQ-005 | FAST_GRANT=1：寄存授权延迟 1 拍且与组合一致 | `PROP-WRRA_REG-005` | tc_registered, tc_equiv | cfg_num_req8_..._fast_grant1_... |
| REQ-006 | 多实现（quota_counter/deficit_rotate）共享契约且等价 | `PROP-WRRA_EQV-006` | tc_equiv, tc_quota_window | cfg_num_req8/32_..._pc_impl0/1_... |
| REQ-007 | GRANT_ACK_EN=1：grant 锁定到 ack 应答后轮转 | `PROP-WRRA_ACK-007` | tc_ack_lock | cfg_num_req8_..._grant_ack_en1 |
| REQ-008 | 非法参数组合在 Elaboration 期被拦截 | （负向编译证据） | tc_negative_elab | cfg_num_req1/65/ww1/ww17_...（negative） |

> 完整映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)（工具生成）。

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `NUM_REQ` | int | 8 | 2..64 | 请求端数（请求向量位宽） |
| `WEIGHT_WIDTH` | int | 4 | 2..16 | 每路权重值位宽（权重上限 2^W-1；配额计数器位宽） |
| `WMODE` | int | 0 | {0,1} | 0=quota（配额计数）；1=smooth（credit 平滑 WRR） |
| `FAST_GRANT` | int | 0 | {0,1} | 0=组合授权；1=寄存授权（1 拍） |
| `GRANT_ACK_EN` | int | 0 | {0,1} | 0=每拍重新决策；1=grant 锁定至 ack 应答 |
| `PC_IMPL` | int | 0 | {0,1} | 微架构：0=quota_counter；1=deficit_rotate |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | `NUM_REQ >= 2` | 防单路无仲裁语义 |
| PC-002 | `NUM_REQ <= 64` | 防超宽轮转链（RTL 平面/时序上界） |
| PC-003 | `WEIGHT_WIDTH >= 2` | 权重至少 2 位（权重可分辨 0..3） |
| PC-004 | `WEIGHT_WIDTH <= 16` | 权重/配额计数器位宽上界（防溢出） |
| PC-005 | `WMODE ∈ {0,1}` | 枚举合法域 |
| PC-006 | `FAST_GRANT ∈ {0,1}` | 枚举合法域 |
| PC-007 | `GRANT_ACK_EN ∈ {0,1}` | 枚举合法域 |
| PC-008 | `PC_IMPL ∈ {0,1}` | 枚举合法域 |

> 非法组合在 Elaboration 前被拦截（`cbb_tool.py check` + RTL `$error` generate 双拦截）。

## 4. 行为不变量（INV）与假设（ASM）

- 不变量：`INV-001` 授权互斥 / `INV-002` quota 权重公平（窗口内不超发、不饿死）/ `INV-003` 无请求→grant=0、
  有请求→恰一授权（权重 0 无资格）/ `INV-004` smooth credit（credit 最大者被选、跨轮累计、无负 credit）
  / `INV-005` 寄存授权 1 拍 / `INV-006` ack 锁定（GRANT_ACK_EN=1 时 grant 保持至应答）
- 时序：组合授权零延迟（FAST_GRANT=0）；寄存授权 1 拍延迟（FAST_GRANT=1）
- 假设：`ASM-001` 输入 X/Z 不承诺；`ASM-002` ack 锁定活锁由消费方保证（ack 必须应答）；
  `ASM-003` 编译期参数不运行时切换；`ASM-004` FAST_GRANT/GRANT_ACK_EN=1 需 clk/rst_n；
  `ASM-005` 权重端口静态/低频配置，权重 0 路不被授权；`ASM-006` quota 窗口重置时机为所有未饱和资格路授权完成后的下一拍
- 异常：复位释放后 grant=0（寄存输出清零）

## 5. 接口与时钟复位

- 接口：`native_req_grant`（request/grant 位向量 + weight_i 权重端口；无总线协议语义；不引用 HWIF——无 AXI/APB/Stream 契约）
- 端口：`req_i[NUM_REQ-1:0]`、`weight_i[NUM_REQ-1:0][WEIGHT_WIDTH-1:0]`（或按 RTL 展开为
  `weight_i[NUM_REQ*WEIGHT_WIDTH-1:0]`）、`grant_ack_i`（GRANT_ACK_EN=1 时应答）、`grant_o[NUM_REQ-1:0]`
- 时钟：1 个（`clk`，FAST_GRANT/GRANT_ACK_EN 时使用）；复位：`rst_n` 低有效异步复位

## 6. 假设与非目标（non-goals）

| 项 | 内容 |
|---|---|
| 非目标 1 | Deficit RR（包长/字节量子，ARB-004 deficit_rr_arbiter） |
| 非目标 2 | 年龄/时间戳公平（ARB-005 age_based_arbiter） |
| 非目标 3 | 随机/抽奖调度（ARB-006 lottery_arbiter） |
| 非目标 4 | 多授权（top-K，ARB-007 multi_grant_arbiter） |
| 非目标 5 | 层次化跨模块仲裁（ARB-008 hierarchical_arbiter） |
| 非目标 6 | 流水化/多拍事务语义（单周期决策；寄存授权仅 1 拍） |
| 非目标 7 | 运行时权重热更新（weight_i 变化视作上游配置约束，窗口内不原子切换） |

## 7. 集成限制

- 限制 1：`GRANT_ACK_EN=1` 时消费方必须在授权保持期间应答 `grant_ack_i`，否则授权保持（防活锁由消费方保证，ASM-002）
- 限制 2：`FAST_GRANT=1` / `GRANT_ACK_EN=1` 需要提供 `clk`/`rst_n`（异步复位清零）
- 限制 3：非目标调度语义（Deficit/age/lottery）请用对应 CBB（ARB-004/005/006）
- 限制 4：权重为 0 的请求在 WMODE=0 下永不被授权；smooth 模式下仅当其是唯一资格路时才可能被选
