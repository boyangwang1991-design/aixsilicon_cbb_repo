# Changelog — weighted_rr_arbiter

## [0.1.0] — 2026-08-29

### Added（初始物化，ARB-003）

- 带权轮转仲裁器（Weighted Round-robin Arbiter），抽象粒度 A2（`arbitration_scheduling`）。
- 功能参数：`NUM_REQ` [2..64]、`WEIGHT_WIDTH` [2..16]、`WMODE` {0=quota,1=smooth}、
  `FAST_GRANT` {0,1}、`GRANT_ACK_EN` {0,1}；微架构参数 `PC_IMPL` {0=quota_counter,1=deficit_rotate}。
- 公平语义：
  - **quota（WMODE=0）**：每路独立配额计数器（每轮起点=权重），窗口内授权 ≤ 权重、比例趋近权重、不超发不饿死。
  - **smooth（WMODE=1）**：统一 credit（复位=权重），argmax 选 credit 最大资格路，被选路 credit-1、
    资格路全低于 N 时回补 += 权重（跨轮累计、无负 credit）。
- 就近 SVA：INV-001 授权互斥 / INV-002 quota 窗口守恒 / INV-003 活性（sel_vec 前件）/
  INV-004 smooth 无负 credit / INV-005 寄存 1 拍 / INV-006 ack 锁定。
- 验证：G3 静态基线（VCS 24 编译点 + 负向 elab + SpyGlass lint 0F/0E）、G4 功能仿真
  （WRRA_TB：quota 800 窗口精确 [2:1:1:0]、smooth 比例、跨实现等价、寄存、ack 锁定、随机互斥）。
- 文档：`docs/cbb_spec.md`（规格）、`docs/design.md` + `docs/detail-design/`（架构/详设）、
  `docs/intake.md`（G0）、README。
- FuseSoC Core：`aixsilicon:cbb:weighted_rr_arbiter:0.1.0`（rtl/sim/synth/lint target）。
