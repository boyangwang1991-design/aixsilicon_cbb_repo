# sync_fifo

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

单时钟域同步 FIFO 深度存储队列（push/pop 原生接口 + full/empty/count），
支持 register（读写指针+寄存器堆）与 shift（移位寄存器）双存储微架构、comb/reg 双输出级。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:sync_fifo:0.1.0` |
| **类别 / ID** | `fifo_queue_buffer / QUE-001` |
| **抽象粒度** | A2（通用复合：存储队列机制） |
| **技术域** | `fifo_queue_buffer`（次：`storage_queue`） |
| **成熟度** | E0（Implemented + Verified 候选；仅 Workflow Gate 可确认升级） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_push_pop`（push_i/pop_i + full_o/empty_o/count_o，非总线协议） |
| **时钟域 / 复位** | 单时钟 `clk`；低有效异步复位 `rst_n` |
| **FuseSoC Core** | `aixsilicon:cbb:sync_fifo:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
sync_fifo #(
  .DATA_W     (32),     // 数据位宽 [1,1024]
  .DEPTH      (16),     // 队列深度 [2,256]
  .OUTPUT_REG (0),      // 0=comb（组合读出）/ 1=reg（寄存输出级）
  .IMPL       (0)       // 0=register（读写指针+寄存器堆）/ 1=shift（移位存储）
) u_sync_fifo (
  .clk        (clk),
  .rst_n      (rst_n),
  .push_i     (push),
  .data_i     (wdata),
  .full_o     (full),
  .pop_i      (pop),
  .rd_valid_o (rvalid),
  .rd_data_o  (rdata),
  .empty_o    (empty),
  .count_o    (count)
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DATA_W` | 32 | [1, 1024] | 数据位宽（push/pop 共享） |
| `DEPTH` | 16 | [2, 256] | 队列条目深度（register 全域；shift 建议 ≤32） |
| `OUTPUT_REG` | 0 | {0,1} | 0=comb 组合读出（0 读延迟）；1=reg 寄存输出级（1 拍读延迟/弹空缓存） |
| `IMPL` | 0 | {0,1} | 0=register（读写指针+寄存器堆，默认）；1=shift（移位寄存器存储） |

> 约束：`PC-001 DATA_W>=1`；`PC-002 DATA_W<=1024`；`PC-003 DEPTH>=2`；`PC-004 DEPTH<=256`；
> `PC-005 OUTPUT_REG∈{0,1}`；`PC-006 IMPL∈{0,1}`（详细见 [`cbb.yaml`](cbb.yaml)）。

## 文档导航

| 文档 | 阶段 | 内容 |
|---|---|---|
| [`docs/intake.md`](docs/intake.md) | G0 | 边界判定 / 查重 / 消费者 / 风险 |
| [`docs/cbb_spec.md`](docs/cbb_spec.md) | G1 | 需求 / 参数 / 行为 / 接口（可读规格） |
| [`docs/design.md`](docs/design.md) | G2 | 模块划分 / 多实现 / 时钟复位 / Profile |
| [`docs/detail-design/register.md`](docs/detail-design/register.md) | C3 | register 微架构详设 / PPA 优化点 |
| [`docs/detail-design/shift.md`](docs/detail-design/shift.md) | C3 | shift 微架构详设 / PPA 优化点 |
| [`docs/qualification-report.md`](docs/qualification-report.md) | G7 | 支持矩阵 / Gate 证据 / Waiver / 成熟度 |
| [`trace/rtm.yaml`](trace/rtm.yaml) | 工具生成 | 需求追踪矩阵 |
| [`verification/configs/`](verification/configs/) | G5 | 配置集（config-gen 生成：1/19/13/4） |
| [`verification/scripts/`](verification/scripts/) | G3-G4 | 可复现静态/功能验证脚本 |
| [`reports/ppa-report.md`](reports/ppa-report.md) | G6 | PPA 报告（8 点 E2 + Pareto + 对比图） |
| [`reports/ppa_run-20260903-01.png`](reports/ppa_run-20260903-01.png) | G6 | PPA 对比图（面积/slack/功耗 × DEPTH） |

## 快速状态（从 registry/run_log 派生，勿双维护）

- 已通过 Gate：G0–G6（静态 + 功能仿真 + PPA E2）；G5/G7 候选待 Workflow Gate 确认
- G6 PPA：`CHARACTERIZED_E2`（run-20260903-01，DC 400MHz 8 点全 MET；
  register×comb 为 Pareto 支配点；shift 实测不占优 → experimental）
- 已知限制：见 [`docs/qualification-report.md`](docs/qualification-report.md) §5

## 子依赖（若为组合 CBB）

| 子 CBB | VLNV | 用途 |
|---|---|---|
| （无运行时依赖） | — | — |

> 依赖方向单向、防环（见 cbb-development-suite / domain-rules §4.1）。IMPL=sram 宏存储方向
> 依赖未实现 A0 wrapper（TEC-015 sram_macro_wrapper），登记 non_goals（intake §3）。
