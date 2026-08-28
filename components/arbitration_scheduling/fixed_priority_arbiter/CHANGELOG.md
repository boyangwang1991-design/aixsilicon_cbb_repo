# Changelog — fixed_priority_arbiter

## [0.1.0] - 2026-08-28

### Added
- 首次物化（ARB-001，A2/P0）：固定优先级仲裁器。
- 参数：`NUM_REQ`(2..64)、`PRIORITY`(LSB/MSB 优先)、`REQ_TYPE`(level/latched)、
  `FAST_GRANT`(组合/寄存授权)、`PC_IMPL`(linear/tree/grouped)。
- 行为契约：授权互斥（INV-001）、优先级语义（INV-002）、无请求→grant=0（INV-003）、
  锁存保持（INV-004）、寄存授权 1 拍延迟（INV-005）。
- 多实现：`impl_linear` / `impl_tree` / `impl_grouped`（同一可观察契约，综合收敛实证）。
- RTL + 就近 SVA（@(posedge clk) 并发断言）；FuseSoC Core（sim/synth/lint target）。
- 验证：G3 静态基线（VCS 编译矩阵 18 点 + 负向 elab + SpyGlass lint 0F/0E）、
  G4 功能仿真（穷举/优先级/边界/随机 2000×N64/等价/锁存/寄存）、G5 配置矩阵 14 配置。
- PPA：DC 综合 sweep（3 实现 × 5 请求数），三实现综合收敛（差异 <3%）。

### Gate 状态
- G0–G6 pass；G7/G8 candidate（Workflow Gate 确认）。

### 已知限制
- FAST_GRANT=1 单独 PPA 表征未做；多 corner STA（当前单 corner tt_1p00v_25c）；消费者 Smoke 待补齐。
