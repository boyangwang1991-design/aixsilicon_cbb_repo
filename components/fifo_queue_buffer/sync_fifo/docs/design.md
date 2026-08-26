# QUE-001 sync_fifo — 架构设计（G2）

## 1. 模块划分

单模块设计（A2 通用复合构件）。内部机制：

- **存储**：`logic [DATA_WIDTH-1:0] mem [DEPTH]`，由综合工具推断为 RAM/寄存器堆；
- **写指针** `wr_ptr` / **读指针** `rd_ptr`：写侧/读侧独立推进，环形寻址；
- **计数** `count`：0..DEPTH，决定 full/empty，避免指针比较歧义（标准同步 FIFO 做法）；
- **输出路径**：`OUTPUT_REG` 控制是否在存储输出再加一轮寄存（切短输出时序）。

## 2. 端口

| 信号 | 方向 | 语义 |
|---|---|---|
| clk / rst_n | 输入 | 单时钟；异步复位，释放同步（`reset_sync`） |
| wr_data[`DATA_WIDTH-1:0`] | 输入 | 写数据 |
| wr_valid / wr_ready | 输入/输出 | 写侧握手；`wr_ready = ~full` |
| rd_data[`DATA_WIDTH-1:0`] | 输出 | 读数据（`OUTPUT_REG=0` 时直接来自存储/旁路；=1 时寄存） |
| rd_valid / rd_ready | 输出/输入 | 读侧握手；`rd_valid = ~empty`（寄存后一拍生效） |

`DATA_WIDTH` 两侧同宽（无宽度转换，边界见 intake.md）。

## 3. 状态更新（每拍）

```
push = wr_valid && wr_ready          // 写侧接受
pop  = rd_valid && rd_ready          // 读侧弹出
count += push - pop                  // 同拍 push+pop 净变化，不越界
wr_ptr += push ? 1 : 0
rd_ptr += pop ? 1 : 0                // OUTPUT_REG=0：弹出拍即推进；=1：读指针在寄存级后一拍推进对应
```

> 忙状态更新在 `always_ff` 中对 `count` 使用一条自加表达式，同拍合并读写，
> 避免 over-write 与 [0..DEPTH] 越界。

## 4. 时钟复位 / 错误模型

- 单时钟域；`rst_n` 异步复位低有效，`count/wr_ptr/rd_ptr` 清零，输出 valid 拉低；
- 无 X 传播假设：复位后所有状态确定；满/空无冲突（计数制而非指针相等制）；
- `ASM-001`：ready 可任意周期拉低（无界背压）；
- `ASM-003`：复位为 async assert / sync deassert。

## 5. 多实现与 Profile

单一微架构 `impl_pointer_count`（指针+计数 + 可选输出寄存），差异仅参数覆盖：

| Profile | implementation | 参数 | 优化目标 | 支持 |
|---|---|---|---|---|
| area_opt | impl_pointer_count | dw8/dep8/oreg0 | area | supported |
| fmax_opt | impl_pointer_count | dw64/dep16/oreg1 | fmax | supported |
| deep_buffer | impl_pointer_count | dw64/dep1024/oreg1 | area | experimental |

所有实现共享契约/接口/断言（`rtl/interface/sync_fifo_pkg.svh` + DUT 内嵌 SVA），
可观察行为一致（保序/无丢失/无重复/满空安全/满吞吐）。

## 6. 可验证性论证

| 不变量 | 验证路径 | 属性 |
|---|---|---|
| 保序 | Formal（序列/读顺序性质）+ 定向仿真 | PROP-SF_ORD-001 |
| 无丢失 | Formal `accepted→eventually output` + 背压随机仿真 | PROP-SF_LOSSLESS-001 |
| 无重复 | Formal 唯一弹出 + 仿真记录比对 | PROP-SF_NODUP-001 |
| 满空安全 | Formal full/empty 互斥 + 边界仿真 | PROP-SF_FULLEMPTY-001, PROP-SF_CNTRL-001 |

每个 Profile 走 Formal/SMOKE 定向仿真；`fmax_opt`/`deep_buffer` 参数点额外纳入
Mandatory/Boundary（G5 配置空间覆盖）。

## 7. PPA 预筛（E0 探索性）

- 无标准单元库/PDK → 门级综合不可行，G6 标 `OPTIONAL_UNAVAILABLE`（E0）；
- 预筛关注点：`OUTPUT_REG` 对 fmax 的影响；大深度下综合存储推断差异；
  首拍延迟 1 vs 2 与面积/时序权衡（记录于 `characterization/plan.yaml`）。

## 8. 与同族构件差异

| 构件 | 差异 |
|---|---|
| QUE-003 Fall-through | 无 FWFT 直通；`OUTPUT_REG=0` 也为标准弹出（写拍后一拍才有效） |
| QUE-004 Shift-register | 存储由综合推断，非纯移位寄存器 |
| QUE-005 SRAM | 不例化/封装专用 SRAM |
| QUE-012 width_conversion | 无宽度转换，两侧同宽 |