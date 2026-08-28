# popcount — impl_lut 详细设计说明书

## 1. 实现标识

| 项 | 值 |
|---|---|
| implementation id | `impl_lut` |
| module / 文件 | `popcount_impl_lut` @ `rtl/popcount.sv`（手写直写） |
| PC 选择值 | `PC_IMPL=2` |
| Profile 挂接 | `lut_compact`（supported） |
| 生成方式 | 手写 |

## 2. 微架构说明

**三级分层查表**（Change C2 重构：替代旧单级大 case 表）：

```
L1 nibble 表    : 每 4-bit → cnt_nib(0..4)，case 16 项推断 LUT4
L2 byte 对合并  : 相邻两 nibble 计数相加（pair_cnt，8-bit 组粒度）
L3 归并树       : NPAIR 个 pair_cnt 经平衡加法树（奇项直通）→ cnt_o
```

- **逻辑深度**：LUT4(1) + 对加(1) + 归并树 ⌈log₂NPAIR⌉ ≈ 1+1+⌈log₂(W/8)⌉ 级；
- 面积要素：⌈W/4⌉ 个 LUT4 + NPAIR 个加法器 + 树；小 W 时比 tree 规整（表结构利于布局）。

## 3. 权值/功能守恒论证

- L1 表完备性：case 枚举 0..15 全部 16 项，popcount(nibble) 数学一致 ✓；
- L2/L3 加法权值不变形 ✓；
- 末尾越界 nibble：d_pad 零扩展（WPAD=NIBS*4 ≥ W）保证读出恒 0 → 计 0 ✓；
- 边界：全 0 → 0；全 1 → 每层和恰为段满值 → 根 W；无溢出（CNT_W 全精度）。

## 4. 参数化行为

| 参数 | 域 | 敏感度 |
|---|---|---|
| INPUT_WIDTH | 4~256 | NIBS/NPAIR 线性增长；树深 log |

防护：PC-001 + d_pad 零扩展（消除负 multiconcat，实测修复项）。

## 5. 验证映射

| 需求/不变量 | 手段 | 证据 |
|---|---|---|
| REQ-001/INV-001 | LUT-TB 1000 随机 + 锚点 | 编译期已过 /tmp 脚本可重放 |
| REQ-001（全空间） | tc_exhaust_w8 覆盖 PC_IMPL=2 档 | evidence/g4_functional/ |
| 编译矩阵 | W∈{4..256} | evidence/g3_static/param_matrix.txt |

## 6. PPA 摘录（run-20260827-01 观察）

大 W 与 tree 综合趋同（DC 将 case 表折叠为同构加法树）——本实现与 tree
共享 Pareto 左端点；差异化价值在 FPGA 目标与小宽度规整布局。

## 7. 已知限制

ASIC 大 W 无独立面积优势（趋同）；X 输入不承诺。

## 8. 变更记录

| Change | 日期 | 摘要 |
|---|---|---|
| C0 | 2026-08-27 | 初版（原 impl_lookup 单级表） |
| C2 | 2026-08-27 | 重构三级分层 + 零扩展修复 + 打平并入 popcount.sv |
