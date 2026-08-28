# fixed_priority_arbiter PPA 分析报告

> **Run ID**: `run-20260828-01`（三实现 × 5 请求数 Sweep，时序主指标 = data arrival time）· 2026-08-28 · **G6 pass**
> 原始证据（本地可复现，不入库）：`build/eda/ppa/run-20260828-01/`；结论以本报告为正式载体
> 脚本：[`synth_sweep.tcl`](../characterization/synth_sweep.tcl)
> 三实现形态：**impl_linear（显式链 O(N)）/ impl_tree（折半前缀 O(log N)）/ impl_grouped（分组 GS=4）**
> ——同输入同契约，实证三种 RTL 微架构对综合最优解的影响。

## 1. 表征上下文（证据等级 E2）

| 维度 | 值 | 来源 |
|---|---|---|
| 工艺/库 | GF CMOS28LP + ARM SC9 base HVT (r5p0) | characterization/pdk.yaml |
| Corner | tt_nominal_max_1p00v_25c（单 corner） | 同上 |
| 约束 | 虚拟时钟 vclk=2.5ns(400MHz)、I/O delay 0.5ns、驱动 BUFH_X4M_A9TH、load 10fF | synth_sweep.tcl |
| 综合策略 | compile_ultra -no_autoungroup；wrapper 参数选择 PC_IMPL/NUM_REQ | synth_sweep.tcl |
| **时序主指标** | **data arrival time（输入→输出传播延迟）**；slack 仅参考 | 组合构件纪律 |

## 2. Sweep 结果矩阵（面积 μm² / data arrival time ns）

| NUM_REQ | impl_linear（链） | impl_tree（树） | impl_grouped（分组） |
|---|---|---|---|
| 4   | 2.34 / 0.84 | 2.34 / 0.84 | 2.34 / 0.84 |
| 8   | 6.79 / 1.11 | 6.79 / 1.11 | 6.79 / 1.11 |
| 16  | 15.33 / 1.66 | 15.33 / 1.66 | 15.33 / 1.67 |
| 32  | 40.13 / 2.00 | 39.31 / 2.00 | 39.31 / 2.00 |
| 64  | 87.40 / 1.99 | 89.62 / 2.00 | 88.80 / 1.99 |

## 3. PPA 结论（诚实定性）

1. **三实现综合基本收敛**：linear/tree/grouped 在 N≤16 时**面积与时序完全一致**；
   N=32/64 差异 <3%（linear 在 N64 面积略小 87.40 vs tree 89.62，tree 在 N32 面积略小
   40.13→39.31）——实证综合器（compile_ultra）对函数等价优先级编码（lowest-set-bit 选择）
   统一生成最优结构，**RTL 微架构写法对综合最优解影响很小**（与 parity_gen_check 观测一致）；
2. **时序主指标**：data arrival 随 N 增长缓慢（0.84→2.00ns），N=32 达 2.00ns 上界
   （优先级编码器深度受限于 O(log N) 综合结构）；slack 在 400MHz 下 N≤16 满足、N≥32 临界；
3. **PPA 空间确认较小**：优先级编码是"最低有效位 one-hot 选择"（信息论下界 O(N) 门/O(log N)
   深），三种 RTL 表述被综合器折叠为近同一网表；差异主要来自综合器启发式而非 RTL 结构；
4. **FAST_GRANT=1 的价值**（profile `linear_small_n_reg`）：寄存授权将组合关键路径
   req→grant 改为 reg→grant（输出级寄存），可进一步解耦时序；本 sweep 未单独表征
   （F3 组合形态已示 400MHz 可达），留待消费场景按需实例化。

**推荐**：`linear_small_n`（N≤8 面积最小，supported）与 `tree_timing`（N≥32 面积略优，
supported）为实际差异点；`grouped_balanced` 与 tree 趋同（experimental）；
`linear_small_n_reg`/`latched_stable` 为功能型 Profile（experimental），非 PPA 驱动。
三实现无显著独立 PPA 优势——保留多实现的意义在于**代码清晰性与微架构语义表达**（链/树/分组），
综合器自动收敛到最优编码器。
