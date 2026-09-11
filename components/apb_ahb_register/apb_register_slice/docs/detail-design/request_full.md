# detail-design: impl_request（SLICE_MODE=0，前向打拍）与 impl_full（SLICE_MODE=2，双打拍）

> 详设（C3 前置）：两实现共享同一顶层与寄存结构，仅打拍位置不同（generate 分派）。

## 1. 微架构

### impl_request（SLICE_MODE=0）

```
main（APB 主侧）                          sub（APB 子/从侧）
  psel_main ══▶ fwd_q[psel] ═════════════▶ psel_sub        （前向 1 拍）
  penable_main ═▶ fwd_q[penable] ════════▶ penable_sub
  paddr/pprot/pwrite/pwdata/pstrb ═fwd_q═▶ 同名 _sub
  pready_main ◀───── assign ────────────── pready_sub      （反馈组合直通）
  prdata_main ◀───── assign ────────────── prdata_sub
  pslverr_main ◀──── assign ────────────── pslverr_sub
```

- 前向组寄存：`fwd_q <= {psel_main, penable_main, paddr_main, pprot_main, pwrite_main,
  pwdata_main, pstrb_main}`（1 拍；异步复位清零）。
- 反馈零逻辑：纯 `assign` 直通。
- 用途：割断主侧地址/写数据大扇入（多从译码后扇出）到子侧的组合路径；
  PREADY 即时返回（ASM-004：主↔子环回组合路径由消费方评估）。

### impl_full（SLICE_MODE=2）

- 前向组寄存（同上 fwd_q）+ 反馈组寄存（resp_stage1/2，同 impl_response）。
- 两侧组合路径均被寄存割断：主侧寄存 →（组合仅走线）→ 子侧寄存。
- 每事务完成延迟：前向 1 拍 + 反馈 RESP_STAGES 拍（独立叠加，INV-005）。

## 2. 逻辑深度

- impl_request：前向 1 拍 + 0 级组合；反馈 0 级。
- impl_full：前向 1 拍 + 0 级组合；反馈 RESP_STAGES 拍 + 0 级组合。
- 关键路径：主侧寄存 Q → 前向寄存 D（走线为主）；两侧寄存间无组合逻辑（割断特性）。

## 3. 守恒论证

- **前向原子性**：psel/penable 与 paddr/pwdata/pstrb 同组寄存（同一 RHS 拼接）→
  子侧看到的选中相位与地址/数据原子一致，不会出现"选中但地址未到"（INV-001/004）。
- **响应直通（request）**：组合 assign 不引入重排/丢拍；完成拍数据即子侧当前值。
- **顺序**：单事务总线 + FIFO 顺序寄存 → 无重排（透传守恒）。
- **full 模式独立性**：前向延迟与反馈延迟作用于不同通路，叠加不交互
  （寄存组无共享状态），INV-005 可分别定向验证。

## 4. PPA 优化点

- impl_request 面积 ≈ AW+3AW/8+DW+7 触发器（前向组，DW 主导）；impl_full 再加
  DW+2（反馈组）。
- 时序：前向寄存使 paddr/pwdata 扇出隔离在子侧域；full 模式两侧均为 reg→reg 短路径，
  适合远距物理隔离（floorplan 友好）。
- 综合风险：pstrb 位宽 DW/8（DATA_WIDTH 非 8 倍数时向下取整——参数约束保证 DW≥8，
  非 8 倍数宽度（如 36/9）按 DW/8 取整为 APB 常规语义，RTL 显式 `DATA_WIDTH/8` 整除）。

## 5. 生成方式

单文件 `rtl/apb_register_slice.sv` 内 `generate if (SLICE_MODE==0/1/2)` 三分支 +
`RESP_STAGES` 二级流水 generate；无独立文件。
