# ripple 详设（ID_IMPL=0，半加器进位链）

> CG（Carry/Data Gating，2026-08-29 PPA 优化）：
> 实现引入显式 `active=inc_en|dec_en` 门控——hold 模式（active=0）下进位链强制 0
> （carry gating，零翻转）、XOR 退化为直通（operand isolation，data gating），
> 动态功耗显著降低；语义与未门控版完全等价（G4 回归证明）。

## 微架构

```
c[0]   = inc_en | dec_en                      // 有操作 → 初始进位/借位 = 1
dout[i] = din[i] ^ c[i]                        // 每级 XOR 得结果位
c[i+1] = inc_en ? (din[i] & c[i])             // 递增：进位传播条件 din[i]=1
               : (~din[i] & c[i])             // 递减：借位传播条件 din[i]=0
carry_out = c[DATA_W]                          // 链末进位/借位 = 溢出/借位标志
```

- 以 `for genvar i=0..DATA_W-1` generate 展开，进位链逐级传播。
- 递增/递减统一为同一链：传播条件用 `inc_en` 选 `din[i]` 或 `~din[i]`。

## 守恒论证

- 递增（inc_en=1）：`dout[i]=din[i]^c[i]`、`c[i+1]=din[i]&c[i]`，即半加器
  `dout = din + 1`（模 2^W）的标准行波进位链；全 1 输入时进位贯通至 carry_out=1。
- 递减（dec_en=1）：借位链 `dout[i]=din[i]^b[i]`、`b[i+1]=~din[i]&b[i]`，
  即 `dout = din - 1`（模 2^W）；全 0 输入时借位贯通至 carry_out=1。
- inc_en=dec_en=0：c[0]=0，dout=din（保持），carry_out=0。
- 两者互斥（ASM-002），不使能时无算术动作。

## 逻辑深度与 PPA

- **逻辑深度**：O(DATA_W)（串行进位链）。
- **面积**：DATA_W × (1 AND + 1 XOR + 1 MUX)，最小实现。
- **时序驱动**：进位链末级延迟；宽位宽（>128）时序差。
- **理论下界**：+1 增量器最低逻辑深度可 O(log W)（进位前缀），本实现用简单链换面积。
- **综合收敛风险**：DC compile_ultra 可能把等价进位链优化/重排（观察与 popcount 同）；
  若需保留原始结构须关算术优化。本构件行为与综合无关，正确性由 G4 保证。

## PPA 优化点

- 面积最小（半加器 vs 全加器），是 Counter 专用优化的核心收益。
- 无需完整加法器（仅 ±1），省去通用加法器的进位产生逻辑。
