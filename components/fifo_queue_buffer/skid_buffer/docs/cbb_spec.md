# CBB 规格（Spec）— skid_buffer

> 本文件为**可读派生视图**；机器可读 SSOT 以 [`../cbb.yaml`](../cbb.yaml)（参数/约束/需求）与
> [`../behavior.yaml`](../behavior.yaml)（不变量/假设/非目标）为准，语义不双维护。

## 1. 需求（REQ）

| ID | 需求 | 属性 | 测试 |
|---|---|---|---|
| REQ-001 | 满吞吐与保序：随机 valid/ready/背压流下所有被接受输入按序输出，无丢无重 | PROP-SKID_ACCEPT-003, PROP-SKID_DATA-004 | tc_random, tc_backpressure |
| REQ-002 | 反压正确：全满时 `in_ready` 拉低；输出级空或槽有空位时必可接受输入 | PROP-SKID_READY-001, PROP-SKID_READY-002 | tc_backpressure, tc_edge |
| REQ-003 | 边界：DATA_W=1/极值/空流/单拍/连续背压；输出始终寄存（非 fall-through） | PROP-SKID_ACCEPT-003 | tc_edge |
| REQ-004 | 非法参数 DATA_W 越界在 Elaboration 期被拦截（generate `$error`） | —（负向编译证据） | tc_negative_elab |

## 2. 参数

| 参数 | 类型 | 默认 | 合法域 | 影响面 | 语义 |
|---|---|---|---|---|---|
| `DATA_W` | int | 32 | [1, 1024] | 接口宽度/面积/时序 | 数据通路位宽（in/out 共享） |

约束：`PC-001 DATA_W>=1`；`PC-002 DATA_W<=1024`（error 级，RTL generate `$error` 双拦截）。

## 3. 行为契约

- **接口**：valid-ready 握手（`in_valid/in_data/in_ready` → `out_valid/out_data/out_ready`）；
- **时钟**：单时钟域，低有效异步复位 `rst_n`；
- **吞吐**：1/cycle，满吞吐无气泡（背压由 SKID 槽吸收）；
- **顺序**：in-order（FIFO 保序，无丢无重）；
- **不变量 INV**：满吞吐（INV-001）、反压条件（INV-002）、保序（INV-003）、输出寄存（INV-004）；
- **假设 ASM**：valid/数据在等待 `in_ready` 时保持稳定；同步复位释放；2-state 语义；
- **非目标**：BYPASS 直通（STR-007）、多级打拍（QUE-008）、fall-through、CDC。

## 4. 微架构（单实现 impl_output_registered）

两级 bubble-free 拓扑：**OUT 寄存级**（`out_valid_r/out_data_r`）+ **SKID 槽**
（`buf_valid_r/buf_data_r`）。

```
in_ready = ~out_valid_r | out_ready | ~buf_valid_r    // 全满才反压
// OUT 级腾出（out_ready | ~out_valid_r）时：槽数据优先补 OUT（FIFO 保序），
//   槽空才输入直达；无来源则置空
// 输入接受（in_valid & in_ready）时：输出级腾出 → 直达（槽空）或替换槽数据（槽满）；
//   否则进槽（槽必空，in_ready 保证）
```

- `out_valid`/`out_data` 完全寄存 → 切断 valid→ready 组合路径；
- `in_ready` 组合深度 ≤1 级（仅依赖寄存状态 + 下游 ready）；
- **保序**：输出级腾出时**槽数据优先**（FIFO 顺序），新输入仅在槽空时直达；
- 背压时输入存槽（槽必空），恢复后槽数据补 OUT，无额外空泡。

## 5. 时钟/复位

| 信号 | 方向 | 说明 |
|---|---|---|
| `clk` | in | 单时钟 |
| `rst_n` | in | 低有效，异步拉低（FF 用 negedge 复位） |
