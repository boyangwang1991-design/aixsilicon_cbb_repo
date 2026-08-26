# width_conversion_fifo 架构设计（G2）

> CBB 生命周期 C2 阶段产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1。
> 执行深度：Standard Loop；执行模式：partial-task。

## 1. 模块划分

单一模块（A2/A3 粒度，参数与端口定制足够表达，无需层次拆分）：

```
width_conversion_fifo
├── 输入侧：窄侧 (narrow_*) / 宽侧 (wide_*) ready/valid 接口
├── 存储：同步 RAM（窄字单元，深度 DEPTH）
├── 方向逻辑：DIRECTION 参数 generate（N2W 拼接 / W2N 拆分）
└── 指针/计数：读写指针 + 计数（满/空判定）
```

- `rtl/interface/`：共享契约（参数检查 `$error`、接口、SVA 属性、公共 package）。
- `rtl/impl/impl_pointer_count/`：唯一微架构实现（指针+计数+方向生成逻辑）。

## 2. 多实现与 Profile

**共享同一可观察契约**（参数/行为/时序语义一致），差异仅在于优化目标。本版本功能实现单一
（`impl_pointer_count`），通过 **Profile** 区分消费者优化的参数/实现选择，满足 domain-rules §4
"Profile 对应真实 Use Case，差异在面积/频率/功耗 trade-off"。

| Profile | implementation | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|
| `area_opt` | impl_pointer_count | area | 窄总线存储接口，面积敏感（如低端 SoC 外设） | supported |
| `fmax_opt` | impl_pointer_count | fmax | 高频数据通路，输出侧寄存，关键路径敏感 | supported |
| `low_power` | impl_pointer_count | low_power | 低活动率场景，门控与节能（证据不足，试用） | experimental |

> 说明：本 CBB 微架构差异小（同一指针+计数结构），用 `generate` + Profile 表达，不拆多个实现文件，
> 符合 domain-rules §2.4"差异较小用 generate"。

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 单一 `clk`，所有状态同步更新 |
| 复位 | 同步复位 `rst_n`（低有效）；释放后指针/计数/输出寄存器清零，两侧 `*_valid` 无效 |
| X 语义 | 复位释放后无 X；读写并发由指针/计数保证无冲突（ASM-002） |
| 异常行为 | 满时不接受写（`narrow_in_ready`/`wide_in_ready` 拉低），空时不输出（`*_out_valid` 拉低） |

## 4. 方向数据路径（契约细化）

### 4.1 NARROW_TO_WIDE
- 每写入 1 窄字，`n2w_count` 递增；`n2w_count` 达到 `RATIO` 时组装宽字并置 `wide_out_valid`。
- 宽字位 = `{RATIO{NARROW_WIDTH}}` 拼接，**窄字 0（最先进）在最低位**（小端）。
- 存储按窄字计数：`used_words = count`；宽字占 `RATIO` 个窄字槽。

### 4.2 WIDE_TO_NARROW
- 每写入 1 宽字（占 `RATIO` 窄字槽），拆分 `RATIO` 个窄字写入 RAM 连续槽，分 `RATIO` 拍输出；
- 窄字 = 宽字按**低段到高段**切片（i=0 为低段），输出遵循 FIFO 顺序（保序，与 REQ-003 一致）。

### 4.3 满/空与背压
- 满：`used_words + 待组装/待拆分占用 >= DEPTH` 时，输入侧 ready 拉低。
- 空：`used_words == 0` 且无待输出片段时，输出侧 valid 拉低。
- 满吞吐：无背压下每拍可接受 1 窄字（N2W）或 1 宽字（W2N）；输出侧 N2W 每 `RATIO` 拍出 1 宽字，W2N 每拍出 1 窄字。

## 5. 可验证性论证

| 不变量 | 验证路径 | 属性 |
|---|---|---|
| 无丢失 / 无重复 | SVA（VCS）+ 定向/随机仿真 | PROP-WC-LOSSLESS-001 / NODUP-001 |
| 保序 | SVA + 仿真 | PROP-WC-ORD-001 |
| N2W 拼接 / W2N 拆分 | SVA + 参考模型对比 | PROP-WC-N2W-001 / W2N-001 |
| 满空安全（指针/计数不越界） | SVA + 边界仿真 | PROP-WC-FULLEMPTY-001 |
| 非法参数（宽侧 > 4096） | RTL `$error` elaboration 拦截 + 负向 | — |

每个 Profile 均有 VCS 仿真 + SVA 断言路径；PPA 在 G6 用 DC 综合表征。

## 6. 集成限制与非目标

- 仅整数比；`RATIO` 为 2 的幂时可简化，非 2 次幂按通用流水处理（状态/时序略增）；
- 不处理 CDC、乱序、QoS、多通道；打包/解包协议语义由 STR-014 覆盖；
- 宽侧位宽上限 4096 bit（`NARROW_WIDTH × RATIO ≤ 4096`），超出视为非法参数。
