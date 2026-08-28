# parity_gen_check 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1。
> 简单 CBB 允许将本文档合并进 `cbb_spec.md`（见 cbb-development-suite design-cbb）。

## 1. 模块划分

<模块结构描述，如：>

```
parity_gen_check
├── 输入侧：<接口组>（ready/valid）
├── 存储：<存储实现 / RAM（深度 DEPTH）>
├── 方向逻辑：<generate 分支 / 参数化逻辑>
└── <指针/计数/状态>：<…>
```

- RTL 布局：**默认单文件** `rtl/<cbb_name>.sv`（pkg+module 同居，interface 不单独拆分）。
- 嵌套依赖（若有）：实例化子 CBB `<sub_cbb>`（`implementations[].dependencies[]` 已声明 VLNV）。

## 2. 多实现与 Profile

**共享同一可观察契约**（参数/行为/时序一致），差异仅在优化目标（domain-rules §4）。

| Profile | implementation | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|
| `<area_opt>` | `<impl_xxx>` | area | <消费者场景> | supported |
| `<fmax_opt>` | `<impl_xxx>` | fmax | <高频场景> | supported |
| `<low_power>` | `<impl_xxx>` | low_power | <低功耗场景（证据不足）> | experimental |

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | <单/多 `clk` 及其来源> |
| 复位 | `<sync/async> rst_n`；释放后 <指针/计数/输出> 行为 |
| X 语义 | <复位后无 X；读写并发由指针/计数保证> |
| 异常行为 | <满时输入 ready 拉低；空时输出 valid 拉低> |

## 4. 关键数据路径（契约细化）

### 4.1 <方向 A / 模式 A>

- <行为描述：每写/读…凑满…输出…；拼接/拆分语义；边界条件>

### 4.2 <方向 B / 模式 B>

- <行为描述；与 4.1 的差异>

## 5. 可验证性论证

- 每个 Profile 有验证路径：<SVA/Formal/Simulation/Consumer Smoke>
- 关键不变量映射 PROP：`PROP-<NAME>-001…`（见 [`trace/rtm.yaml`](../trace/rtm.yaml)）
- Profile 差异的验证重点：<…>

## 6. PPA 预筛（E0/E1，若有）

- 定性趋势：<面积/时序随参数的定性结论；标记 E0/exploratory>

## 7. 子依赖（若有）

| 子 CBB | VLNV | 共享契约点 | 验证协同 |
|---|---|---|---|
| <sub_cbb> | `aixsilicon:cbb:<sub>:<version>` | <接口/握手> | <G4 联调> |

> 依赖按抽象粒度单向、防环（domain-rules §4.1）。