# parity_gen_check — impl_reduction 详细设计说明书

## 1. 实现标识

| 项 | 值 |
|---|---|
| implementation id | `impl_reduction`（cbb.yaml implementations[].id） |
| module / 文件 | `parity_impl_reduction` @ `rtl/parity_gen_check.sv`（手写直写） |
| PC 选择值 | `PC_IMPL=1` |
| Profile 挂接 | `reduction_alt`（experimental） |
| 生成方式 | SV 手写（一行；Python 与 SV 均可时倾向 SV——design-cbb SKILL §2） |

## 2. 微架构说明

一行 reduction XOR：
```systemverilog
assign parity_i = ^data_i;
```
- 综合工具（DC/Genus）对 `^data_i` **自动生成最优平衡 XOR 树**（`ceil(log₂W)` 级关键路径、
  `W-1` 个 XOR）；
- **逻辑深度**：`O(log W)`（综合器决定，RTL 一行无显式结构）；
- 面积要素：`W-1` 个 2 输入 XOR（信息论下界）。

## 3. 权值/功能守恒论证

- `^data_i = b_0⊕b_1⊕…⊕b_{W-1}` 奇偶归约数学恒等；与显式树/链函数等价；
- 边界：全0→0（even）/1（odd）；全1→W%2；单bit=1→1（even）/0（odd）；
- 反模式自查：无运行时 `%//`、无软件式扫描（reduction 运算符为综合器原生归约）。

## 4. 参数化行为

| 参数 | 合法域 | 本实现敏感度 |
|---|---|---|
| DATA_WIDTH | [4..512] | 综合器按宽度生成最优树（深度 log₂W） |
| PARITY_TYPE | {0,1} | 仅 wrapper FLIP，本实现无感 |

## 5. 验证映射

| 需求/不变量 | 本实现的验证手段 | 证据 |
|---|---|---|
| REQ-001 / INV-001 | tc_exhaust_w8 + tc_random（黄金 XOR 归约） | build/eda/evidence/g4_functional/ |
| REQ-002 / INV-002 | tc_edge（全0/全1/one-hot） | 同上 |
| REQ-003 | tc_equiv（tree≡reduction≡linear 跨实现一致） | 同上 |

## 6. PPA 表征摘录（run-20260828-06，SC9 HVT tt / 2.5ns）

| W | area | data arrival time | 对比 |
|---|---|---|---|
| 8   | 6.55 | 1.15 ns | tree 1.13（微差 0.02） |
| 16  | 14.04 | 1.40 ns | 三实现同 |
| 32  | 29.02 | 1.52 ns | 三实现同 |
| 64  | 58.97 | 1.80 ns | 三实现同 |
| 128 | 119.92 | 2.00 ns | 三实现同 |
| 256 | 240.08 | 2.00 ns | 三实现同 |

结论：reduction 与显式树/线性**面积全同**（综合器统一生成最优平衡树），仅 W8 arrival
1.15 微逊于显式树 1.13（0.02ns 可忽略）——**SV 优先决策实证**：一行 RTL 获得等价 PPA。

## 7. 已知限制与非目标

与 tree/linear 无独立 PPA 差异（综合收敛）；X/Z 不承诺；无时钟端口（ASM-002）。

## 8. 变更记录

| Change | 日期 | 摘要 | 触发 Gate |
|---|---|---|---|
| C0 | 2026-08-28 | 初版（一行 reduction XOR，三形态对比引入） | G3 |
