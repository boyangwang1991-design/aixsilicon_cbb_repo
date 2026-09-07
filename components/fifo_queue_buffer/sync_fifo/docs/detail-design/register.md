# 详设：impl_register（IMPL=0，读写指针 + 寄存器堆）

> 生命周期 C3 前置。前置：架构（`docs/design.md` + `profiles.yaml`）已通过 G2；规格确认门已过。
> 本文档为**写 RTL 前**的详细设计（implement-cbb-rtl step 1 强制），经**详设确认门**用户确认后方可实现。

## 1. 微架构

单模块 `sync_fifo` 内 generate 分支（`IMPL==0`），与 shift 共享 count/满空/输出级：

```
状态：count[CNT_W-1:0]（CNT_W=$clog2(DEPTH+1)，含 0..DEPTH）
      wptr[PTR_W-1:0] / rptr[PTR_W-1:0]（PTR_W=$clog2(DEPTH) 保护，DEPTH≥2 → ≥1）
存储：logic [DATA_W-1:0] mem[0:DEPTH-1]
```

- `push_ok = push_i && ~full_o`；写 `mem[wptr] <= data_i`（沿 t 捕获），`wptr <= wptr+1`（回绕）。
- `pop_ev = pop_i && ~empty_o`（**沿前非空**判定，防下溢）；comb/reg 输出模式决定数据呈现。
- 计数：`count <= count + push_ok - pop_ev`（同拍 push+pop 净 0；满写/空读被 mask，无上/下溢）。

## 2. 逻辑深度与守恒论证

- 关键组合路径：
  - 计数路径：`push_i/pop_i → (count+1/-1 加法, CNT_W 位) → count`（小位宽，深度对数）。
  - full/empty：`count == DEPTH` / `count == 0`（CNT_W 位比较器，1 级）。
  - comb 输出：`head = mem[rptr]`（DEPTH 选 1 mux，深度 O(DEPTH)）+ `~empty 门控`——读路径
    主要时序关注点（大 DEPTH 时建议 OUTPUT_REG=1 或 SRAM 方向）。
  - reg 输出：`rd_valid_q/rd_data_q` FF 切段 read→ready 组合链（fmax 收益），读延迟 1 拍。
- 守恒论证：count 仅被 `push_ok`（+1）与 `pop_ev`（-1）修改；两者不能同时无效地越界
  （push_ok 前提 ~full → count<DEPTH；pop_ev 前提 ~empty → count>0），故 count∈[0,DEPTH] 不变式保持。

## 3. 边界条件（domain-rules §3.1.1 实测坑自查）

| 坑 | 对策 |
|---|---|
| `$clog2(DEPTH)` 当 DEPTH=2 → PTR_W=1（OK）；DEPTH 上界 256 → PTR_W=8；DEPTH 非 2 幂（129/3） | 指针回绕用 `(p==DEPTH-1)?0:p+1`（不依赖 2 幂回绕，避开位选越界） |
| 计数位宽 `$clog2(DEPTH+1)` | `CNT_W` 覆盖 0..DEPTH（含 DEPTH 满值） |
| full 表达式溢出 | `full_o = (count == CNT_W'(DEPTH))` 位宽对齐 |
| 空 FIFO 输出误报 | comb：`rd_valid_o = ~empty_o`（count 派生），`rd_data_o = ~empty_o ? head : '0` |
| 输出寄存（OUTPUT_REG=1）pop 判定滞后下溢 | `pop_ev` 用沿前 `~empty_o && pop_i`（非空判定）；`rd_valid_q<=~empty_o`、`rd_data_q<=head`（弹空拍缓存最后 head） |
| 弹空后 valid 残存 | 断言用 `empty_o |-> ##1 ~rd_valid_o`（下拍拉低，非立即） |

## 4. PPA 优化点（RTL 完成前评估，E0）

- 面积驱动：`DEPTH×DATA_W` FF（存储）+ 计数/指针 FF。存储不可省；读侧 mux 是面积/时序杠杆。
- 时序杠杆：OUTPUT_REG=1 寄存 head（把 O(DEPTH) 读 mux 移出输出组合路径）；comb 模式
  读路径 = mux + ~empty 门，DEPTH 大时收敛风险高。
- 理论下界：面积 ≥ DEPTH×DATA_W（存储下界）；读路径 ≥ O(log DEPTH)（若用树形 mux，DC 自动）。
- 收敛风险：comb 大深度读 mux → 建议 profile 限定或 OUTPUT_REG=1；`default_register`
  面向中等 DEPTH（≤64），`register_registered_out` 面向深/高频。
- 大宽度杠杆：DATA_W 大时输出 mux 宽度线性放大——同样倾向 OUTPUT_REG=1。

## 5. 生成方式

SV 手写（`rtl/sync_fifo.sv` 内 generate 分支，无 Python 生成）。
