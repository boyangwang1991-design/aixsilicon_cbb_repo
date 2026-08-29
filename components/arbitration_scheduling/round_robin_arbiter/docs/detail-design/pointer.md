# 详设：impl_pointer（PC_IMPL=2）— 二进制指针 + 循环移位选择（折中）

## 微架构
- 维护轮转指针 `rr_ptr`（复位为 0，二进制编码）。
- 使用显式**循环移位器**将 `req` 按 `rr_ptr` 循环左移，使 `req[rr_ptr]` 落到 LSB：
  ```
  rotated[i] = req_src[(rr_ptr + i) % N]        // 循环移位（与 rotate_prio 相同旋转）
  grant_rot  = first_set(rotated)               // LSB 优先编码
  grant[(rr_ptr + j) % N] = grant_rot[j]        // 逆旋转
  ```
- 与 impl_rotate_prio 的差异：pointer 显式物化循环移位器 + 优先级编码两个阶段，
  逻辑组织更规整（shift→select），综合器可独立优化；N 大时 LUT/FF 映射更友好。
- 轮转更新：`rr_ptr <= (grant_index + 1) % N`（GRANT_ACK_EN=0 每拍；=1 仅 ack 应答后）。
- REQ_TYPE=1（latched）：`req_hold` 寄存器 `<= (req_i | req_hold) & ~(grant_ack_i & grant)`。
- FAST_GRANT=1：`grant_o <= grant_combo`（输出寄存，1 拍延迟；异步复位清零）。

## 逻辑深度推导
- 循环移位：桶形移位 O(log N) MUX 深（每输出位 N:1）。
- LSB 优先编码：O(log N) 并行前缀。
- 总深度 **O(log N)**（与 rotate_prio 同级）。

## 面积/时序驱动要素与理论下界
- **面积**：显式循环移位器（N×N MUX）+ 编码器；与 rotate_prio 结构同级，
  但分阶段表达可能让综合器映射为不同网表（G6 实证对比）。
- **时序**：O(log N) 深度，N 大时（≥16）fmax 优于 mask。
- **理论下界**：与 rotate_prio 相同（桶形移位 + 编码）。

## PPA 优化点
- 循环移位器用 `<<<`/`>>>` 或显式 generate（综合器自动生成桶形结构）。
- LSB 编码与 mask/rotate 共享同一 first_set 语义（结构复用，代码清晰）。
- N 为 2 的幂时 `% N` 退化为位选（`& (N-1)`），综合器自动优化。

## 生成方式决策
- **SV 手写**（generate 参数化）：循环移位 + 编码器均可用循环 generate 简洁表达；
  符合"SV 优先"决策准则（无数学枚举）。
