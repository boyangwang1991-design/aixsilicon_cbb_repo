# parity_gen_check 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1。
> 简单 CBB（A1 单输出）本文档即完整架构视图。

## 1. 模块划分

```
parity_gen_check              # wrapper：参数检查 + SVA + PC_IMPL 分派
├── parity_impl_tree          # PC_IMPL=0 显式平衡 XOR 折半树（SV generate）
├── parity_impl_reduction     # PC_IMPL=1 一行 reduction XOR（^data_i）
├── parity_impl_linear        # PC_IMPL=2 显式线性 XOR 链（SV 手写）
└── 接口：data_i[W-1:0] → parity_o（1-bit，纯组合，无时钟）
```

- RTL 布局：单文件 `rtl/parity_gen_check.sv`（wrapper + 三实现同居，极简单文件规范）
- 嵌套依赖：无（dependencies=[]）

## 2. 生成方式决策（design-cbb SKILL §2）

| 实现 | 结构特征 | 生成方式 | 理由 |
|---|---|---|---|
| **impl_tree** | 显式平衡 XOR 折半树（O(log W)） | **SV generate**（显式折半树） | 显式书写以实证"显式树 vs reduction vs 链"三形态综合差异 |
| **impl_reduction** | 一行 reduction XOR | **SV 一行** `assign parity_i = ^data_i;` | reduction 一元运算符由 DC/Genus 自动生成最优平衡树；Python 与 SV 均可时**倾向 SV**（parity 复盘） |
| **impl_linear** | 显式 XOR 链（O(W)） | **SV 手写** | 显式链 vs 综合收敛的结构教学视图 |

**评估**：parity 判定为 **SV（非 Python 生成）**——reduction XOR 由综合器自动优化，
RTL 一行即可；显式树/链亦 SV 书写（三形态共同实证 G6 综合收敛：RTL 写法不影响综合
最优解）。Python 生成仅保留给 SV 无法简洁表达的复杂算法结构（如 wallace 调度网表）。

## 3. 多实现与 Profile

**共享同一可观察契约**（参数/行为/时序一致），差异仅在 XOR 归约树结构（domain-rules §4）。

| Profile | implementation | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|
| tree_default | impl_tree | balanced | 通用奇偶校验（ECC/总线 parity） | supported |
| reduction_alt | impl_reduction | code_simplicity | 极简 RTL 首选（综合器自动最优树） | experimental |
| linear_alt | impl_linear | area_small_w | 小宽度面积极敏感/结构教学 | experimental |

## 4. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 0（纯组合，无时钟端口；流水化属消费侧，ASM-002） |
| 复位 | 无（组合原子） |
| X 语义 | X/Z 输入不承诺（ASM-001）；输出由 XOR 归约即时决定 |
| 异常行为 | 非法参数（DATA_WIDTH 越界 / PARITY_TYPE/PC_IMPL 非法）elaboration `$error` 拦截（PC-001/002） |

## 5. 关键数据路径

- tree：`ceil(log2 W)` 级 XOR（显式折半）；reduction：综合器生成 `ceil(log2 W)` 级（等价）；
  linear：`W-1` 级 XOR 链
- 输出：`parity_o = xor_i ^ FLIP`（FLIP 由 PARITY_TYPE 决定，1 位取反零面积代价）
