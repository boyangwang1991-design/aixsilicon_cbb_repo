# CBB 规格（Spec）— skid_buffer

> 本文件为**可读派生视图**；机器可读 SSOT 以 [`../cbb.yaml`](../cbb.yaml)（参数/约束/需求）与
> [`../behavior.yaml`](../behavior.yaml)（不变量/假设/非目标）为准，语义不双维护。

## 1. 需求（REQ）

| ID | 需求 | 属性 | 测试 |
|---|---|---|---|
| REQ-001 | 满吞吐与保序（full）：随机流下所有被接受输入按序输出，无丢无重 | PROP-SKID_ACCEPT-003, PROP-SKID_DATA-004 | tc_random, tc_backpressure |
| REQ-002 | 反压正确（full）：全满时 `in_ready` 拉低；输出级空或槽有空位时必可接受输入 | PROP-SKID_READY-001, PROP-SKID_READY-002 | tc_backpressure, tc_edge |
| REQ-003 | 边界：DATA_W=1/极值/空流/单拍/连续背压；输出始终寄存 | PROP-SKID_ACCEPT-003 | tc_edge |
| REQ-004 | 非法参数 DATA_W/BYPASS/IMPL 越界在 Elaboration 期被拦截（generate `$error`） | —（负向编译证据） | tc_negative_elab |
| REQ-005 | forward（IMPL=0）：data/valid 打拍 1 拍、ready 组合透传，保序无丢 | PROP-FWD_ACCEPT-001, PROP-FWD_DATA-002 | tc_fwd_random, tc_fwd_backpressure |
| REQ-006 | BYPASS=1：组合零延迟直通（out=in、in_ready=out_ready），忽略 IMPL | PROP-BYP_DIRECT-001 | tc_bypass |

## 2. 参数

| 参数 | 类型 | 默认 | 合法域 | 影响面 | 语义 |
|---|---|---|---|---|---|
| `DATA_W` | int | 32 | [1, 1024] | 接口宽度/面积/时序 | 数据通路位宽（in/out 共享） |
| `IMPL` | int | 1 | {0,1} | 面积/时序/延迟 | 0=forward 简单打拍；1=full skid 满吞吐（默认） |
| `BYPASS` | int | 0 | {0,1} | 延迟/面积/时序 | 1=组合直通（零延迟），忽略 IMPL |

约束：`PC-001 DATA_W>=1`；`PC-002 DATA_W<=1024`；`PC-003 IMPL∈{0,1}`；`PC-004 BYPASS∈{0,1}`
（error 级，RTL generate `$error` 双拦截）。

## 3. 行为契约

- **接口**：valid-ready 握手（`in_valid/in_data/in_ready` → `out_valid/out_data/out_ready`）；
- **时钟**：单时钟域，低有效异步复位 `rst_n`；
- **吞吐**：full/BYPASS 1/cycle；forward 打拍 1 拍、ready 组合透传（背压由 ready 传导）；
- **顺序**：in-order（FIFO 保序，无丢无重，全模式）；
- **不变量 INV**：full 满吞吐/反压（INV-001/002）、保序（INV-003）、输出寄存（INV-004）、
  forward 打拍+ready 透传（INV-005）、BYPASS 直通（INV-006）；
- **假设 ASM**：valid/数据在等待 `in_ready` 时保持稳定；同步复位释放；2-state 语义；
  BYPASS=1 时 IMPL 忽略；
- **非目标**：多级打拍（QUE-008）、fall-through、CDC、ICG 门控数据路径。

## 4. 微架构（多实现 profile）

**wrapper**（[`rtl/skid_buffer.sv`](../rtl/skid_buffer.sv)）：参数检查 + `BYPASS` 直通 +
按 `IMPL` 实例化 forward/full 子模块（单文件极简风格，无 package/interface）。

```
BYPASS=1 ──▶ in_ready=out_ready; out_valid=in_valid; out_data=in_data   // 组合直通
IMPL=0   ──▶ skid_buffer_forward：out_valid_r<=in_valid; out_data_r<=in_data;
             in_ready=out_ready（ready 组合透传，背压直接传导）
IMPL=1   ──▶ skid_buffer_full：OUT 寄存 + SKID 槽（bubble-free 满吞吐，FIFO 保序）
```

- `impl_forward`（IMPL=0）：面积最小（1×DATA_W FF + 1 valid FF），延迟 1 拍，ready 链 = `out_ready→in_ready`（透传）；
- `impl_full`（IMPL=1）：满吞吐无气泡，双向切时序，ready 组合链 ≤1 级（寄存状态 + out_ready）。

## 5. 时钟/复位

| 信号 | 方向 | 说明 |
|---|---|---|
| `clk` | in | 单时钟 |
| `rst_n` | in | 低有效，异步拉低（FF 用 negedge 复位） |
