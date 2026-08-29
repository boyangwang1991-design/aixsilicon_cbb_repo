# round_robin_arbiter

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

轮转（Round-robin）仲裁器：对请求向量按**等权轮转顺序**选出**唯一授权**（授权互斥 + 公平轮转，无静态优先），
支持锁存请求（latched）、寄存授权（FAST_GRANT）、ack 锁定（GRANT_ACK_EN）与三种微架构（mask/rotate+priority/pointer）。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:round_robin_arbiter:0.1.0` |
| **类别 / ID** | `arbitration_scheduling / ARB-002` |
| **抽象粒度** | A2 |
| **技术域** | `arbitration_scheduling`（次：`selection_decode`） |
| **成熟度** | E2（Implemented + Verified；G7 候选） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_req_grant`（request/grant 位向量，无总线协议） |
| **时钟域 / 复位** | 1 时钟（REQ_TYPE/FAST_GRANT/GRANT_ACK_EN=1 时用）；异步复位 `rst_n` |
| **FuseSoC Core** | `aixsilicon:cbb:round_robin_arbiter:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
round_robin_arbiter #(
  .NUM_REQ(8),
  .REQ_TYPE(0),        // 0=level 纯组合，1=latched 锁存请求
  .FAST_GRANT(0),      // 0=组合授权，1=寄存授权（1 拍延迟）
  .PC_IMPL(0),         // 0=mask，1=rotate+priority，2=pointer
  .GRANT_ACK_EN(0)     // 0=每拍重新决策，1=grant 锁定至 grant_ack_i 应答
) u_round_robin_arbiter (
  .clk(clk), .rst_n(rst_n),
  .req_i(req), .grant_ack_i(grant_ack), .grant_o(grant)
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `NUM_REQ` | 8 | 2..64 | 请求端数（请求向量位宽） |
| `REQ_TYPE` | 0 | {0,1} | 0=level 纯组合；1=latched 锁存至 ack 应答 |
| `FAST_GRANT` | 0 | {0,1} | 0=组合授权零延迟；1=输出寄存授权 1 拍 |
| `PC_IMPL` | 0 | {0,1,2} | 微架构：0=mask 链、1=rotate+priority、2=pointer |
| `GRANT_ACK_EN` | 0 | {0,1} | 0=每拍重新决策；1=grant 锁定至 ack 应答后轮转 |

> 约束：`NUM_REQ∈[2,64]`（PC-001/002）、枚举参数合法域（PC-003..006，详细见 [`cbb.yaml`](cbb.yaml)）。

## 轮转语义（核心）

- 维护轮转指针 `rr_ptr`，从 `rr_ptr` 起**回绕扫描**请求向量首个置位 → 授权；授权后 `rr_ptr = (授权索引+1) % N`。
- 单请求一直有效 → 重复授权同一位（**不饿死其它请求**）；连续多请求 → 按 RR 顺序轮流（等权公平）。
- `GRANT_ACK_EN=1`：grant 锁定至 `grant_ack_i` 应答后才轮转（消费方背压感知；防活锁由消费方保证）。

## 文档导航

| 文档 | 阶段 | 内容 |
|---|---|---|
| [`docs/intake.md`](docs/intake.md) | G0 | 边界判定 / 查重 / 消费者 / 风险 |
| [`docs/cbb_spec.md`](docs/cbb_spec.md) | G1 | 需求 / 参数 / 行为 / 接口（可读规格） |
| [`docs/design.md`](docs/design.md) | G2 | 模块划分 / 多实现 / 时钟复位 / Profile |
| [`docs/qualification-report.md`](docs/qualification-report.md) | G7 | 支持矩阵 / Gate 证据 / Waiver / 成熟度 |
| [`docs/detail-design/`](docs/detail-design/) | C3 | mask/rotate_prio/pointer 详设（含 PPA 优化点） |
| [`reports/ppa-report.md`](reports/ppa-report.md) | G6 | PPA sweep 结论（三实现综合收敛实证） |
