# incrementer_decrementer 规格（G1，可读规格）

## 1. 功能语义

`incrementer_decrementer` 是 Counter 专用 ±1 运算器（纯组合、无时钟）。输入数据 `din[DATA_W-1:0]`
与递增/递减使能，输出模 `2^DATA_W` 回绕的结果：

```
dout = din + 1   (inc_en=1, dec_en=0)   # 递增
dout = din - 1   (inc_en=0, dec_en=1)   # 递减
dout = din       (inc_en=0, dec_en=0)   # 保持
inc_en=1, dec_en=1 → 行为未定义（ASM-002，调用方保证互斥）
```

`carry_out` 为溢出/借位标志：

```
carry_out = (inc_en & &din) | (dec_en & ~|din)   # 递增到全 1 溢出，或递减到 0 借位
```

## 2. 接口

| 端口 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `din` | in | `[DATA_W-1:0]` | 输入数据 |
| `inc_en` | in | 1 | 递增使能（与 dec_en 互斥） |
| `dec_en` | in | 1 | 递减使能（与 inc_en 互斥） |
| `dout` | out | `[DATA_W-1:0]` | ±1 结果（模 2^W 回绕） |
| `carry_out` | out | 1 | 溢出（递增到全 1）/ 借位（递减到 0）标志 |

无时钟/复位端口（纯组合）。

## 3. 参数

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DATA_W` | 32 | [2,1024] | 数据位宽（PC-001/002） |
| `ID_IMPL` | 0 | {0,1} | 微架构（PC-003）：0=ripple, 1=segmented |
| `SEG_W` | 4 | [2,16] | segmented 段位宽（PC-004，仅 ID_IMPL=1 生效） |

## 4. 微架构

### 0 = ripple（半加器进位链，基线）
逐位传播进位：`c[0]=inc_en|dec_en; dout[i]=din[i]^c[i]; c[i+1]=inc_en ? (din[i]&c[i]) : (~din[i]&c[i])`。
关键路径 O(DATA_W)，面积最小（每级 1 AND + 1 XOR + 1 MUX），作为 PPA 基线。

### 1 = segmented（分段进位）
将 `DATA_W` 分为 `CEIL(DATA_W/SEG_W)` 段，段内用半加器链，段间用 carry-skip 预计算：
段传播条件 `P[k]=inc_en ? (&seg[k]) : (~|seg[k])`，段间进位 `c[k+1]=c[k]&P[k]`。
关键路径 O(SEG_W + N_SEG) ≈ O(SEG_W + DATA_W/SEG_W)，宽位宽时序更优。

## 5. 行为不变量

| 不变量 | 说明 |
|---|---|
| INV-001 | 正确性：inc/dec/hold 结果与参考模型一致；两实现等价 |
| INV-002 | 回绕：全 1+1→0、0−1→全 1，无饱和截断 |
| INV-003 | 溢出/借位标志：carry_out 语义正确 |

## 6. 假设与约束

- ASM-001：输入 X/Z 不承诺。
- ASM-002：inc_en 与 dec_en 不同时断言（互斥）。
- ASM-003：参数编译期固定，不运行时切换。
- ASM-004：纯组合，调用方负责输入稳定/采样时序。

## 7. 非法参数拦截

elaboration 期 `$error`（PC-001..004），见
[`verification/formal/negative_elab_tb.sv`](../verification/formal/negative_elab_tb.sv)（G3 阶段创建）。
