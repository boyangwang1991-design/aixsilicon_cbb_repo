# 详设：impl_linear（PC_IMPL=0）— 显式线性优先级链

## 微架构
- 逐位"更高优先级段是否已请求"信号链式传播。
- PRIORITY=0（LSB 优先，最低索引最高优先级）：
  ```
  grant[0] = req[0]
  grant[i] = req[i] & ~|req[i-1:0]    (i = 1..N-1)
  ```
- PRIORITY=1（MSB 优先）：对输入做 bit-reverse 后套用同一公式，再反转输出。
- REQ_TYPE=1（latched）：`req_hold` 寄存器 `<= (req_i | req_hold) & ~(grant_ack_i & grant)`，
  （ack 应答且授权时清除被授权请求）；仲裁输入用 `req_hold`。
- FAST_GRANT=1：`grant_o <= grant_combo`（输出寄存，1 拍延迟；异步复位清零）。

## 逻辑深度推导
- 组合关键路径：链式 `~|`（OR 归约）从 bit0 传播到 bitN-1 → **O(N)**。
- 每条 grant 位 = 1 个 AND + 前段 OR 归约（扇入递增）。

## 面积/时序驱动要素与理论下界
- **面积**：N 个 AND + N 个逐级 OR（约 N·2 门）→ **最小面积实现**；无冗余并行结构。
- **时序**：O(N) 逻辑深度，N 大时（≥16）为关键路径瓶颈。
- **理论下界**：线性链必然 O(N) 深度；面积下界 O(N) 门（每路需判断前序有无请求）。

## PPA 优化点
- 大扇入 OR 归约可借综合器自动平衡（`~|` 给综合器自由空间），但仍受链式依赖约束。
- FAST_GRANT=1 将 req→grant 组合关键路径改为 reg→grant（寄存授权拍），
  适合小 N + 时序敏感场景（profile `linear_small_n_reg`）。
- 小 N（≤8）时综合器常把整条链优化为最小面积结构，与 tree 差异小；N≥16 时差异显现。

## 生成方式决策
- **SV 手写**（generate 参数化，无数学枚举需求）：公式 `grant[i] = req[i] & ~|req[i-1:0]`
  用循环 generate 简洁表达；PRIORITY 反转用 bit-reverse generate。符合"SV 优先"决策准则。
