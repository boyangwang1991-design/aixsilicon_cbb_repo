# popcount 规格（G1，可读规格）

## 1. 功能语义

`popcount` 对输入位向量 `din[DATA_W-1:0]` 返回其中 1 的个数：

```
popcnt = Σ din[i] = # { i : din[i] = 1 },  0 ≤ popcnt ≤ DATA_W
```

输出位宽 `NBITS = $clog2(DATA_W + 1)`（精确覆盖 0..DATA_W，不溢出）。

## 2. 接口

| 端口 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `din` | in | `[DATA_W-1:0]` | 输入数据（位向量） |
| `popcnt` | out | `[$clog2(DATA_W+1)-1:0]` | 1 的个数 |

无时钟/复位端口（纯组合）。

## 3. 参数

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DATA_W` | 32 | [2,1024] | 输入位宽（PC-001/002） |
| `PC_IMPL` | 1 | {0,1,2,3,4} | 微架构（PC-003）：0=direct,1=tree,2=wallace,3=comp4_2,4=lut |

Wallace/compressor 仅支持 `DATA_W∈{8,16,32,64}`（PC-004，生成器位宽集）。

## 4. 微架构

### 0 = direct（直接加法基线）
把 `DATA_W` 个输入位当作 1-bit 计数，串行两两相加（`acc[i+1]=acc[i]+din[i]`），
形成 O(W) 级加法器链。最直观，作为 PPA 参照基线。

### 1 = tree（平衡归约树）
每级把相邻两节点的 2 输入计数相加（`lv[s][j]=lv[s-1][2j]+lv[s-1][2j+1]`），
O(log W) 级、全并行；末级单节点即结果。深度最小、时序优。

### 2 = wallace（Wallace tree，生成器展开）
权重 0 列含全部输入位；每级把每列 3 个同权重 bit 压缩为 FA{sum 同列, carry 高列}、
2 个压缩为 HA{sum, carry}，直到每列 ≤2，再以 NBITS 位 ripple-carry 收尾。
见 [`tools/gen_popcount.py`](../tools/gen_popcount.py) 与 [`rtl/gen/`](../rtl/gen/)。

### 3 = comp4_2（4:2 compressor，生成器展开）
同权重列每 4 个 bit 用一个 4:2 compressor（cin 来自低列 cout 的列间链、sum 同列、
carry 高列），链末 cout 作为普通进位进高列；不足 4 的列用 FA/HA/pass。
每级归约 4→2，级数 ~log₄W，最少。

### 4 = lut（LUT 查表）
每 4 输入位一个 3-bit 计数真值表（case，综合映射为查找表/复用逻辑），再以折半
加法树合并各子块计数。结构规整、面积可控。

## 5. 行为不变量

| 不变量 | 说明 |
|---|---|
| INV-001 | 正确性：`popcnt` == 1 的个数（黄金模型一致；五实现等价） |
| INV-002 | 上界：`popcnt ≤ DATA_W`，输出位宽不溢出 |
| INV-003 | 边界：全 0→0、全 1→DATA_W、单热→1、0101 交错→DATA_W/2 |

## 6. 假设与约束

- ASM-001：输入 X/Z 不承诺。
- ASM-002：参数编译期固定，不运行时切换。
- ASM-003：Wallace/compressor 位宽集 {8,16,32,64}（PC-004）。
- ASM-004：纯组合，调用方负责输入稳定/采样时序。

## 7. 非法参数拦截

elaboration 期 `$error`（PC-001..004），见
[`verification/formal/negative_elab_tb.sv`](../verification/formal/negative_elab_tb.sv)。
