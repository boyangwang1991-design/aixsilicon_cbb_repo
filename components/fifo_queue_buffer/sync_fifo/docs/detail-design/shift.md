# 详设：impl_shift（IMPL=1，移位寄存器存储）

> 生命周期 C3 前置。前置：架构（`docs/design.md` + `profiles.yaml`）已通过 G2；规格确认门已过。
> 本文档为**写 RTL 前**的详细设计（implement-cbb-rtl step 1 强制），经**详设确认门**用户确认后方可实现。
> **实现修订（2026-09-03）**：移位语义最终确定为"push 尾写（count 索引） + pop/refill 全体左移、
> 头固定 index0"——与 RTL `g_shift_*` 分支一致（见 §1.2）。

## 1. 微架构

单模块 `sync_fifo` 内 generate 分支（`IMPL==1`），与 register 共享满/空/计数/输出级语义
（四分支独立实现但可观察契约一致）：

```
状态：count[CNT_W-1:0]（CNT_W=$clog2(DEPTH+1)）；reg 模式另含 rd_valid_q（输出级）
存储：logic [DATA_W-1:0] shift_mem[0:DEPTH-1]；有效条目紧排 [0..count-1]，头=shift_mem[0]
```

### 1.1 方向语义权衡（设计记录）

- **头固定 index0（读侧固定位）**：队列头（最先 pop）位于 `shift_mem[0]`——读端口固定索引，
  **无 DEPTH 选 1 读 mux**（相对 register 的核心 PPA 优势）。
- push 尾写：新条目写入当前尾 `shift_mem[count]`（同拍 pop 时尾前移一位 =
  `tail_c = count - pop_ev/refill`），已占用条目保持不动（不整体平移）。
- pop/refill 头出：`shift_mem[i] <= shift_mem[i+1]`（i=0..DEPTH-2）全体左移，头移入输出级
  或消费者；`shift_mem[DEPTH-1] <= '0`。
- 因 push 只写尾部（count 索引）、pop 只左移，**无需额外 wptr/rptr**——状态仅 count
  （reg 模式加输出级 1 词）。

### 1.2 选定语义（最终，与 RTL 一致）

- **方向约定**：头=最老项固定 `shift_mem[0]`（comb 输出 `rd_data_o = shift_mem[0]`；
  reg 输出 `rd_data_q <= shift_mem[0]` refill 沿前头）。
- **push（非满）**：写入尾索引 `tail_c`（无 pop 时 = count，同拍 pop 时 = count-1）；
  条目不整体平移（省翻转功耗 vs 压头方案——写尾 + 左移仅 pop 平移）。
- **pop/refill**：全体左移一级（`[i] <= [i+1]`），头移出；count-1。
- comb/reg 输出级与 register 完全一致（comb 直读头、reg refill 预取 + consume 消费）。
- 状态仅 count（+ reg 输出级有效位）；无 wptr/rptr、无地址译码。

## 2. 逻辑深度与守恒论证

- 组合路径：`head = shift_mem[0]`（固定位，**无 mux**）；full/empty 由 count 派生（≤1 级）；
  左移数据路径 `shift_mem[i] <= shift_mem[i+1]`（每 FF 一个"保持/左移"mux，级间无组合链）；
  尾写 `shift_mem[tail_c] <= data`（固定由 count 索引选择，一个写 mux）。
- 移位链代价：每 pop/refill 全体左移（DEPTH×DATA_W FF 平移使能），动态功耗随 DEPTH 线性——
  浅深（≤8/≤32）占优、深时劣化（profiles known_limits）。push 不平移（与"压头右移"方案相比
  省 push 平移功耗）。
- 守恒论证：与 register 相同——count 状态机唯一事实源；push_ok（~full）与 pop/refill
  （沿前非空）mask 越界，count ∈ [0,DEPTH]（reg 模式整体 count = 存储 count + 输出级有效）。

## 3. 边界条件（domain-rules §3.1.1 + §3.2 FIFO 专项自查）

| 坑 | 对策 |
|---|---|
| 移位方向写反 | §1.2 明确"头=index0、push 尾写、pop 左移"；用单点样例验证（push 1→2→3 → head 先 1） |
| 同拍 push+pop/refill 尾索引冲突 | `tail_c = count - (pop_ev 或 refill)`：左移腾出尾空位后写入新数据，不覆盖有效条目 |
| `$clog2(DEPTH)` 位宽（DEPTH≥2） | CNT_W=$clog2(DEPTH+1) 覆盖 0..DEPTH；PTR_W 仅用于 register 指针（shift 不用指针） |
| 空/满边界 | count 派生；空时 pop/refill 无效、满时 push 无效（无平移/无写） |
| comb/reg 输出级 | 与 register 共享同一输出级语义（comb 直读、reg refill/consume），INV-003/004 |
| 弹空缓存（OUTPUT_REG=1） | `rd_data_q <= shift_mem[0]`（沿前捕获最老项）；断言 `empty_c && ~rd_valid_q |-> ~rd_valid_o` |

## 4. PPA 优化点（E0 预判 → G6 实测修正，run-20260903-01）

**理论预判（E0，RTL 完成前）**：
- 面积驱动：DEPTH×DATA_W FF；读路径固定位输出 O(1)（无读 mux）；pop 左移使能扇出
  DEPTH×DATA_W（深时扇出/拥塞关注点）；push 尾写由一个 count 索引选择。
- 理论下界：面积 ≈ DEPTH×DATA_W FF；读路径 O(1)。

**G6 实测修正（E2，必须覆盖理论预判）**：
- **实测 shift 面积/功耗不优于 register**（d8=1041–1053 vs register×comb 957.6；
  d32=4095–4105 vs 3747，shift 大 9.5%；动态功耗 d32 shift 1821–1851 vs register
  1621–1685，+12~14%）——每个存储 FF 的"保持/左移/尾写"选择 mux（≈DEPTH×DW 个）
  组合开销 **>** 省下的单个读侧 mux（register 仅 1 个 DEPTH 选 1）。实测 cell 统计：
  shift 组合单元 d8=606 / d32=2274，均多于 register（484 / 1879）。
- 时序：d8 shift slack 0.03ns 显著差于 register×comb 0.55ns（refill 左移使能链深）；
  d32 全实现临界 MET（0.00–0.02）。
- 结论：shift 在本工艺/本深度区间**非 Pareto 优势实现**；建议仅保留为功能/结构备选
  （experimental），适用域收窄至 DEPTH≤4 / 多读口等**未表征区**（不宣称）。
- 与 register 等价性：REQ-006 参考模型 + 代表点交叉验证通过（功能等价，仅存储组织不同）。

## 5. 生成方式

SV 手写（`rtl/sync_fifo.sv` 内 generate 分支，无 Python 生成）。
