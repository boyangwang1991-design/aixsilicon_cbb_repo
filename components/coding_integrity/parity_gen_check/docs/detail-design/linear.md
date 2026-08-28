# parity_gen_check — impl_linear 详细设计说明书

## 1. 实现标识

| 项 | 值 |
|---|---|
| implementation id | `impl_linear`（cbb.yaml implementations[].id） |
| module / 文件 | `parity_impl_linear` @ `rtl/parity_gen_check.sv`（手写直写） |
| PC 选择值 | `PC_IMPL=1` |
| Profile 挂接 | `linear_alt`（experimental） |
| 生成方式 | 手写（极简单文件，无生成器） |

## 2. 微架构说明

线性 XOR 链（逐位累异或）：
- `always_comb` 内 `parity_i = data_i[0]; for b=1..W-1: parity_i ^= data_i[b]`；
- 综合语义为 `W-1` 个 2 输入 XOR 串行链。

- **逻辑深度**：`O(W)` 级 XOR 串链（关键路径随 W 线性增长）；
- 面积要素：`W-1` 个 XOR（与 tree 同数量，但结构为链，DC 可能重排为树）。

## 3. 权值/功能守恒论证

- 与 tree 同一 XOR 归约数学（`^data_i`），逐位累异或语义等价；
- 边界条件与 tree 完全一致（全0/全1/单bit，even/odd）；
- 反模式自查：`for` 循环为综合器可展开的**常量边界**归约，非运行时扫描（每迭代
  仅 1 个 XOR，无状态/无控制依赖）。

## 4. PPA 优化点（本实现可优化维度）

- **深度弱点**：链关键路径 `O(W)` 级 XOR（W=512 时 ~512 级）——大宽度时序必然违例，
  是相对 tree 的**退化维度**，仅在小宽度（W≤32）时序余量大时具探索意义；
- **综合收敛风险**：DC 对函数等价的 XOR 链会**自动重排为近似平衡树**——若综合后
  linear 与 tree 面积/时序趋同，说明结构差异被工具抹平（PPA 空间确认为小）；
- **面积下界**：与 tree 同为 `W-1` 个 XOR，理论面积无差；
- **用途**：作为"显式链 vs 树"的**结构教学视图**，验证 DC 重构行为（domain-rules
  §3.1.3 观测点），非量产推荐。

## 5. 参数化行为

| 参数 | 合法域 | 本实现敏感度 |
|---|---|---|
| DATA_WIDTH | [4..512] | 链深度随 `W` 线性增长（PPA 对比主维度） |
| PARITY_TYPE | {even,odd} | 仅 wrapper FLIP，本实现无感 |

零宽防护：PC-001（W≥4）经 wrapper `$error` 拦截。

## 5. 验证映射

| 需求/不变量 | 本实现的验证手段 | 证据 |
|---|---|---|
| REQ-001 / INV-001 | tc_exhaust_w8 + tc_random（黄金 XOR 归约） | build/eda/evidence/g4_functional/ |
| REQ-002 / INV-002 | tc_edge（全0/全1/one-hot） | 同上 |
| REQ-003 | tc_equiv（tree≡linear 跨实现一致，TB 内直接比对） | 同上 |

## 6. PPA 表征摘录

| W | area | data arrival time | 备注 |
|---|---|---|---|
| 8   | 6.55 | 1.15 ns | 与 tree 略差（链深） |
| 16  | 14.04 | 1.40 ns | 与 tree 同 |
| 32  | 29.02 | 1.52 ns | 与 tree 同 |
| 64  | 58.97 | 1.80 ns | 功耗 20.66 μW（略低 ~9%） |
| 128 | 119.92 | 2.00 ns | 与 tree 同 |
| 256 | 240.08 | 2.00 ns | 与 tree 同 |

结论：**综合收敛实证**——DC 将显式线性 XOR 链重排为平衡归约树，各宽度面积/arrival
与 tree 一致（W8 arrival 1.15 vs tree 1.13，链深略差；仅小宽度功耗略低 ~9%）；本实现
定位 experimental/结构教学视图，无独立 PPA 价值。Pareto/图见
[`reports/ppa-report.md`](../../reports/ppa-report.md)。

## 7. 已知限制与非目标

大宽度（W≥128）深度 O(W) 时序风险；X/Z 不承诺；无时钟端口（ASM-002）。

## 8. 变更记录

| Change | 日期 | 摘要 | 触发 Gate |
|---|---|---|---|
| C0 | 2026-08-28 | 初版（线性 XOR 链实现 + 详设） | G3 |
