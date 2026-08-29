# incrementer_decrementer 设计（G2）

## 1. 模块划分

```
incrementer_decrementer.sv（wrapper，极简单文件）
├── 参数检查 generate（PC-001..004 $error）
├── 实现分派 generate（ID_IMPL 0/1）
│   ├── incrementer_decrementer_impl_ripple   （0 ripple 半加器进位链）
│   └── incrementer_decrementer_impl_segmented（1 segmented 分段进位）
└── 就近 SVA（INV-001/002/003，验证期生效）
```

- 单文件 `rtl/incrementer_decrementer.sv`：wrapper + 两实现同居（对齐 popcount 极简单
  文件风格），无 package/interface 层级。
- 无嵌套子 CBB 依赖（纯组合单算子），`implementations[].dependencies[]` 为空。

## 2. 多实现设计要点

### ripple（ID_IMPL=0，半加器进位链）
```
c[0] = inc_en | dec_en                     // 有操作则初始进位 1
dout[i] = din[i] ^ c[i]
c[i+1] = inc_en ? (din[i] & c[i])          // 递增：进位传播条件 din[i]=1
               : (~din[i] & c[i])          // 递减：借位传播条件 din[i]=0
```
- 每级 1 AND + 1 XOR + 1 MUX，面积最小；关键路径 O(DATA_W)。
- 递减用借位链（~din 作传播条件），与递增共享同一进位链结构。

### segmented（ID_IMPL=1，分段进位 carry-skip）
```
N_SEG = ceil(DATA_W/SEG_W)
段 k 内：ripple 半加器链（同上）
段间进位：c[k+1] = c[k] & P[k]
  P[k] = inc_en ? (&seg[k]) : (~|seg[k])    // 段传播条件：段内全1(inc)/全0(dec)
```
- 段内 ripple 输出 + 段间 carry-skip 预计算，关键路径 O(SEG_W + N_SEG)。
- 用 generate 参数化（`for genvar`），段宽 SEG_W 可调；SEG_W=2 时近似 ripple，
  SEG_W 增大退化 ripple；SEG_W 过小段间逻辑增加。

## 3. 时钟/复位

无（纯组合）。无时序状态，调用方负责输入稳定与采样。

## 4. 生成方式决策

- 两实现均 **SV 手写**（generate 参数化）：结构规整、可参数化表达，无需 Python 生成
  （对齐 design-cbb step 3：SV 能简洁参数化表达 → SV）。
- 无派生 RTL 生成器；`rtl/gen/` 不产生。

## 5. Profile（见 profiles.yaml）

| Profile | ID_IMPL | 场景 |
|---|---|---|
| prof_area_opt | ripple | 面积优先（窄位宽步进计数） |
| prof_timing_opt | segmented | 时序优先（宽位宽高频 Counter） |
| prof_balanced | ripple | 默认通用（窄位宽面积/时序均衡） |
| prof_reference | ripple | 基线参照 |

## 6. 验证策略

- G3 静态：compile/elab 矩阵（两实现 × {8,16,32,64} × SEG_W{4,8}）+ 负向参数拦截
  （DATA_W/ID_IMPL/SEG_W 越界）+ SpyGlass lint。
- G4 功能：穷举 W8 两实现 + 边界（全1/0/单bit）+ 随机（W{8,16,32} 两实现，黄金模型
  一致 + 等价对比）+ carry_out 校验。
- G6 PPA：两实现 × {8,16,32,64} 综合 sweep（PDK：GF CMOS28LP + ARM SC9）。

## 7. 可验证性论证

- 每实现共享同一可观察契约（inc/dec/hold 模回绕），等价仿真保证互换性。
- 关键不变量 INV-001/002/003 映射 PROP-INC_DEC_*-001..004；纯组合无时序状态，
  SVA 用 `always_comb` 立即断言 + `$isunknown` 防护（对齐 popcount 观察）。
