# popcount

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

人口统计/位计数（Population Count）：对输入位向量返回其中 **1 的个数**（0..DATA_W），
纯组合、无时钟；提供五种微架构（直接加法/平衡树/Wallace/4:2 compressor/LUT）供
面积/时序 Pareto 权衡。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:popcount:0.1.0` |
| **类别 / ID** | `selection_decode / SEL-014` |
| **抽象粒度** | A1（原子数据通路算子，纯组合） |
| **技术域** | `selection_decode`（次：`arithmetic_datapath`） |
| **成熟度** | E1（Implemented；G3/G4 证据，G7 候选） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_bits_in_count_out`（原生位向量输入 → 计数输出） |
| **时钟域 / 复位** | 无（纯组合，无时钟端口） |
| **FuseSoC Core** | `aixsilicon:cbb:popcount:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
popcount #(
  .DATA_W(32),      // 输入位宽 [2..1024]
  .PC_IMPL(1)       // 0=direct,1=tree,2=wallace,3=comp4_2,4=lut
) u_popcount (
  .din(din),        // [DATA_W-1:0] 输入
  .popcnt(cnt)      // [clog2(DATA_W+1)-1:0] 输出（1 的个数）
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DATA_W` | 32 | 2..1024 | 输入位宽；输出位宽 NBITS=clog2(DATA_W+1) |
| `PC_IMPL` | 1 | {0..4} | 微架构：0=direct、1=tree、2=wallace、3=comp4_2、4=lut |

> 约束：`DATA_W∈[2,1024]`（PC-001/002）、`PC_IMPL∈{0..4}`（PC-003）、Wallace/compressor
> 仅支持 `DATA_W∈{8,16,32,64}`（PC-004，生成器位宽集，详见 [`cbb.yaml`](cbb.yaml)）。

## 微架构速览（PPA 权衡，详见表征报告）

| PC_IMPL | 结构 | 深度 | 面积 | 时序 | 适用 |
|---|---|---|---|---|---|
| 0 direct | 串行加法器链 | O(W) | 最小 | 最差 | 基线/教学 |
| 1 tree | 平衡归约树 | O(log W) | 中 | 优 | 通用默认 |
| 2 wallace | 3:2 FA+2:1 HA 归约 | O(log W) | 小 | 优 | 经典压缩 |
| 3 comp4_2 | 4:2 compressor 列间链 | ~log₄W | 中 | 最优 | 时序敏感 |
| 4 lut | 4bit 子块查表+小加法树 | O(log W) | 小 | 中 | 小位宽面积 |

> Wallace/compressor 由 [`tools/gen_popcount.py`](tools/gen_popcount.py) 动态生成
> （SSOT）为扁平网表 [`rtl/gen/`](rtl/gen/)，重新生成不手改。

## 文档导航

| 文档 | 阶段 | 内容 |
|---|---|---|
| [`docs/intake.md`](docs/intake.md) | G0 | 边界判定 / 查重 / 消费者 / 风险 |
| [`docs/cbb_spec.md`](docs/cbb_spec.md) | G1 | 需求 / 参数 / 行为 / 接口（可读规格） |
| [`docs/design.md`](docs/design.md) | G2 | 模块划分 / 多实现 / 生成器 / Profile |
| [`docs/qualification-report.md`](docs/qualification-report.md) | G7 | 支持矩阵 / Gate 证据 / Waiver / 成熟度 |
| [`docs/detail-design/`](docs/detail-design/) | C3 | direct/tree/wallace/comp4_2/lut 详设 |
| [`reports/ppa-report.md`](reports/ppa-report.md) | G6 | PPA sweep 结论（五实现综合收敛实证） |
| [`trace/rtm.yaml`](trace/rtm.yaml) | 工具生成 | 需求追踪矩阵 |
| [`verification/configs/`](verification/configs/) | G5 | 配置集 |
| [`verification/plan.yaml`](verification/plan.yaml) | G4 | 验证计划（形态/用例→需求映射） |

## 快速状态（从 registry/run_log 派生，勿双维护）

- 已通过 Gate：**G0–G4** ◼ ｜ G5–G8：`candidate`（Workflow Gate 确认）
- 已知限制：见 [`docs/qualification-report.md`](docs/qualification-report.md) §4
  （多 corner STA、消费者 Smoke、更大位宽 Wallace/compressor 生成待补齐）

## 子依赖（若为组合 CBB）

生成器 [`tools/gen_popcount.py`](tools/gen_popcount.py) 为标准库 Python（无运行时
依赖）；Wallace/compressor 无子模块。非目标：周期计数/累加（见 CTL-*、MON-* 计数器）。
