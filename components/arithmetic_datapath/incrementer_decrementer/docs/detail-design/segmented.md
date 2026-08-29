# segmented 详设（ID_IMPL=1，分段进位 carry-skip）

## 微架构

```
N_SEG = (DATA_W + SEG_W - 1) / SEG_W        // 段数
段 k 输入 seg[k] = din[k*SEG_W +: SEG_W]     // 末段高位补 0（< SEG_W）

段内（ripple 半加器链，同 ripple 实现）：
  ck[0] = 段输入进位（来自段间预计算）
  segout[i] = seg[k][i] ^ ck[i]
  ck[i+1] = inc_en ? (seg[k][i] & ck[i]) : (~seg[k][i] & ck[i])

段间进位（carry-skip 预计算）：
  P[k] = inc_en ? (&seg[k]) : (~|seg[k])    // 段传播条件：段内全1(inc)/全0(dec)
  c_seg[k+1] = c_seg[k] & P[k]              // 进位贯通段
  c_seg[0] = inc_en | dec_en

dout = 各段 segout 拼接；carry_out = c_seg[N_SEG]
```

- 用嵌套 `generate`（外层段、内层段内位）参数化展开。
- 段内 ripple + 段间 AND 预计算（carry-skip），关键路径 = 段内链 + 段间 AND 链。

## 守恒论证

- 与 ripple 共享同一半加器/借位传播模型；段间仅预计算"段内全传播"条件，
  不改变每位的 dout/进位语义 → 与 ripple 逐位等价（模 2^W + carry_out）。
- P[k]=&seg[k]（inc）：段内全 1 时进位贯通；P[k]=~|seg[k]（dec）：段内全 0 时
  借位贯通。非全传播段在段内即吸收进位/借位，链末 carry_out 语义与 ripple 一致。

## 逻辑深度与 PPA

- **逻辑深度**：O(SEG_W + N_SEG) ≈ O(SEG_W + DATA_W/SEG_W)；最优在
  SEG_W ≈ sqrt(DATA_W) 附近（当 SEG_W 与 N_SEG 平衡）。
- **面积**：ripple 面积 + 段间 (N_SEG-1) 个 N_SEG 输入 AND/OR + 与门，略增。
- **时序驱动**：段间 AND 链比 ripple 长进位链更短；宽位宽收益明显。
- **SEG_W 折中**：SEG_W 过小 → 段间逻辑/寄存器密度增加；SEG_W 过大 → 退化为
  ripple（段内链主导）。典型取 4/8（PC-004 合法域 [2,16]）。

## PPA 优化点

- 宽位宽 Counter（32/64/128）关键路径显著短于 ripple。
- 段间用 `&`/`~|` reduction 预计算，综合后映射为规整门级结构。
