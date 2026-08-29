# 详设：impl_deficit_rotate（PC_IMPL=1，WMODE=1 smooth / =0 等价退化）— 统一 credit 减法 + 旋转选择

## 微架构
- 维护统一 credit 状态 `credit[N-1:0]`（每路位宽 `CW = WEIGHT_WIDTH + $clog2(N+1)`，复位=权重 `w[i]`）。
- 资格/请求过滤（INV-003/INV-004）：
  ```
  qual[i] = req_i[i] & (w[i] != 0)            // 权重 0 无资格
  ```
- 选择（smooth WRR，credit 最大且有资格；INV-004）：
  ```
  grant = argmax(credit, over qual)            // 平局取 RR 序最先（从 rr_ptr 起）
  ```
  - argmax 实现：先计算 `max_credit = max(credit[qual])`，再在 `qual & (credit == max_credit)` 中
    从 rr_ptr 起 RR 扫描首个置位。
- 授权后更新：`credit[grant_idx] <= credit[grant_idx] - N`（被选路扣总额，等效"每路每轮 +w、被选路 -N"）。
- 回补（跨轮累计，无负 credit；INV-004）：当所有资格路的 credit 均 < N（无法再扣）且 `|qual` → 全部 `credit <= credit + w`。
- RR 指针更新：`rr_ptr <= (grant_idx + 1) % N`（GRANT_ACK_EN=0 每拍；=1 仅 ack 应答后）。
- **WMODE=0 等价退化（REQ-006）**：当配置 WMODE=0 时，本实现以同一外部契约运行——
  若需与 quota_counter 完全等价，选择语义退化为"从 rr_ptr 起 RR 扫描有配额/资格的 eligible 首个置位"
  （credit 退化为配额计数的编码形式）。实现上通过 WMODE 编译期分支选择选择函数，保证共享可观察契约。

## 逻辑深度推导
- argmax：N 路 N 位比较树（O(log N) 深度）× W 位 → O(log N + log W)。
- RR 扫描（平局选择）：旋转 + LSB 优先编码 O(log N)。
- credit 减法/回补：N 路减法器 + 加法器 + MUX → O(log W)。
- 回补判定：所有资格路 credit < N（N 路比较 + AND 树）→ O(log N)。
- **总深度 ≈ O(log N + log W)**（argmax 比较树主导，与 quota 同量级；逻辑稍重）。

## 面积/时序驱动要素与理论下界
- **面积**：N×CW 位 credit 寄存器（CW = W + log N > W）+ N 路减法/加法/比较 + argmax 比较树 +
  RR 扫描 → O(N·CW + N·W)。
- **时序**：argmax 比较树 O(log N)；平滑语义的跨轮累计是状态而非关键路径。
- **理论下界**：smooth WRR 必然维护每路 credit（N×CW 位）与 argmax 选择（O(log N) 树）；
  面积下界略高于 quota（credit 位宽含 log N 余量），时序同级。

## PPA 优化点
- argmax 用并行前缀最大树（综合器优化），再与 RR 扫描共享旋转结构。
- credit 扣减用 one-hot 使能 MUX 网络；回补加法复用。
- FAST_GRANT=1 将 req→grant 关键路径改为 reg→grant（可与 smooth_credit Profile 组合）。
- CW 取 `WEIGHT_WIDTH + $clog2(N+1)` 防溢出（credit 上界≈w + N，扣 N 后仍 ≥0）。

## 生成方式决策
- **SV 手写**（generate 参数化）：argmax 比较树 + RR 旋转选择 + credit 状态用 generate/循环简洁表达；
  无数学枚举/查找表物化需求，符合"SV 优先"决策准则。
