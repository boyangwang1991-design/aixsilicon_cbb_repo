# fixed_priority_arbiter

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

固定优先级仲裁器：对请求向量按固定优先级选出**唯一授权**（授权互斥 + 优先级链语义），支持
LSB/MSB 优先、锁存请求（latched）、寄存授权（FAST_GRANT）与三种微架构（linear/tree/grouped）。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:fixed_priority_arbiter:0.1.0` |
| **类别 / ID** | `arbitration_scheduling / ARB-001` |
| **抽象粒度** | A2 |
| **技术域** | `arbitration_scheduling`（次：`selection_decode`） |
| **成熟度** | E2（Implemented + Verified；G7 候选） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_req_grant`（request/grant 位向量，无总线协议） |
| **时钟域 / 复位** | 1 时钟（FAST_GRANT/REQ_TYPE=1 时用）；异步复位 `rst_n` |
| **FuseSoC Core** | `aixsilicon:cbb:fixed_priority_arbiter:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
fixed_priority_arbiter #(
  .NUM_REQ(8),
  .PRIORITY(0),        // 0=LSB 优先（req[0] 最高），1=MSB 优先
  .REQ_TYPE(0),        // 0=level 纯组合，1=latched 锁存请求
  .FAST_GRANT(0),      // 0=组合授权，1=寄存授权（1 拍延迟）
  .PC_IMPL(0)          // 0=linear，1=tree，2=grouped
) u_fixed_priority_arbiter (
  .clk(clk), .rst_n(rst_n),
  .req_i(req), .grant_ack_i(grant_ack), .grant_o(grant)
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `NUM_REQ` | 8 | 2..64 | 请求端数（请求向量位宽） |
| `PRIORITY` | 0 | {0,1} | 0=LSB 优先；1=MSB 优先 |
| `REQ_TYPE` | 0 | {0,1} | 0=level 纯组合；1=latched 锁存至 ack 应答 |
| `FAST_GRANT` | 0 | {0,1} | 0=组合授权零延迟；1=输出寄存授权 1 拍 |
| `PC_IMPL` | 0 | {0,1,2} | 微架构：0=linear 链、1=tree 前缀、2=grouped 分组 |

> 约束：`NUM_REQ∈[2,64]`（PC-001/002）、枚举参数合法域（PC-003..006，详细见 [`cbb.yaml`](cbb.yaml)）。

## 文档导航

| 文档 | 阶段 | 内容 |
|---|---|---|
| [`docs/intake.md`](docs/intake.md) | G0 | 边界判定 / 查重 / 消费者 / 风险 |
| [`docs/cbb_spec.md`](docs/cbb_spec.md) | G1 | 需求 / 参数 / 行为 / 接口（可读规格） |
| [`docs/design.md`](docs/design.md) | G2 | 模块划分 / 多实现 / 时钟复位 / Profile |
| [`docs/qualification-report.md`](docs/qualification-report.md) | G7 | 支持矩阵 / Gate 证据 / Waiver / 成熟度 |
| [`docs/detail-design/`](docs/detail-design/) | C3 | linear/tree/grouped 详设（含 PPA 优化点） |
| [`reports/ppa-report.md`](reports/ppa-report.md) | G6 | PPA sweep 结论（三实现综合收敛实证） |
| [`trace/rtm.yaml`](trace/rtm.yaml) | 工具生成 | 需求追踪矩阵 |
| [`verification/configs/`](verification/configs/) | G5 | 配置集（config-gen 生成） |
| [`verification/plan.yaml`](verification/plan.yaml) | G4 | 验证计划（形态/用例→需求映射） |

## 快速状态（从 registry/run_log 派生，勿双维护）

- 已通过 Gate：**G0–G6** ◼ ｜ G7/G8：`candidate`（Workflow Gate 确认）
- 已知限制：见 [`docs/qualification-report.md`](docs/qualification-report.md) §4（FAST_GRANT=1 单独 PPA、
  多 corner STA、消费者 Smoke 待补齐）

## 子依赖（若为组合 CBB）

无运行时子依赖（`implementations[].dependencies[]` 为空）。非目标：RR/WRR/多授权/层次仲裁
（见 ARB-002/003/007/008）。
