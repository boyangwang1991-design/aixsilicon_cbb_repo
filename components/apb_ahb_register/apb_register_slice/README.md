# apb_register_slice

> 单文件快速索引页（人工阅读入口）。SSOT 以 [`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)/[`profiles.yaml`](profiles.yaml)）为准，本文档为派生视图、仅用于快速浏览。

## 一句话定位

APB 寄存切片：在 APB 主↔子之间按模式对前向（地址/写数据/控制）与反馈（PREADY/PRDATA/PSLVERR）通路打拍，割断长组合路径（经典 PREADY 返回路径割断），不改变事务相位与顺序。

## 索引信息

| 项 | 值 |
|---|---|
| **VLNV** | `aixsilicon:cbb:apb_register_slice:0.1.0` |
| **类别 / ID** | `apb_ahb_register / BUS-003` |
| **抽象粒度** | `A3`（协议构件：APB 握手语义） |
| **技术域** | `apb_ahb_register`（次：无） |
| **成熟度** | `E0`（Implemented 候选，G3/G4 证据采集中） |
| **Owner** | `aixsilicon:cbb` |
| **接口语义** | `apb_passthrough`（信号级透传；APB 协议契约归 aixsilicon_hwif_repo） |
| **时钟域 / 复位** | 1 时钟；异步复位 `rst_n`（低有效） |
| **FuseSoC Core** | `aixsilicon:cbb:apb_register_slice:0.1.0` |

## 快速上手（实例化示例）

```systemverilog
apb_register_slice #(
  .ADDR_WIDTH (16),
  .DATA_WIDTH (32),
  .SLICE_MODE (2),   // 0=request / 1=response / 2=full
  .RESP_STAGES(1)    // 反馈寄存级数 1..2
) u_apb_register_slice (
  .clk(clk), .rst_n(rst_n),
  // 主侧（上游 APB）
  .psel_main(psel_m), .penable_main(penable_m), .paddr_main(paddr_m),
  .pprot_main(pprot_m), .pwrite_main(pwrite_m), .pwdata_main(pwdata_m), .pstrb_main(pstrb_m),
  .pready_main(pready_m), .prdata_main(prdata_m), .pslverr_main(pslverr_m),
  // 子侧（下游从设备）
  .psel_sub(psel_s), .penable_sub(penable_s), .paddr_sub(paddr_s),
  .pprot_sub(pprot_s), .pwrite_sub(pwrite_s), .pwdata_sub(pwdata_s), .pstrb_sub(pstrb_s),
  .pready_sub(pready_s), .prdata_sub(prdata_s), .pslverr_sub(pslverr_s)
);
```

## 参数速览

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `ADDR_WIDTH` | 16 | 8..32 | PADDR 位宽 |
| `DATA_WIDTH` | 32 | 8..64 | PWDATA/PRDATA 位宽 |
| `SLICE_MODE` | 2 | {0,1,2} | 0=request（前向打拍）/1=response（反馈打拍）/2=full（双打拍） |
| `RESP_STAGES` | 1 | 1..2 | 反馈寄存级数（SLICE_MODE!=0 有效） |

## 模式选择速查

| 场景 | 推荐 Profile | 前向延迟 | 反馈延迟 |
|---|---|---|---|
| 前向扇入长、反馈路径短 | `request_slice`（mode=0） | 1 拍 | 0（组合直通，ASM-004） |
| PREADY 返回路径长（经典） | `response_slice`（mode=1） | 0 | 1 拍 |
| 两侧组合路径均长/物理隔离 | `full_slice`（mode=2） | 1 拍 | 1 拍 |
| 反馈两级流水（远距/多级 mux） | `full_slice_deep`（mode=2,RS=2） | 1 拍 | 2 拍 |

## 关键文档

| 需求 | 文档 |
|---|---|
| 可读规格（需求/参数/行为） | [`docs/cbb_spec.md`](docs/cbb_spec.md) |
| Intake 结论 | [`docs/intake.md`](docs/intake.md) |
| 架构设计 | [`docs/design.md`](docs/design.md) |
| 详设（response / request+full） | [`docs/detail-design/`](docs/detail-design/) |
| 验证计划 | [`verification/plan.yaml`](verification/plan.yaml) |

## 非目标（摘录）

- APB 协议检查/BFM（→ aixsilicon_vip_repo）；地址译码/mux（BUS-004/005）；
  CDC（BUS-006）；位宽转换（BUS-007）；超时保护（BUS-008）。
