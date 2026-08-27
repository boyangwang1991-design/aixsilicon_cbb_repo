# popcount

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

<一句话：这个 CBB 解决什么问题（如 "单时钟同步 FIFO + 整数比宽度转换"）>

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:<cbb_name>:<version>` |
| **类别 / ID** | `<category> / <registry-id>`（如 `fifo_queue_buffer / QUE-xxx`） |
| **抽象粒度** | `<abstraction>`（如 A2/A3） |
| **技术域** | `<primary_domain>`（次：`<secondary_domains>`） |
| **成熟度** | `<E0–E5>`（如 E2 = Implemented + Verified） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `<interface>`（如 `ready_valid`；引用 HWIF 契约） |
| **时钟域 / 复位** | `<N>` 时钟；`<sync/async>` 复位 `<rst_n>` |
| **FuseSoC Core** | `aixsilicon:cbb:<cbb_name>:<version>` |

## 快速上手（实例化示例）

```systemverilog
popcount #(
  .<PARAM_A>(<default>),
  .<PARAM_B>(<default>)
) u_<cbb_name> (
  .clk(clk), .rst_n(rst_n),
  // ... 关键端口连接
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `<PARAM_A>` | `<default>` | `<min~max / enum>` | <一句话> |
| `<PARAM_B>` | `<default>` | `<min~max / enum>` | <一句话> |

> 约束：`<PC-00x 摘要>`（详细见 [`cbb.yaml`](cbb.yaml)）。

## 文档导航

| 文档 | 阶段 | 内容 |
|---|---|---|
| [`docs/intake.md`](docs/intake.md) | G0 | 边界判定 / 查重 / 消费者 / 风险 |
| [`docs/cbb_spec.md`](docs/cbb_spec.md) | G1 | 需求 / 参数 / 行为 / 接口（可读规格） |
| [`docs/design.md`](docs/design.md) | G2 | 模块划分 / 多实现 / 时钟复位 / Profile |
| [`docs/qualification-report.md`](docs/qualification-report.md) | G7 | 支持矩阵 / Gate 证据 / Waiver / 成熟度 |
| [`trace/rtm.yaml`](trace/rtm.yaml) | 工具生成 | 需求追踪矩阵 |
| [`verification/configs/`](verification/configs/) | G5 | 配置集（config-gen 生成） |
| [`evidence/`](evidence/) | G3-G4 | 静态 / 功能验证证据 |

## 快速状态（从 registry/run_log 派生，勿双维护）

- 已通过 Gate：G0–G5 ◼ ｜ G6 PPA：`OPTIONAL_UNAVAILABLE(E0)` / 已表征
- 已知限制：<列表或指向 qualification-report §5>

## 子依赖（若为组合 CBB）

| 子 CBB | VLNV | 用途 |
|---|---|---|
| <sub_cbb> | `aixsilicon:cbb:<sub>:<version>` | <一句话> |

> 依赖方向单向、防环（见 cbb-development-suite / domain-rules §4.1）。