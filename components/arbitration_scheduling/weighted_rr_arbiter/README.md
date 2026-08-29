# weighted_rr_arbiter

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

带权轮转仲裁器（Weighted Round-robin Arbiter）：对请求向量按**权重比例公平**选出唯一授权（授权互斥 + 权重公平），
支持 quota 配额计数与 smooth credit 两种公平语义，可选寄存授权与 ack 锁定，两种微架构（quota_counter / deficit_rotate）。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:weighted_rr_arbiter:0.1.0` |
| **类别 / ID** | `arbitration_scheduling / ARB-003` |
| **抽象粒度** | A2（通用复合：加权仲裁机制） |
| **技术域** | `arbitration_scheduling`（次：`selection_decode`） |
| **成熟度** | E2（Implemented + Verified，G4 功能仿真通过） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_req_grant`（req_i + weight_i + grant_ack_i + grant_o；无总线协议，不引用 HWIF） |
| **时钟域 / 复位** | 1 时钟；异步复位 `rst_n`（低有效） |
| **FuseSoC Core** | `aixsilicon:cbb:weighted_rr_arbiter:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
weighted_rr_arbiter #(
  .NUM_REQ      (8),
  .WEIGHT_WIDTH (4),
  .WMODE        (0),          // 0=quota 配额计数 / 1=smooth credit
  .FAST_GRANT   (0),          // 0=组合授权 / 1=寄存授权（1 拍）
  .GRANT_ACK_EN (0),          // 0=每拍决策 / 1=grant 锁定至 grant_ack_i
  .PC_IMPL      (0)           // 0=quota_counter / 1=deficit_rotate
) u_wrra (
  .clk(clk), .rst_n(rst_n),
  .req_i(req), .weight_i(weight_packed), .grant_ack_i(ack), .grant_o(grant)
);
```

- `weight_i` 为每路权重连续打包：`weight_i[i*WEIGHT_WIDTH +: WEIGHT_WIDTH]` 为第 i 路权重（权重 0 无资格）。

## 验证状态

| 门禁 | 状态 | 证据 |
|---|---|---|
| G0 Intake / G1 Contract | pass | [`docs/intake.md`](docs/intake.md) + `check` |
| G2 Architecture | pass | [`docs/design.md`](docs/design.md) + detail-design/ |
| G3 RTL Static | pass | VCS 24 编译点 + 负向 elab + SpyGlass lint 0F/0E（`build/eda/evidence/g3_static/`） |
| G4 Functional | pass | WRRA_TB 全场景（`build/eda/evidence/g4_functional/functional_sim.txt`） |
| G5 Config Space | pass | config-gen 生成（mandatory/boundary/pairwise/negative） |
| G6 PPA | pass | DC 综合 E2（quota/smooth × 2 实现，[`reports/ppa-report.md`](reports/ppa-report.md)） |

## 非目标（详见 behavior.yaml non_goals）

Deficit RR（包长量子 ARB-004）、Age-based（ARB-005）、Lottery（ARB-006）、multi-grant（ARB-007）、
层次仲裁（ARB-008）、运行时权重热更新。
