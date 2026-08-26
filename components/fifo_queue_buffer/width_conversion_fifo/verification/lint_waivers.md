# Lint Waiver 记录（G3）

> SpyGlass `lint/lint_rtl` 结果：**0 Fatal / 0 Error**（证据：`evidence/g3_static/moresimple.rpt`）。
> 以下 warning/info 经评估为**参数化方向分支（DIRECTION generate）的预期产物**，非 RTL 缺陷，予以 waiver。

| Rule | 位置 | 说明 | 处置 |
|---|---|---|---|
| W240 | `wide_in_data`/`wide_in_valid`（N2W 下未读） | DIRECTION=N2W 时宽侧输入被 generate 裁剪，端口仍保留用于 W2N | waiver（方向分支预期） |
| W240 | `narrow_out_ready`（N2W 下未读） | 同 N2W 方向，窄侧输出端口未用 | waiver（方向分支预期） |
| W528 | `empty` set but not read | N2W 分支不使用 `empty`（仅 W2N 用） | waiver（方向分支预期） |
| STARC05-1.3.1.3 AsyncResetOtherUse | `rst_n` 用于 RAM 写使能 `.EN` | 异步复位 always 推断 RAM 写使能，标准推断 | waiver（异步复位 RAM 写使能预期） |

## 已修复项（由 SpyGlass 暴露并修复）

- **W415a / InitValUsingNBA（beat_idx 多次赋值）**：N2W 状态块 `beat_idx` 在 push 与 pop 两处
  `<=` 同拍可能冲突 → 已合并为单一 `if (pop) ... else if (push) ...` 赋值，消除多次 NBA。
  （证据：SpyGlass 复跑后 W415a 消失。）

## Waiver 归属

- Owner：rtl-owner（aixsilicon:cbb）
- 范围：`DIRECTION` 参数化方向分支的端口/信号使用差异
- 失效条件：若未来实现改用**双向端口或统一数据路径**（消除 generate 方向裁剪）则需复审
