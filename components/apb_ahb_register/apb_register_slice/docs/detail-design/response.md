# detail-design: impl_response（SLICE_MODE=1，经典 PREADY 返回路径割断）

> 详设（C3 前置）：微架构、逻辑深度、守恒论证、PPA 优化点。契约见 `cbb.yaml`/`behavior.yaml`。

## 1. 微架构

```
main（APB 主侧）                          sub（APB 子/从侧）
  psel_main ────── assign ────────────────▶ psel_sub        （前向组合直通）
  penable_main ─── assign ────────────────▶ penable_sub
  paddr/pprot/pwrite/pwdata/pstrb ─ assign ▶ 同名 _sub
  pready_main ◀── resp_stage1[ready] ◀═══ pready_sub       （反馈 1 拍寄存）
  prdata_main ◀── resp_stage1[data]  ◀═══ prdata_sub
  pslverr_main ◀─ resp_stage1[err]   ◀═══ pslverr_sub
```

- 反馈组寄存：`resp_stage1 <= {pslverr_sub, prdata_sub, pready_sub}`，`RESP_STAGES=2`
  时 `resp_stage2 <= resp_stage1`，主侧取末级。
- 前向零逻辑：纯 `assign` 直通（无面积、无延迟）。

## 2. 逻辑深度

- 前向：0 级（assign）。
- 反馈：1 拍 + 0 级组合（寄存输出直连主侧）；RESP_STAGES=2 为 2 拍。
- 关键路径：子侧寄存/组合 → 反馈寄存 D 端（prdata 仅走线）；主侧→子侧当拍直达。

## 3. 守恒论证（无丢/无重/无错位）

- **完成事件**：`pready_sub` 高的拍被寄存沿捕获，恰 1 拍后在主侧呈现；子侧保持多拍
  不产生多次呈现（寄存沿采样，非边沿计数）→ 无重。
- **对齐**：pready/prdata/pslverr 同组寄存（同一 always_ff 同一 RHS 向量拼接），
  物理上同拍翻转 → 数据/错误与完成天然对齐（INV-003），无移位错位。
- **相位**：前向直通使 psel_sub/penable_sub 与主侧同拍同相位；反馈打拍只作用于
  "完成呈现"，不影响主侧相位状态机（主侧在 ACCESS 等 PREADY，多等 1 拍即新延迟）→
  相位语义守恒（INV-001）。
- **顺序**：APB 单事务总线（无并发第二事务），打拍不重排。

## 4. PPA 优化点

- 面积 ≈ DATA_WIDTH+2 触发器（反馈组）；三模式中最小。
- 时序：割断子侧 PREADY 返回 mux/长线组合（本构件存在意义）；主→子为纯组合直通，
  若前向路径才是瓶颈应选 request/full 模式。
- 综合风险：无（无算术/无深 mux）；prdata 寄存可被 DC 重排为 input-skew 寄存（收益）。

## 5. 生成方式

单文件 `rtl/apb_register_slice.sv` 内 `generate if (SLICE_MODE==1)` 分支；无独立文件。
