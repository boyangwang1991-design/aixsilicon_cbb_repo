# width_conversion_fifo（QUE-012）

单时钟同步 FIFO + **整数比宽度转换**的可复用公共构件（CBB），抽象粒度 `A2/A3`，风险 `P1`。

## 需求说明

在 SoC/DMA/协议适配数据通路中，经常需要在窄总线与宽存储/接口之间搬移数据。
`width_conversion_fifo` 在**一个同步 FIFO** 内同时完成缓冲与宽度转换：

- **NARROW_TO_WIDE**：窄侧每拍写入一个窄字；缓存凑齐 `RATIO` 个后，在宽侧输出一个宽字
  （宽字 = 连续窄字按**小端**拼接，先进窄字在低位）。
- **WIDE_TO_NARROW**：宽侧每拍写入一个宽字；拆分为 `RATIO` 个窄字，在窄侧按 FIFO 顺序分拍输出
  （低段→高段，保序）。

两侧均为标准 ready/valid 握手，单时钟域、同步复位，保序、无丢失、无重复。

## 关键参数

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| `DIRECTION` | `NARROW_TO_WIDE` | enum | 转换方向 |
| `NARROW_WIDTH` | 8 | 1–512 bit | 窄侧位宽 |
| `RATIO` | 4 | 2–64 | 宽侧位宽 = `NARROW_WIDTH × RATIO` |
| `DEPTH` | 8 | 2–1024（窄字单位） | FIFO 深度 |

## 非目标

- 非整数比 gearbox、多时钟域（CDC）、乱序/QoS/仲裁、打包/解包协议语义。

## 使用

- VLNV：`aixsilicon:cbb:width_conversion_fifo:0.1.0`
- 工程包结构见 [`docs/cbb_spec`](../../../docs/cbb_spec/)；规格契约见 `cbb.yaml` / `behavior.yaml`。

## 文档索引

- Intake：`docs/intake.md`
- 架构：`docs/design.md`
- 契约（SSOT）：`cbb.yaml`、`behavior.yaml`
- 验证矩阵 / 追踪：`verification/configs/`、`trace/rtm.yaml`
- 变更记录：`CHANGELOG.md`
