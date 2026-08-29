# weighted_rr_arbiter 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1 并经用户规格确认门确认。
> 详设（微架构/逻辑深度/PPA 优化点/生成方式）见 [`docs/detail-design/`](detail-design/)（quota_counter/deficit_rotate）。

## 1. 模块划分

```
weighted_rr_arbiter（wrapper，极简单单文件）
├── 参数检查：generate $error（PC-001..008，elaboration 期拦截）
├── 请求源：req_i 直通（无 latched；ack 锁定由 GRANT_ACK_EN 状态机提供）
├── 权重源：weight_i[NUM_REQ*WEIGHT_WIDTH-1:0] 解析为每路权重（静态/低频配置，ASM-005）
├── 资格计算：valid_mask = req_i & (weight > 0)（权重 0 无资格，INV-003）
├── 加权选择核心（WMODE 分派）：
│   ├── WMODE=0 quota：每路独立配额计数器 quota_cnt[i]（复位=权重 w[i]），
│   │   授权后 -1；从 round-robin 指针起在"仍有配额且有请求"的路中选首个（RR 序轮转）
│   └── WMODE=1 smooth：统一 credit 状态 credit[i]（复位=权重 w[i]），
│       每轮选 credit 最大且有资格的路；被选路 credit -= N（跨轮累计，无负 credit）
├── ack 锁定（GRANT_ACK_EN=1）：grant 保持至 grant_ack_i 应答后更新指针/配额（INV-006）
├── 输出级：FAST_GRANT=0 组合授权 / =1 寄存授权（异步复位清零）
└── 就近 SVA：@(posedge clk) 并发断言（INV-001..006）
```

- RTL 布局：**默认单文件** `rtl/weighted_rr_arbiter.sv`（wrapper + 两实现同居，WMODE/PC_IMPL 编译期分派）。
- 嵌套依赖：无（`implementations[].dependencies[]` 为空）。

## 2. 多实现与 Profile

**共享同一可观察契约**（授权互斥 + 权重公平语义一致），差异仅在加权轮转结构（domain-rules §4）。
功能参数（WMODE/FAST_GRANT/GRANT_ACK_EN）与微架构参数（PC_IMPL）分离。

| Profile | implementation | WMODE | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|---|
| `quota_small` | impl_quota_counter | 0 | area | N≤8、权重区分明显、面积极优先 | supported |
| `quota_reg` | impl_quota_counter | 0 (FAST_GRANT=1) | timing | 小 N + 寄存授权（1 拍） | experimental |
| `smooth_credit` | impl_deficit_rotate | 1 | fairness_smooth | 需要更平滑/接近理想权重比例的调度 | experimental |
| `ack_lock` | impl_quota_counter | 0 (GRANT_ACK_EN=1) | stable_grant | 慢速/需稳定授权场景 | experimental |

> 注：PC_IMPL（0=quota_counter / 1=deficit_rotate）是微架构选择；WMODE 是功能公平语义。
> 多实现等价验证（REQ-006）要求两实现（quota_counter / deficit_rotate）在 WMODE=0 时共享同一可观察契约。
> smooth_credit Profile（WMODE=1）语义上仅由 deficit_rotate 实现承担（其"统一 credit"本质即 smooth WRR）。

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 单 `clk`（FAST_GRANT=1 或 GRANT_ACK_EN=1 时使用；纯组合配置可悬空） |
| 复位 | 异步 `rst_n`（低有效）；释放后寄存状态（quota_cnt/credit/rr_ptr/grant_o）清零，rr_ptr 初始 0 |
| X 语义 | 输入 X/Z 不承诺（ASM-001）；2-state 仿真语义 |
| 异常行为 | 无请求→grant=0；ack 锁定无应答时授权保持（防活锁由消费方保证 ASM-002）；权重 0 路不被选（INV-003） |

## 4. 关键数据路径（契约细化）

### 4.1 资格计算（INV-003）

```
qual[i] = req_i[i] & (weight_i[i] != 0)     // 权重 0 无资格
```

- 无资格/无请求路不参与选择，不阻塞其它路。

### 4.2 quota 加权选择（WMODE=0，INV-002）

```
quota_cnt[i]  复位 = weight_i[i]（每轮窗口起始各路配额=权重）
选择（从 rr_ptr 起回绕）：
  eligible = qual & (quota_cnt > 0)
  grant    = rr_select(eligible)            // 从 rr_ptr 起扫描 eligible 首个置位
授权后：quota_cnt[grant_idx] -= 1
窗口重置：当 eligible 全 0 且 |qual（仍有资格但配额耗尽）→ 全部 quota_cnt 复位为权重（下一轮）
```

- 公平窗口语义：一轮内各有效请求授权次数 ≤ 权重（不超发）；每路权重>0 且有请求至少授权一次（不饿死）。
- RR 序在"有配额且有请求"路中轮转（窗口内顺序按 RR 公平轮流）。

### 4.3 smooth credit 加权选择（WMODE=1，INV-004）

```
credit[i]  复位 = weight_i[i]
选择（从 rr_ptr 起回绕，选 credit 最大且有资格）：
  grant = argmax(credit, over qual)         // 平局取 RR 序最先
授权后：credit[grant_idx] -= N              // 扣除总额（实现为：每路每轮 credit += weight，被选路 credit -= N 等价）
回补：当所有资格路 credit 之和不足以再授权（或全部 < N）→ credit[i] += weight_i[i]（跨轮累计）
```

- 经典 smooth WRR（单槽 credit 累积）：每周期各资格路 credit 递增其权重，被选路一次性扣 N；
  选择 credit 最大者。等效实现为"复位=权重；被选路 -N；资格路全小于 N 时统一 +权重"。
- 无负 credit（不超发）；跨轮累计使比例趋近理想权重。

### 4.4 多实现等价（REQ-006，PC_IMPL）

- `impl_quota_counter`（PC_IMPL=0）：**上述 WMODE=0 quota 的直接实现**——每路独立配额计数器 + RR 选择。
- `impl_deficit_rotate`（PC_IMPL=1）：统一 credit 减法 + 旋转选择；当 WMODE=0 时退化为与 quota 相同
  的可观察行为（共享同一契约，用于跨实现等价验证）。

### 4.5 ack 锁定（GRANT_ACK_EN=1，INV-006）

- `grant` 保持至 `grant_ack_i` 应答；应答后按加权 RR 移动到下一请求并更新配额/credit；
  未应答不更新（ASM-002 防活锁由消费方保证）。

### 4.6 寄存授权（FAST_GRANT=1，INV-005）

- `grant_o <= grant_mid`（输出寄存，1 拍延迟；异步复位清零）；与组合参考一致。

## 5. 可验证性论证

- 每个 Profile 有验证路径：SVA（模块内 @(posedge clk) 并发断言）+ Simulation（互斥/配额窗口/
  smooth 比例/边界/随机/等价/寄存/ack 锁定）+ 负向 elab（非法参数）。
- 关键不变量映射 PROP：`PROP-WRRA_MUTEX-001`/`PROP-WRRA_QUOTA-002`/`PROP-WRRA_NONE-003`/
  `PROP-WRRA_SMOOTH-004`/`PROP-WRRA_REG-005`/`PROP-WRRA_EQV-006`/`PROP-WRRA_ACK-007`
  （见 [`trace/rtm.yaml`](../trace/rtm.yaml)）。
- Profile 差异验证重点：两实现跨实现一致（tc_equiv）+ 配额窗口公平（tc_quota_window）+
  smooth 比例（tc_smooth_ratio）+ PPA 收敛实证（G6）。

## 6. PPA 预筛（E0/E1 → G6 实证）

- 定性：WRR 选择本质为"资格过滤 + RR 扫描 + 配额/credit 状态"：
  - quota_counter：每路独立计数器（N×W 位寄存器）+ RR 扫描；面积 O(N·W)，时序 O(N)（扫描链）或 O(log N)（旋转+编码）。
  - deficit_rotate：统一 credit（N×CW 位寄存器，CW≈W+logN）+ 旋转选择 + 减法；面积略高，时序 O(log N)。
- 预期 Pareto：N 小时 quota_counter 面积最小；N≥16 且需平滑时 deficit_rotate 时序/公平更优。
- 证据等级：E2（DC 综合 sweep，单 corner tt_1p00v_25c，CMOS28LP）——G6 实证（见 [`reports/ppa-report.md`](../reports/ppa-report.md)）。

## 7. 子依赖（若有）

无运行时子依赖。非目标：Deficit RR/age/lottery/multi-grant/层次仲裁/流水化（ARB-004/005/006/007/008）。
