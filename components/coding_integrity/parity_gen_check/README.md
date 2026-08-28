# parity_gen_check

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图。

## 一句话定位

纯组合**奇偶校验**原子构件（reduction XOR）：`parity_o = ^data_i`（even）/ `~^data_i`（odd），
tree/reduction/linear **三实现** + G3/G4/G6 完整证据（COD-001）。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:parity_gen_check:0.1.0` |
| **类别 / ID** | `coding_integrity / COD-001` |
| **抽象粒度** | A1（原子机制） |
| **技术域** | `coding_integrity`（次：`arithmetic_datapath`） |
| **成熟度** | E2（Implemented + Verified） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_vector`（无总线协议） |
| **时钟域 / 复位** | 0 时钟（纯组合，A1 无时钟端口） |
| **FuseSoC Core** | `aixsilicon:cbb:parity_gen_check:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
parity_gen_check #(
  .DATA_WIDTH(64),   // [4..512]
  .PARITY_TYPE(0),   // {0=even, 1=odd}
  .PC_IMPL(0)        // {0=tree 显式平衡树, 1=reduction ^data, 2=linear 线性链}
) u_parity (
  .data_i(data),     // [DATA_WIDTH-1:0]
  .parity_o(parity)  // 1-bit
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DATA_WIDTH` | 64 | [4..512] | 输入向量位宽（XOR 归约树规模） |
| `PARITY_TYPE` | 0 | {0,1} | 0=even 偶校验；1=odd 奇校验（int 枚举，DC 综合兼容） |
| `PC_IMPL` | 0 | {0,1,2} | 0=tree 显式平衡树；1=reduction ^data；2=linear 线性链 |

## 报告

- PPA：[`reports/ppa-report.md`](reports/ppa-report.md)（含对比图）
- Qualification：[`reports/qualification-report.md`](reports/qualification-report.md)
