# incrementer_decrementer

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

Counter 专用 ±1 运算器（Incrementer/Decrementer）：`dout = din ± 1`（模 `2^DATA_W` 回绕），
纯组合、无时钟；提供两种微架构（ripple 半加器进位链 / segmented 分段进位）供
面积/时序 Pareto 权衡；输出溢出/借位标志 `carry_out` 供级联/饱和。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:incrementer_decrementer:0.1.0` |
| **类别 / ID** | `arithmetic_datapath / ARI-001` |
| **抽象粒度** | A1（原子数据通路算子，纯组合） |
| **技术域** | `arithmetic_datapath`（次：`control_event_status`） |
| **成熟度** | E1（Implemented + 单元验证；G3/G4 证据，G7 候选） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `native_bits_in_out`（原生位向量 ±1，无总线协议） |
| **时钟域 / 复位** | 无（纯组合，无时钟端口） |
| **FuseSoC Core** | `aixsilicon:cbb:incrementer_decrementer:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
incrementer_decrementer #(
  .DATA_W(32),      // 数据位宽 [2..1024]
  .ID_IMPL(0),      // 0=ripple, 1=segmented
  .SEG_W(4)         // segmented 段宽 [2..16]（仅 ID_IMPL=1 生效）
) u_ide (
  .din(din),        // [DATA_W-1:0] 输入
  .inc_en(inc_en),  // 递增使能（与 dec_en 互斥）
  .dec_en(dec_en),  // 递减使能（与 inc_en 互斥）
  .dout(dout),      // [DATA_W-1:0] ±1 结果（模 2^W 回绕）
  .carry_out(carry) // 递增到全 1 溢出 / 递减到 0 借位
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DATA_W` | 32 | [2,1024] | 数据位宽（PC-001/002） |
| `ID_IMPL` | 0 | {0,1} | 微架构（PC-003）：0=ripple, 1=segmented |
| `SEG_W` | 4 | [2,16] | segmented 段位宽（PC-004，仅 ID_IMPL=1 生效） |
| `CG_EN` | 1 | {0,1} | 自动 Carry/Data Gating（PC-005）：0=off, 1=on（hold 零翻转+XOR 直通，低功耗；无需 ICG） |

## 语义速览

- `inc_en=1, dec_en=0` → `dout = din + 1`（模 2^W 回绕）
- `inc_en=0, dec_en=1` → `dout = din - 1`（模 2^W 回绕）
- `inc_en=0, dec_en=0` → `dout = din`（保持）
- `inc_en=1, dec_en=1` → 未定义（ASM-002，调用方保证互斥）
- `carry_out = (inc_en & &din) | (dec_en & ~|din)`

## 文档链接

- [规格（可读）](docs/cbb_spec.md) · [设计](docs/design.md) · [详设 ripple](docs/detail-design/ripple.md) · [详设 segmented](docs/detail-design/segmented.md)
- [Intake（G0）](docs/intake.md) · [Qualification（G7）](docs/qualification-report.md) · [PPA 报告](reports/ppa-report.md)
