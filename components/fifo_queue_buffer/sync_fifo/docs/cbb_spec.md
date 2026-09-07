# CBB 规格（Spec）— sync_fifo

> 本文件为**可读派生视图**；机器可读 SSOT 以 [`../cbb.yaml`](../cbb.yaml)（参数/约束/需求）与
> [`../behavior.yaml`](../behavior.yaml)（不变量/假设/非目标）为准，语义不双维护。

## 1. 定位

同步 FIFO（Synchronous FIFO，单时钟域深度存储队列）：push/pop 原生存储接口 + full/empty/count
占用输出，支持寄存器堆/移位寄存器双存储微架构（register/shift）与组合/寄存输出级（OUTPUT_REG）。

- 抽象粒度：`A2（通用复合：存储队列机制）`
- 技术域：`fifo_queue_buffer`（次：`storage_queue`）
- Registry ID：`QUE-001`（已登记 planned，本次物化）
- 分类：CBB（无 CSR/软件契约/独立地址空间；参数与端口定制；被多 IP/Subsystem 内嵌复用）

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） |
|---|---|---|---|
| REQ-001 | 保序与无丢无重（register）：随机 push/pop 流下被接受写入按序输出一次且仅一次 | PROP-SYNC_ORDER-001, PROP-SYNC_CNT-002 | tc_random, tc_backpressure |
| REQ-002 | 满/空/占用计数一致性：full==(count==DEPTH)、empty==(count==0)、count 守恒 | PROP-SYNC_CNT-002, PROP-SYNC_FULL-003, PROP-SYNC_EMPTY-004 | tc_random, tc_backpressure, tc_edge |
| REQ-003 | 同拍 push+pop 与满写/空读并发边界（无上溢/下溢回绕） | PROP-SYNC_CNT-002 | tc_edge |
| REQ-004 | OUTPUT_REG=0 组合读出：empty 拉低同拍 rd_data 有效，pop 次拍指针推进 | PROP-SYNC_COMB-005 | tc_out_comb, tc_random |
| REQ-005 | OUTPUT_REG=1 寄存输出级：1 拍读延迟；弹空拍可消费缓存，空态稳定后 rd_valid 拉低 | PROP-SYNC_OUTREG-006 | tc_outreg, tc_edge |
| REQ-006 | shift 实现（IMPL=1）与 register 共享同一可观察契约（保序/满空/计数/输出） | PROP-SYNC_ORDER-001, PROP-SYNC_CNT-002 | tc_random, tc_backpressure |
| REQ-007 | 边界：DATA_W=1 / DEPTH=2 / 大深度 / 空流 / 满写连发 / 空读连发 | PROP-SYNC_EMPTY-004, PROP-SYNC_FULL-003 | tc_edge |
| REQ-008 | 非法参数 DATA_W/DEPTH/OUTPUT_REG/IMPL 越界在 Elaboration 期被拦截（generate `$error`） | —（负向编译证据） | tc_negative_elab |
| REQ-009 | 复位后状态清零（empty=1/count=0/full=0；reg 输出 rd_valid=0），可立即 push | — | tc_reset |

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `DATA_W` | int | 32 | [1, 1024] | 数据位宽（push/pop 共享） |
| `DEPTH` | int | 16 | [2, 256] | 队列条目深度（register 全域；shift 建议 ≤32） |
| `OUTPUT_REG` | int | 0 | {0,1} | 0=组合读出（0 读延迟）；1=寄存输出级（1 拍读延迟/弹空缓存语义） |
| `IMPL` | int | 0 | {0,1} | 0=register（读写指针+寄存器堆，默认）；1=shift（移位寄存器存储） |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | `DATA_W >= 1` | 非零位宽 |
| PC-002 | `DATA_W <= 1024` | RTL 位宽上界 |
| PC-003 | `DEPTH >= 2` | 最小深度（单条目归 A3 skid_buffer） |
| PC-004 | `DEPTH <= 256` | register 综合/仿真上界 |
| PC-005 | `OUTPUT_REG ∈ {0,1}` | 编码合法域 |
| PC-006 | `IMPL ∈ {0,1}` | 编码合法域 |

> 非法组合在 Elaboration 前被拦截（`cbb_tool.py check` + RTL `$error` generate 双拦截）。

## 4. 行为契约

- **接口**：原生 push/pop（`push_i/pop_i` + `full_o/empty_o/count_o`），非总线协议；
- **时钟**：单时钟域 `clk`，低有效异步复位 `rst_n`（异步拉低；释放后状态清零）；
- **吞吐**：非满每拍 push、非空每拍 pop（1/cycle）；满→push 反压 1 拍内生效（count 寄存派生）；
- **顺序**：in-order（FIFO 保序，无丢无重，register/shift 全模式）；
- **不变量 INV**：保序（INV-001）、计数守恒/满空一致（INV-002）、comb 读出（INV-003）、
  reg 输出级弹空语义（INV-004）、无组合环/锁存（INV-005）；
- **假设 ASM**：push 数据保持稳定；异步复位；2-state 语义；OUTPUT_REG×IMPL 可自由组合；
  无 override/flush（flush 归 A3 包装或消费者控制）；
- **异常**：复位释放后 count/指针/输出级清零；满时 push 无效、空时 pop 无效；
- **非目标**：CDC/异步（QUE-002）、FWFT 直读（QUE-003）、SRAM 宏存储（依赖未实现
  A0 wrapper TEC-015，登记 intake §3）、flush/override/peek、almost 水位中断。

## 5. 微架构（多实现 profile）

**单文件极简**（[`rtl/sync_fifo.sv`](../rtl/sync_fifo.sv)）：参数检查（generate `$error`）+ 按
`IMPL`/`OUTPUT_REG` generate 分派，无 package/interface。

```
push_i(~full) ──▶ 写指针/移位入口 ──▶ 存储（register 数组 / shift 链）
                                            │
pop_i(~empty) ──▶ 读指针/移位出口 ──▶ 输出级（OUTPUT_REG=0 组合 / =1 寄存 FF）──▶ rd_data_o/rd_valid_o
```

- `impl_register`（IMPL=0，默认）：读写指针 + `logic [DATA_W-1:0] mem[DEPTH]`；任意深度；
  读侧多路选择随 DEPTH 增长（大深度 PPA 关注点）；
- `impl_shift`（IMPL=1）：移位寄存器存储（push 时全链平移 / pop 时头出），浅深低功耗、
  无地址译码；建议 DEPTH≤32（见 profiles 限制）；
- 输出级与存储解耦：`OUTPUT_REG` 独立作用于两种存储实现。

## 6. 时钟/复位

| 信号 | 方向 | 说明 |
|---|---|---|
| `clk` | in | 单时钟 |
| `rst_n` | in | 低有效，异步拉低（FF 用 negedge 复位） |

## 7. 追踪与验证

需求→属性→测试→配置映射见 [`../trace/rtm.yaml`](../trace/rtm.yaml)（工具生成）；验证形态与矩阵见
[`../verification/plan.yaml`](../verification/plan.yaml) 与 [`../verification/configs/`](../verification/configs/)
（config-gen 确定性生成：1 mandatory + 19 boundary + 13 pairwise + 4 negative）。
