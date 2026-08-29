# 详设：impl_rotate_prio（PC_IMPL=1）— 旋转索引 + LSB 优先编码（O(log N)）

## 微架构
- 维护轮转指针 `rr_ptr`（复位为 0，二进制编码）。
- 将请求按 `rr_ptr` **旋转**，使 `req[rr_ptr]` 落到新向量 LSB，然后 LSB 优先编码（首个置位）：
  ```
  rotated[i]      = req_src[(rr_ptr + i) % N]          // 旋转：rr_ptr 位在新 LSB
  grant_rot       = first_set(rotated)                 // LSB 优先编码（O(log N)）
  grant[(rr_ptr + j) % N] = grant_rot[j]               // 逆旋转回原始索引空间
  ```
  等价于：从 rr_ptr 起回绕扫描首个置位（统一轮转语义，INV-002/ASM-005）。
- 旋转实现：每输出位 `rotated[i]` 为 N:1 MUX（sel = rr_ptr），桶形移位器结构 O(log N) MUX 深。
- 轮转更新：`rr_ptr <= (grant_index + 1) % N`（GRANT_ACK_EN=0 每拍；=1 仅 ack 应答后）。
  `grant_index` 由 priority encoder（rotated 的置位位序）给出。
- REQ_TYPE=1（latched）：`req_hold` 寄存器 `<= (req_i | req_hold) & ~(grant_ack_i & grant)`；
  仲裁输入用 `req_hold`。
- FAST_GRANT=1：`grant_o <= grant_combo`（输出寄存，1 拍延迟；异步复位清零）。

## 逻辑深度推导
- 旋转：桶形移位器每输出位 O(log N) MUX 深度。
- LSB 优先编码：并行前缀 O(log N) 深度（同 fixed_priority_arbiter tree 实现）。
- 总深度 **O(log N)**（+ 逆旋转 O(log N)）。

## 面积/时序驱动要素与理论下界
- **面积**：N×N 桶形移位 MUX（约 N²/2 个 2:1 等效）+ 编码器 → 面积大于 mask（N 大时明显）。
- **时序**：O(log N) 深度，N 大时（≥16）fmax 最优（相对 mask）。
- **理论下界**：旋转选择本质为"任意起点循环选择"，桶形移位为 O(N log N) MUX、O(log N) 深。

## PPA 优化点
- 逆旋转可省：直接用 `grant_rot` 索引旋转 `req` 的结论在原始空间表达（综合器可能重组）。
- 编码器复用 LSB 优先树（与 mask 的 first_set 共享，仅结构不同）。
- FAST_GRANT=1 配合时序优化（profile 可扩展）。

## 生成方式决策
- **SV 手写**（generate 参数化）：桶形旋转用 `for` generate + 条件移位，LSB 编码用并行前缀；
  符合"SV 优先"决策准则（无数学枚举）。
