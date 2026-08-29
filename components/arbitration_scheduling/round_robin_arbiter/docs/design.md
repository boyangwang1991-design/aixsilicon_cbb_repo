# round_robin_arbiter 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1 并经用户规格确认门确认。
> 详设（微架构/逻辑深度/PPA 优化点/生成方式）见 [`docs/detail-design/`](detail-design/)（mask/rotate_prio/pointer）。

## 1. 模块划分

```
round_robin_arbiter（wrapper，极简单单文件）
├── 参数检查：generate $error（PC-001..006，elaboration 期拦截）
├── 请求源：REQ_TYPE=0 level 直通 / REQ_TYPE=1 latched 锁存寄存器（ack 应答清除）
├── RR 指针状态：rr_ptr（本轮授权起始位；PC_IMPL=0/1/2 统一维护，公平窗口语义一致）
├── 核心分派（PC_IMPL）：rra_impl_mask / rra_impl_rotate_prio / rra_impl_pointer
│   ├── mask：轮转掩码优先链 grant = base_priority(req & ~lower_mask) | wrap_priority(...)（O(N) 深）
│   ├── rotate_prio：rotated = {req[ptr-1:0], req[N-1:ptr]} 旋转后 LSB 优先编码（O(log N) 深）
│   └── pointer：二进制指针 ptr + 循环移位选择（area/timing 折中，N 大 LUT 友好）
├── ack 锁定（GRANT_ACK_EN=1）：grant 保持至 grant_ack_i 应答后更新 rr_ptr
├── 输出级：FAST_GRANT=0 组合授权 / =1 寄存授权（异步复位清零）
└── 就近 SVA：@(posedge clk) 并发断言（INV-001..006）
```

- RTL 布局：**默认单文件** `rtl/round_robin_arbiter.sv`（wrapper + 三实现同居，PC_IMPL 编译期分派）。
- 嵌套依赖：无（`implementations[].dependencies[]` 为空）。

## 2. 多实现与 Profile

**共享同一可观察契约**（授权互斥 + 轮转公平语义一致），差异仅在轮转选择结构（domain-rules §4）。

| Profile | implementation | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|
| `mask_area` | impl_mask | area | N≤8 面积极优先、经典 RR mask 法 | supported |
| `mask_area_reg` | impl_mask (FAST_GRANT=1) | timing | 小 N + 寄存授权（1 拍） | experimental |
| `rotate_timing` | impl_rotate_prio | timing | N≥16 fmax 优先 | supported |
| `pointer_balanced` | impl_pointer | balanced | N=8~32 面积/时序均衡 | experimental |
| `ack_lock` | impl_mask (GRANT_ACK_EN=1) | stable_grant | 慢速/需稳定授权场景 | experimental |

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 单 `clk`（FAST_GRANT=1 或 REQ_TYPE=1 或 GRANT_ACK_EN=1 时使用；纯组合配置可悬空） |
| 复位 | 异步 `rst_n`（低有效）；释放后寄存输出（req_hold/rr_ptr/grant_o）清零，rr_ptr 初始为 0 |
| X 语义 | 输入 X/Z 不承诺（ASM-001）；2-state 仿真语义 |
| 异常行为 | 无请求→grant=0；latched/ack 锁定无应答时授权保持（防活锁由消费方保证 ASM-002） |

## 4. 关键数据路径（契约细化）

### 4.1 轮转选择（核心，从 rr_ptr 起扫描首个置位）

统一语义：`selected = first_set(req 从 rr_ptr 起回绕扫描)`。

- **impl_mask（O(N) 深，经典 mask 法）**：
  `lower = req & ((1<<rr_ptr)-1)`（rr_ptr 以下位）；`upper = req & ~((1<<rr_ptr)-1)`（rr_ptr 及以上位）；
  `grant = (upper != 0) ? first_set(upper) : first_set(lower)`。
  逻辑深度 ≈ 两段优先级链 + 一级 MUX（O(N)）。
- **impl_rotate_prio（O(log N) 深）**：`rotated = {req[rr_ptr-1:0], req[N-1:rr_ptr]}`（按 rr_ptr 旋转，
  rr_ptr 位在新向量 LSB）；`grant_rot = first_set(rotated)`（LSB 优先编码，O(log N)）；`grant = 逆旋转`。
  旋转用 N 路 barrel shift（每输出位 O(log N) MUX 深）。
- **impl_pointer（折中）**：维护二进制 `rr_ptr`，用循环移位器产生旋转向量后 LSB 优先选择；
  面积略大于 rotate_prio（显式移位器），但可读性好、N 大时 LUT 映射友好。

三实现共享 `rr_ptr` 状态与轮转语义，仅改变"从 ptr 起选择首个置位"的实现方式。

### 4.2 轮转公平窗口（INV-002/ASM-005）

- 纯轮转（GRANT_ACK_EN=0）：每拍按当前 `req` 决策，`rr_ptr` 更新为 `(grant_index+1) % N`。
  单请求一直有效 → 重复授权同一位（不饿死其它请求）；连续多请求 → 按 ptr 循环轮流。
- ack 锁定（GRANT_ACK_EN=1）：`grant` 保持至 `grant_ack_i` 应答，应答后按 RR 移动到下一请求；
  未应答不更新（INV-006，ASM-002 防活锁由消费方保证）。

### 4.3 锁存（REQ_TYPE=1）

- `req_hold <= (req_hold | req_i) & ~(grant_ack_i ? grant_mid : 0)`
- 捕获新请求；ack 应答后清除被授权请求；未应答时授权保持（INV-004）

### 4.4 寄存授权（FAST_GRANT=1）

- `grant_o <= grant_mid`（输出寄存，1 拍延迟；异步复位清零）
- 与组合参考一致（INV-005，G4 tc_registered 已验）

## 5. 可验证性论证

- 每个 Profile 有验证路径：SVA（模块内 @(posedge clk) 并发断言）+ Simulation（穷举/随机/等价/轮转序）
  + 负向 elab（非法参数）；跨实现等价（tc_equiv）覆盖多实现一致。
- 关键不变量映射 PROP：`PROP-RRA_MUTEX-001`/`PROP-RRA_FAIR-002`/`PROP-RRA_NONE-003`/
  `PROP-RRA_LATCH-004`/`PROP-RRA_REG-005`/`PROP-RRA_EQV-006`/`PROP-RRA_ACK-007`（见 [`trace/rtm.yaml`](../trace/rtm.yaml)）。
- Profile 差异验证重点：三实现跨实现一致（tc_equiv）+ 轮转公平序（tc_rr_order）+ PPA 收敛实证（G6）。

## 6. PPA 预筛（E0/E1 → G6 实证）

- 定性：RR 选择本质为"循环移位 + 优先级编码"：面积 O(N)、时序 O(log N)（LSB 优先编码器综合最优）；
  mask 法两段链 O(N) 深度，rotate 法 barrel 移位 O(log N)，pointer 法显式移位器折中。
- 预期 Pareto：N 小时 mask 面积最小；N≥16 时 rotate/pointer 时序更优。
- 证据等级：E2（DC 综合 sweep，单 corner tt_1p00v_25c，CMOS28LP）——G6 实证（见 [`reports/ppa-report.md`](../reports/ppa-report.md)）。

## 7. 子依赖（若有）

无运行时子依赖。非目标：WRR/Deficit/age/multi-grant/层次仲裁/流水化（ARB-003/004/005/007/008）。
