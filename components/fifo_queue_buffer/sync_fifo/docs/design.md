# sync_fifo 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1（规格确认门 2026-09-03 通过）。
> SSOT：本文档为架构决策记录视图；机器可读多实现/Profile 见 [`../profiles.yaml`](../profiles.yaml)。

## 1. 模块划分

单模块、单文件极简（`rtl/sync_fifo.sv`，无 package/interface）。参数化存储与输出级：

```
sync_fifo
├── 参数检查：generate $error（DATA_W/DEPTH/OUTPUT_REG/IMPL，PC-001..006）
├── 写侧：push_i & ~full_o → 写入指针 wptr / 移位入口（写入路径）
├── 存储：
│   ├── IMPL=0 register → logic [DATA_W-1:0] mem[DEPTH]（wptr 写、rptr 读）
│   └── IMPL=1 shift   → 移位寄存器链（push 平移 + 尾写、pop 头出）
├── 计数/状态：count ∈ [0,DEPTH]（full=count==DEPTH、empty=count==0 派生）
└── 输出级：
    ├── OUTPUT_REG=0 comb  → rd_valid_o=~empty_o、rd_data_o=头（组合，0 延迟）
    └── OUTPUT_REG=1 reg   → rd_valid_q/rd_data_q 输出 FF（1 拍延迟、弹空缓存语义）
```

- RTL 布局：默认单文件 `rtl/sync_fifo.sv`（pkg+module 同居、interface 不单独拆分，对齐
  artifact-contract §2 极简单文件规范）。register/shift 差异经 generate 参数化在同一文件内
  表达（共享计数/输出级，避免 `rtl/impl/` 拆分造成的契约复制；多实现共享契约原则满足）。
- 嵌套依赖：无（`implementations[].dependencies[]` 为空）。

## 2. 多实现与 Profile

**共享同一可观察契约**（参数/行为/时序一致——保序、满/空/计数、输出语义），差异仅在
存储微架构与输出级实现（domain-rules §4）。

| Profile | implementation | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|
| `default_register` | impl_register（IMPL=0, comb） | latency | 通用深度缓冲、组合读出 0 延迟 | supported |
| `register_registered_out` | impl_register（IMPL=0, reg） | fmax | 高频/反压路径时序隔离（输出级寄存） | supported |
| `shift_shallow` | impl_shift（IMPL=1, comb） | area | 浅深（≤32）低面积/低功耗队列 | supported |
| `shift_registered_out` | impl_shift（IMPL=1, reg） | fmax | 浅深 + 寄存输出组合（证据待补） | experimental |

生成方式决策：**SV 手写**（默认）——控制/存储/指针逻辑简单规整，无 Python 生成必要
（design-cbb step 3）。

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 单 `clk` |
| 复位 | 低有效异步复位 `rst_n`（FF 用 negedge）；释放后 count=0、wptr/rptr=0、输出级清零 |
| X 语义 | 复位后无 X（count/指针/输出级均有 reset 值）；数据路径输入 X 传播视为未定义（ASM-003） |
| 异常行为 | 满时 push 无效（不写入、count 不增）；空时 pop 无效（不产生读、count 不减）——无溢出/下溢 |

## 4. 关键数据路径（契约细化）

### 4.1 计数与满/空（共享）

- `count`（`CNT_W = $clog2(DEPTH+1)` 位）为唯一状态源；`push_ok = push_i && ~full`、
  `pop_ev = pop_i && ~empty`（沿前非空判定，防下溢——domain-rules §3.1.1）。
- `count_next = count + push_ok - pop_ev`（同拍 push+pop 净 0；满写/空读被 mask）。
- `full_o = (count == DEPTH)`、`empty_o = (count == 0)`——由寄存 count 派生，组合深度 ≤1 级。

### 4.2 IMPL=0 register：读写指针存储

- 存储 `logic [DATA_W-1:0] mem[0:DEPTH-1]`；写 `mem[wptr] <= data`（push_ok）、读组合
  `head = mem[rptr]`（rptr 指向下一个待读项）。
- `wptr/rptr` 位宽 `PTR_W`（`DEPTH` 非 2 幂亦可），回绕用 `+1` 与 `PTR_MAX` 比较归零
  （不依赖 2 幂回绕，避免 `$clog2` 位选陷阱；DEPTH 上界 256 → PTR_W 有界）。
- 输出级：
  - comb：`rd_valid_o = ~empty_o`、`rd_data_o = ~empty_o ? head : '0`；
    pop 当拍消费 head，次拍 rptr 推进、新 head 可见。
  - reg：`rd_valid_q <= ~empty_o`、`rd_data_q <= head`（弹空拍缓存最后 head，空态稳定后
    `rd_valid_q` 下一拍拉低——INV-004）；物理 pop 由沿前非空判定（`~empty_o && pop_i`）。

### 4.3 IMPL=1 shift：移位寄存器存储

- 存储为移位链 `logic [DATA_W-1:0] shift_mem[0:DEPTH-1]`，有效条目紧排 `[0..count-1]`：
  **push 尾写**（新数据写入 `shift_mem[count]`，同拍 pop/refill 时尾前移一位，已占用条目
  不平移）；**pop/refill 全体左移**（`[i]<=[i+1]`），头（最老项）固定 `shift_mem[0]`
  ——无地址译码、读侧固定 index0（无读 mux）。
- 为满足"浅深"（≤32）语义：pop/refill 全体左移使能扇出 DEPTH×DATA_W，深时功耗/拥塞劣化
  （见 profiles known_limits）；push 不平移（省 push 平移功耗）。
- 输出级与 4.2 相同（comb/reg 语义一致，INV-003/004 共享）。

> 一致性论证（register/shift 等价）：两种存储在同一 `count` 状态机控制下，暴露相同
> full/empty/count/pop 输出序列；仅存储组织不同。仿真以参考模型队列整体比对 + register/shift
> 代表点同场景等价性交叉验证（REQ-006）。

## 5. 可验证性论证

- 每个 Profile 有验证路径：SVA（PROP-SYNC_*：count 守恒/满空/comb/outreg）+ Simulation
  （VCS 参考模型队列整体比对：tc_random/backpressure/edge/out_comb/outreg/reset）
  + Negative（elaboration `$error`）。
- 关键不变量映射 PROP：`PROP-SYNC_ORDER-001`（保序）、`PROP-SYNC_CNT-002`（计数守恒）、
  `PROP-SYNC_FULL-003`/`PROP-SYNC_EMPTY-004`（满空）、`PROP-SYNC_COMB-005`（组合读出）、
  `PROP-SYNC_OUTREG-006`（寄存输出弹空语义）——见 [`../trace/rtm.yaml`](../trace/rtm.yaml)。
- Profile 差异验证重点：register 大 DEPTH 边界（DEPTH=129/256）、shift 浅深代表点 + 等价性。

## 6. PPA 预筛（E0/exploratory）

- 定性趋势（E0 推断，与 G6 实测见 [`reports/ppa-report.md`](../reports/ppa-report.md)）：
  - register：面积 ≈ DEPTH×(DATA_W) FF + 计数/指针；读侧单个 DEPTH 选 1 mux
    （读路径随 DEPTH 增长）；comb 输出在 `head` 选择上加 `~empty` 门（≤1 级）。
  - shift：面积 ≈ DEPTH×DATA_W FF + **每槽"保持/左移/尾写"mux**；理论"省读 mux"预判
    **实测不成立**——run-20260903-01：shift 组合单元多于 register、面积/功耗均略大
    （d32 shift×comb 比 register×comb 大 9.5%、动态功耗 +12~14%）；仅 DEPTH≤4 / 多读口
    等未表征区可能反转。
  - OUTPUT_REG=1 增加输出级 FF（DATA_W+1+1），d8 slack 略降但切断输出路径/便于下游
    timing-closure。
- 证据等级：E0（结构推断）→ **E2（G6 实测，run-20260903-01）**：register×comb 为
  d8/d32 Pareto 支配点；400MHz 下 d32 全实现临界 MET。

## 7. 子依赖（若有）

| 子 CBB | VLNV | 共享契约点 | 验证协同 |
|---|---|---|---|
| （无运行时依赖） | — | — | — |

> 依赖按抽象粒度单向、防环（domain-rules §4.1）。IMPL=sram 方向依赖 A0 wrapper
> （TEC-015 sram_macro_wrapper, planned 未实现）——登记 non_goals，待用户同意委派后扩展
> （intake §3 / run_log）。
