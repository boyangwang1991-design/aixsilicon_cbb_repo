# Lint Waiver 记录（G3）— weighted_rr_arbiter

> SpyGlass `lint/lint_rtl` 结果：0 Fatal / 0 Error（证据：`build/eda/evidence/g3_static/`，不入库）。
> 以下 warning/info 经评估为参数化方向/分支的预期产物，非 RTL 缺陷，予以 waiver。

| Rule | 位置 | 说明 | 处置 |
|---|---|---|---|
| SYNTH_5064 | `rtl/weighted_rr_arbiter.sv` 就近 SVA（`assert property`） | 验证期断言在综合（DC/SpyGlass）中忽略，不产生硬件；`$countones()` 仅用于断言 | waiver（验证资产，非可综合逻辑） |
| W340A（parameter 未用分支） | `rtl/weighted_rr_arbiter.sv` generate 分支（quota/smooth/ack/fast_grant 互斥） | WMODE/FAST_GRANT/GRANT_ACK_EN/PC_IMPL 编译期选择，未用分支信号由 generate 默认驱动 0 | waiver（参数化裁剪预期产物） |
| 未用端口/信号 | `grant_ack_i`（GRANT_ACK_EN=0 时）、`clk`（纯组合配置） | 参数化端口按契约保留（ASM-004），未用配置不驱动 | waiver（契约端口固定） |

## Waiver 归属

- Owner：rtl-owner（aixsilicon:cbb）
- 范围：SVA 断言（验证资产）、参数化 generate 分支、契约固定端口
- 失效条件：SVA 需综合（不应发生）；改用统一数据路径/去除 generate 裁剪后复审
