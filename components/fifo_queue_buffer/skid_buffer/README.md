# skid_buffer

**Valid-Ready 打拍模块（QUE-007，A3/P0）** —— 多实现 profile（forward / full / BYPASS），
在 valid-ready 数据通路上插入打拍寄存器改善时序。

## 需求说明

- **切断 ready 组合链**：`out_valid`/`out_data` 寄存（full），`in_ready` 只组合依赖寄存状态，
  组合深度 ≤1 级；
- **满吞吐无气泡（full）**：SKID 槽在背压时吸收输入，不产生气泡丢拍；
- **保序**：输入到输出 FIFO 顺序不变，无丢无重（forward/full 均满足）。

## 参数与实现（多实现 profile）

| 参数 | 默认 | 说明 |
|---|---|---|
| `DATA_W` | 32 | 数据位宽 [1,1024] |
| `IMPL` | 1 | 0=forward 简单打拍（面积最小）；1=full 满吞吐 skid（默认） |
| `BYPASS` | 0 | 1=组合零延迟直通（out=in、in_ready=out_ready，忽略 IMPL） |

| 实现 | 微架构 | PPA 特征（400MHz 实测） |
|---|---|---|
| `forward` | data/valid 打拍 1 拍，ready 组合透传 | 面积最小（W32≈86µm²），slack 2.02ns（与位宽无关） |
| `full` | OUT 寄存 + SKID 槽（bubble-free） | 满吞吐 + 短反压路径；W32≈252µm²，slack 0.81ns |
| `bypass` | 组合直通（零延迟） | 面积≈0（wire），arrival 0.02ns |

选择建议：面积/浅流水 → `forward`；满吞吐 + 深流水背压频繁 → `full`；零延迟旁路 → `BYPASS=1`。
详见 [`reports/ppa-report.md`](reports/ppa-report.md)。

## 接口

| 端口 | 方向 | 说明 |
|---|---|---|
| `clk` / `rst_n` | in | 时钟 / 低有效异步复位 |
| `in_valid` / `in_data[DATA_W-1:0]` / `in_ready` | 握手 | 输入 valid-ready |
| `out_valid` / `out_data[DATA_W-1:0]` / `out_ready` | 握手 | 输出 valid-ready |

## 验证状态

- G3 静态：VCS 编译矩阵（DATA_W×IMPL + BYPASS）+ 负向 $error 拦截（PC-001..004）
- G4 功能：VCS 仿真 4 配置（full32/fwd32/bypass32/full1）PASS，SVA 无失败
- G6 PPA：DC 400MHz tt corner 多实现对比（reg→reg worst slack 主判据）
- 配置集由 `config-gen` 确定性生成（`verification/configs/`）

详见 [`docs/cbb_spec.md`](docs/cbb_spec.md) 与 [`docs/intake.md`](docs/intake.md)。
