# 详设：impl_quota_counter（PC_IMPL=0，WMODE=0）— 每路独立配额计数器 + RR 选择

## 微架构
- 维护每路独立配额计数器 `quota_cnt[N-1:0]`（每路位宽 `WW = WEIGHT_WIDTH`，复位=权重 `w[i]`）。
- 资格/请求过滤（INV-003）：
  ```
  qual[i] = req_i[i] & (w[i] != 0)            // 权重 0 无资格
  eligible[i] = qual[i] & (quota_cnt[i] > 0)  // 仍有配额
  ```
- 选择（从 RR 指针起回绕扫描 eligible 首个置位；统一轮转语义，INV-002/ASM-005）：
  - 复用 RR 旋转选择结构：`rotated = (eligible >> rr_ptr) | (eligible << (N - rr_ptr))`，
    `grant_rot = first_set(rotated)`（LSB 优先），逆旋转回原始索引空间（`always_comb` 内循环赋值）。
- 授权后更新：`quota_cnt[grant_idx] <= quota_cnt[grant_idx] - 1`（该路配额减 1）。
- 窗口重置（INV-006/ASM-006）：当 `|eligible == 0`（所有资格路配额耗尽）且 `|qual == 1`（仍有资格但无配额）
  → 全部 `quota_cnt <= w`（开始下一轮）。
- RR 指针更新：`rr_ptr <= (grant_idx + 1) % N`（GRANT_ACK_EN=0 每拍；=1 仅 ack 应答后）。
- FAST_GRANT=1：`grant_o <= grant_mid`（输出寄存，1 拍延迟；异步复位清零）。

## 逻辑深度推导
- RR 扫描（旋转 + LSB 优先编码）O(log N)；资格过滤 N 位 AND/比较 O(1)。
- 窗口重置判定：`|eligible == 0`（N 位 OR）+ `|qual`（N 位 OR）→ O(log N) 树。
- 配额减 1 / 复位：每路 N 位减法器 + MUX → O(log W)。
- **总深度 ≈ O(log N + log W)**（旋转+编码主导）。

## 面积/时序驱动要素与理论下界
- **面积**：N×W 位配额寄存器 + N 路减法/MUX + RR 扫描（旋转+编码）→ O(N·W + N)。
- **时序**：RR 扫描 O(log N)；N 大时旋转/编码为关键路径。
- **理论下界**：加权选择必然含"资格过滤 + 从指针起回绕扫描"，quota 状态必然 N×W 位（每路独立配额）；
  面积下界 O(N·W)。

## PPA 优化点
- RR 扫描用旋转 + LSB 优先编码（O(log N)，综合器优化为并行前缀），避免 O(N) 链。
- 配额计数器复用减法器：`quota_cnt[grant_idx]-1` 用 one-hot 使能 MUX 网络（综合器映射为编码器）。
- FAST_GRANT=1 将 req→grant 组合关键路径改为 reg→grant（profile `quota_reg`）。
- 窗口重置用组合 `|eligible`/`|qual` 全局判定（单级 OR 树）。

## 生成方式决策
- **SV 手写**（generate 参数化，无数学枚举需求）：配额计数器数组 + RR 旋转选择用 generate/循环简洁表达；
  符合"SV 优先"决策准则（reduction `|`、`$clog2` 等给综合器自由空间）。
