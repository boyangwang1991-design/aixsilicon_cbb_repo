# parity_gen_check — impl_tree 详细设计说明书

## 1. 实现标识

| 项 | 值 |
|---|---|
| implementation id | `impl_tree`（cbb.yaml implementations[].id） |
| module / 文件 | `parity_impl_tree` @ `rtl/parity_gen_check.sv`（手写直写） |
| PC 选择值 | `PC_IMPL=0` |
| Profile 挂接 | `tree_default`（supported） |
| 生成方式 | 手写（极简单文件，无生成器） |

## 2. 微架构说明

平衡 XOR 归约树——**SV 一行 `assign parity_i = ^data_i;`**（reduction 一元运算符），
由综合工具（DC/Genus）自动生成最优平衡 XOR 树：

- 综合器对 `^data_i` 构造折半归约：关键路径 `ceil(log₂W)` 个 XOR 级（O(log W) 深度）、
  `W-1` 个 XOR——理论最优（生成方式决策：Python 与 SV 均可时倾向 SV，parity 复盘）；
- 面积要素：`W-1` 个 2 输入 XOR（SC9 单 XOR 面积远小于加法器，整体紧凑）；
- 注：G6 实测 tree 与 linear 综合完全收敛，正源于 DC 对函数等价的归约统一生成
  最优平衡树（RTL 写法不影响综合最优解）。

## 3. 权值/功能守恒论证

- XOR 归约数学：`^data_i = b_0⊕b_1⊕…⊕b_{W-1}`；偶校验 `parity_o=^data_i`，
  奇校验 `parity_o=~^data_i`（wrapper 内 FLIP）；
- 边界：全 0 → `^=0`（even=0/odd=1）；全 1 → W 个 1 异或 = `W%2`（even=W%2, odd=~W%2）；
  单 bit=1 → `^=1`（even=1/odd=0）；
- 反模式自查：零运行时 `%//`、零软件式扫描（仅 generate 结构展开）。

## 4. PPA 优化点（本实现可优化维度）

- **深度最优**：折半 XOR 树关键路径 = `ceil(log₂W)` 级 XOR，为理论下限（任何归约
  至少 log₂W 级）——时序方向已到 Pareto 前端，无进一步降深空间；
- **面积下界**：XOR 归约需 `W-1` 个 2 输入 XOR（信息论下界），本实现已达；
- **单元/综合优化**：SC9 库 XOR2/AOI 组合由 DC `compile_ultra` 自动选择；`-no_autoungroup`
  会阻止跨层级重组，默认 autoungroup 可让 DC 折叠共享 XOR（面积 −0~5% 观察点）；
- **大宽度杠杆**：W=512 时树深仅 9 级（vs 线性链 512 级）——时序优势在宽位最显著，
  是 PPA 对比的主维度；
- **PARITY_TYPE**：仅 1 位 FLIP（wrapper），零面积代价。

## 5. 参数化行为

| 参数 | 合法域 | 本实现敏感度 |
|---|---|---|
| DATA_WIDTH | [4..512] | XOR 树层级随 `log₂W` 增长；面积随 `W` 线性 |
| PARITY_TYPE | {even,odd} | 仅 wrapper FLIP 一位取反，本实现无感 |

零宽防护：PC-001（W≥4）经 wrapper `$error` 拦截（本模块无独立卫兵）。

## 5. 验证映射

| 需求/不变量 | 本实现的验证手段 | 证据 |
|---|---|---|
| REQ-001 / INV-001 | tc_exhaust_w8 + tc_random（黄金 XOR 归约） | build/eda/evidence/g4_functional/ |
| REQ-002 / INV-002 | tc_edge（全0/全1/one-hot，even/odd） | 同上 |
| REQ-003 | tc_equiv（tree≡linear 跨实现一致） | 同上 |

## 6. PPA 表征摘录

| W | area | data arrival time | 备注 |
|---|---|---|---|
| 8   | 6.55 | 1.13 ns | 与 linear 同 |
| 16  | 14.04 | 1.40 ns | 与 linear 同 |
| 32  | 29.02 | 1.52 ns | 与 linear 同 |
| 64  | 58.97 | 1.80 ns | 功耗 22.65 μW |
| 128 | 119.92 | 2.00 ns | 组合深度上限 |
| 256 | 240.08 | 2.00 ns | 组合深度上限 |

结论：W=8~256 与 linear **面积/时序完全收敛**（DC 将等价 XOR 归约统一综合），
PPA 空间确认为小（单输出 XOR 归约无组合形态差异）；tree_default 为推荐（同面积，
逻辑结构清晰）。时序主指标 = **data arrival time**（组合逻辑独立于虚拟时钟）。
Pareto/图见 [`reports/ppa-report.md`](../../reports/ppa-report.md)。

## 7. 已知限制与非目标

X/Z 输入不承诺（ASM-001）；无时钟端口（流水化属消费侧，ASM-002）；非 CRC/多项式（COD-002）。

## 8. 变更记录

| Change | 日期 | 摘要 | 触发 Gate |
|---|---|---|---|
| C0 | 2026-08-28 | 初版（平衡 XOR 树实现 + 详设） | G3 |
