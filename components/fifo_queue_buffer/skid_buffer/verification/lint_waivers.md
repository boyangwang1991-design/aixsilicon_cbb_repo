# Lint Waiver 记录（G3）— skid_buffer

> SpyGlass `lint/lint_rtl` 结果：0 Fatal / 0 Error（证据：`build/eda/evidence/g3_static/`，不入库）。
> 以下 warning/info 经评估为参数化结构/握手控制信号的预期产物，非 RTL 缺陷，予以 waiver。

| Rule | 位置 | 说明 | 处置 |
|---|---|---|---|
| （如 W465: multi-driver 检查通过；参数 generate $error 分支） | `g_bad_data_w` | 参数检查 generate 分支仅在非法参数时 $error，属预期负向路径 | waiver（参数化保护） |
| （如 W310: 组合输出 `in_ready`） | `assign in_ready` | 握手反压信号为组合输出（valid-ready 协议标准），非缺陷 | waiver（协议语义） |

## Waiver 归属

- Owner：rtl-owner（aixsilicon:cbb）
- 范围：参数化分支（`g_bad_data_w`）、组合握手输出（`in_ready`）
- 失效条件：改用统一数据路径/去除参数保护后复审
