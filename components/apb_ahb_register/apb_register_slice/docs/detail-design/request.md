# 详设 — impl_request（SLICE_MODE=0，request 寄存切片）

## 1. 微架构

- **前向打拍**：`psel/penable/paddr/pprot/pwrite/pwdata/pstrb` 全组同步打 1 拍
  （`always_ff`，异步复位清零）——子侧相位与地址/数据原子到达，无半事务窗口。
- **反馈直通**：`pready_main = pready_sub`、`prdata_main = prdata_sub`、
  `pslverr_main = pslverr_sub`（连续赋值，零延迟）。

## 2. 逻辑深度

- 前向：1 级寄存（组合深度 0）；反馈：0 级寄存。
- 关键路径：主侧输出→寄存器 D 端（无逻辑）；反馈为纯导线。

## 3. 守恒论证

- 事务数量：前向打拍不吞事务——`psel_sub` 是 `psel_main` 的延迟副本，主侧发起的每个
  SETUP→ACCESS 序列完整呈现于子侧（无组合裁决逻辑，无状态机丢拍）。
- 相位守恒：`penable_sub` 与 `psel_sub` 同拍寄存，SETUP/ACCESS 两相位宽度不变
  （INV-001 对 mode=0 天然成立：相位 1 拍平移）。
- 数据守恒：完成拍 `pready_main` 即时呈现子侧值，主侧采样到的
  `prdata/pslverr` 与子侧同拍（INV-003 直通成立）。

## 4. PPA 优化点

- 面积：寄存器 `(1+1+AW+3+1+DW+DW/8)` 位；反馈路径无寄存——三模式中最小。
- 时序：割断主侧地址/写数据大扇入（多从译码扇出前先寄存）；**反馈未割断**
  （ASM-004）——多从 PREADY mux 组合路径仍贯穿主侧，fmax 受限场景请用 impl_response。
- 理论下界：割断前向即需 1 级寄存，本实现已达下界。

## 5. 生成方式

SLICE_MODE=0 编译期 generate 分派（`rtl/apb_register_slice.sv`），无独立文件。
