# width_conversion_fifo 规格说明（可读视图）

> 派生视图：SSOT 为 [`cbb.yaml`](../cbb.yaml) 与 [`behavior.yaml`](../behavior.yaml)，本文件仅为人工评审可读副本，语义以 YAML 为准。

## 1. 定位

单时钟同步 FIFO + **整数比宽度转换**（QUE-012，A2/A3，P1）。在窄总线与宽存储/接口之间搬移数据，同时完成缓冲与位宽转换，两侧标准 ready/valid 握手，单时钟域、同步复位。

## 2. 需求（REQ）

| ID | 需求 | 属性 |
|---|---|---|
| REQ-001 | 窄→宽：每 `RATIO` 个窄字组合为 1 宽字，宽字低位对应先进窄字（小端） | `PROP-WC_N2W-001` |
| REQ-002 | 宽→窄：1 宽字拆 `RATIO` 窄字，按 FIFO 顺序输出（低段→高段，保序） | `PROP-WC_W2N-001` |
| REQ-003 | FIFO 保序：输出顺序与输入写入顺序一致 | `PROP-WC_ORD-001` |
| REQ-004 | 无丢失：握手接受的数据不得丢弃；无重复：不重复输出 | `PROP-WC_LOSSLESS-001`/`PROP-WC_NODUP-001` |

## 3. 参数

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `DIRECTION` | enum | NARROW_TO_WIDE | [NARROW_TO_WIDE, WIDE_TO_NARROW] | 转换方向 |
| `NARROW_WIDTH` | int | 8 | 1–512 bit | 窄侧位宽 |
| `RATIO` | int | 4 | 2–64 | 宽侧位宽 = `NARROW_WIDTH×RATIO` |
| `DEPTH` | int | 8 | 2–1024，`DEPTH>=RATIO` | FIFO 深度（窄字单位） |

约束（PC）：`NARROW_WIDTH≥1`、`RATIO≥2`、`DEPTH≥2`、`NARROW_WIDTH×RATIO≤4096`、`DEPTH≥RATIO`（死锁防护）。

## 4. 行为不变量（INV）

- INV-001 无丢失、INV-002 无重复、INV-003 保序；
- INV-004 N2W 小端拼接、INV-005 W2N 低段→高段拆分、INV-006 满空安全（指针/计数不越界）。

## 5. 接口与时钟复位

- 输入：`narrow_in_*` / `wide_in_*`（ready/valid）；输出：`narrow_out_*` / `wide_out_*`；
- 单时钟 `clk`、同步低有效复位 `rst_n`；满时输入 ready 拉低、空时输出 valid 拉低。

## 6. 假设与非目标

- ASM-001 无界背压（ready 可任意周期拉低）、ASM-002 读写并发由指针/计数保证；
- 非目标：非整比 gearbox、多时钟域（CDC）、乱序/QoS/仲裁、打包/解包协议语义。

## 7. 集成限制

- 仅整数比；`DEPTH>=RATIO` 强制；宽侧位宽 ≤4096；
- 用途：窄总线写宽存储、宽读分拍窄出、DMA/协议适配数据整形。

## 8. 追踪

需求→属性→测试→配置映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)；验证形态与矩阵见 [`verification/plan.yaml`](../verification/plan.yaml)。