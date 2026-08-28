# fixed_priority_arbiter 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1。
> 详设（微架构/逻辑深度/PPA 优化点/生成方式）见 [`docs/detail-design/`](detail-design/)（linear/tree/grouped）。

## 1. 模块划分

```
fixed_priority_arbiter（wrapper，极简单单文件）
├── 参数检查：generate $error（PC-001..006，elaboration 期拦截）
├── 请求源：REQ_TYPE=0 level 直通 / REQ_TYPE=1 latched 锁存寄存器（ack 应答清除）
├── 优先级归一化：PRIORITY=0 直通 / PRIORITY=1 bit-reverse（核心统一 LSB 优先）
├── 核心分派（PC_IMPL）：fpa_impl_linear / fpa_impl_tree / fpa_impl_grouped
│   ├── linear：显式链 grant[i]=req[i] & ~|req[i-1:0]（O(N) 深，最小面积）
│   ├── tree：折半并行前缀网络（O(log N) 深）
│   └── grouped：组内链(GS=4) + 组间前缀链（O(GS+G) 深，折中）
├── 输出级：FAST_GRANT=0 组合授权 / =1 寄存授权（异步复位清零）
└── 就近 SVA：@(posedge clk) 并发断言（INV-001..005）
```

- RTL 布局：**默认单文件** `rtl/fixed_priority_arbiter.sv`（wrapper + 三实现同居，PC_IMPL 编译期分派）。
- 嵌套依赖：无（`implementations[].dependencies[]` 为空）。

## 2. 多实现与 Profile

**共享同一可观察契约**（授权互斥 + 优先级语义一致），差异仅在微架构结构（domain-rules §4）。

| Profile | implementation | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|
| `linear_small_n` | impl_linear | area | N≤8 面积优先 | supported |
| `linear_small_n_reg` | impl_linear (FAST_GRANT=1) | timing | 小 N + 寄存授权 | experimental |
| `tree_timing` | impl_tree | timing | N≥16 fmax 优先 | supported |
| `grouped_balanced` | impl_grouped | balanced | N=8~32 折中 | experimental |
| `latched_stable` | impl_linear (REQ_TYPE=1) | stable_grant | 慢速授权保持 | experimental |

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 单 `clk`（FAST_GRANT=1 或 REQ_TYPE=1 时使用；纯组合配置可悬空） |
| 复位 | 异步 `rst_n`（低有效）；释放后寄存输出（req_hold/grant_o）清零 |
| X 语义 | 输入 X/Z 不承诺（ASM-001）；2-state 仿真语义 |
| 异常行为 | 无请求→grant=0；latched 无 ack 应答时授权保持（防活锁由消费方保证 ASM-002） |

## 4. 关键数据路径（契约细化）

### 4.1 优先级选择（核心，LSB 优先归一化）

- `grant_core[i] = req_core[i] & ~|req_core[i-1:0]`（i>0）；`grant_core[0] = req_core[0]`
- PRIORITY=1 时对输入/输出做 bit-reverse 后套用同一公式（归一化，三实现共享）
- 三实现（linear/tree/grouped）仅改变 `~|req_core[i-1:0]`（前序 OR 归约）的计算方式：
  线性链逐级、树折半前缀、分组组内链+组间前缀

### 4.2 锁存（REQ_TYPE=1）

- `req_hold <= (req_hold | req_i) & ~(grant_ack_i ? grant_mid : 0)`
- 捕获新请求；ack 应答后清除被授权请求；未应答时授权保持（INV-004）

### 4.3 寄存授权（FAST_GRANT=1）

- `grant_o <= grant_mid`（输出寄存，1 拍延迟；异步复位清零）
- 与组合参考一致（INV-005，G4 tc_registered 已验）

## 5. 可验证性论证

- 每个 Profile 有验证路径：SVA（模块内 @(posedge clk) 并发断言）+ Simulation（穷举/随机/等价）
  + 负向 elab（非法参数）；跨实现等价（tc_equiv）覆盖多实现一致。
- 关键不变量映射 PROP：`PROP-FPA_MUTEX-001`/`PROP-FPA_PRIO-002`/`PROP-FPA_NONE-003`/
  `PROP-FPA_LATCH-004`/`PROP-FPA_REG-005`/`PROP-FPA_EQV-006`（见 [`trace/rtm.yaml`](../trace/rtm.yaml)）。
- Profile 差异验证重点：三实现跨实现一致（tc_equiv）+ PPA 收敛实证（G6）。

## 6. PPA 预筛（E0/E1 → G6 实证）

- 定性：优先级编码器（lowest-set-bit one-hot）面积 O(N)、时序 O(log N)（综合最优）；
  三实现 RTL 表述综合后收敛（G6 实证差异 <3%）。
- 证据等级：E2（DC 综合 sweep 15 点，单 corner tt_1p00v_25c）——见 [`reports/ppa-report.md`](../reports/ppa-report.md)。

## 7. 子依赖（若有）

无运行时子依赖。非目标：RR/WRR/多授权/层次仲裁（ARB-002/003/007/008）。
