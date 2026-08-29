# Changelog — round_robin_arbiter

## [0.1.0] - 2026-08-29

### Added
- 首次物化（ARB-002，A2/P0）：轮转（Round-robin）仲裁器。
- 参数：`NUM_REQ`(2..64)、`REQ_TYPE`(level/latched)、`FAST_GRANT`(组合/寄存授权)、
  `PC_IMPL`(mask/rotate+priority/pointer)、`GRANT_ACK_EN`(每拍决策/ack 锁定)。
- 行为契约：授权互斥（INV-001）、轮转公平（INV-002）、无请求→grant=0（INV-003）、
  锁存保持（INV-004）、寄存授权 1 拍延迟（INV-005）、ack 锁定（INV-006）。
- 多实现：`impl_mask` / `impl_rotate_prio` / `impl_pointer`（同一可观察契约，综合收敛实证）。
- RTL + 就近 SVA（@(posedge clk) 并发断言）；FuseSoC Core（sim/synth/lint target）。
- 验证：G3 静态基线（VCS 编译矩阵 18 点 + 负向 elab + SpyGlass lint 0F/0E）、
  G4 功能仿真（穷举/轮转序/边界/随机 2000×N64/等价/锁存/寄存/ack 锁定）、
  G5 配置矩阵 35 配置、变异测试（互斥破坏 → SVA 20078 次断言失败检测）。

### Gate 状态
- G0–G5 pass（candidate）；G6 待 DC 综合实证；G7/G8 待 Workflow Gate 确认。

### 已知限制
- 非目标：WRR/Deficit/age（ARB-003/004/005）、multi-grant（ARB-007）、hierarchical（ARB-008）。
- `REQ_TYPE=1` 或 `GRANT_ACK_EN=1` 时消费方必须在授权保持期间应答 `grant_ack_i`（ASM-002）。
- PPA 表征（G6）尚未执行（本版本为 G0–G5 物化；G6 计划用 CMOS28LP DC 真实综合）。
