# 详设：impl_mask（PC_IMPL=0）— 轮转掩码优先链（经典 RR mask 法）

## 微架构
- 维护轮转指针 `rr_ptr`（复位为 0，二进制编码，位宽 `$clog2(N)`）。
- 从 `rr_ptr` 起回绕扫描首个置位（统一轮转语义，INV-002/ASM-005）：
  ```
  lower  = req_src &  ((1 << rr_ptr) - 1)     // rr_ptr 以下位（低段）
  upper  = req_src & ~((1 << rr_ptr) - 1)     // rr_ptr 及以上位（高段）
  grant  = (|upper) ? first_set(upper)        // 高段有请求 → 高段首个置位
                   : first_set(lower)         // 否则回绕到低段首个置位
  ```
- `first_set()` 为 LSB 优先编码（同 fixed_priority_arbiter 优先级链）：
  `grant[i] = v[i] & ~|v[i-1:0]`；`grant[0] = v[0]`。
- 轮转更新：`rr_ptr <= (grant_index + 1) % N`（GRANT_ACK_EN=0 每拍；=1 仅 ack 应答后）。
- REQ_TYPE=1（latched）：`req_hold` 寄存器 `<= (req_i | req_hold) & ~(grant_ack_i & grant)`；
  仲裁输入用 `req_hold`。
- FAST_GRANT=1：`grant_o <= grant_combo`（输出寄存，1 拍延迟；异步复位清零）。

## 逻辑深度推导
- 两段 LSB 优先链各 O(N) 深度 + 一级选择 MUX（|upper 判空）→ **O(N)**。
- grant_index 编码（priority encoder 找置位索引）为 O(log N)，供 rr_ptr 更新。

## 面积/时序驱动要素与理论下界
- **面积**：两段链（约 2N 门）+ 掩码生成（N 位 AND）+ 1 个 N:1 MUX → 最小面积实现（相对 rotate）。
- **时序**：O(N) 逻辑深度（两段链串行 + MUX），N 大时（≥16）为关键路径瓶颈。
- **理论下界**：轮转选择必然含"从指针起回绕扫描"，mask 法为 O(N) 深；面积下界 O(N) 门。

## PPA 优化点
- 掩码 `(1<<rr_ptr)-1` 用左移生成（综合器映射为移位/译码），N 为 2 的幂时最简。
- FAST_GRANT=1 将 req→grant 组合关键路径改为 reg→grant（profile `mask_area_reg`）。
- 小 N（≤8）时综合器把两段链优化为最小面积，与 rotate/pointer 差异小；N≥16 时差异显现。

## 生成方式决策
- **SV 手写**（generate 参数化，无数学枚举需求）：两段链 + 掩码用循环 generate 简洁表达；
  符合"SV 优先"决策准则（reduction `|` 给综合器自由空间）。
