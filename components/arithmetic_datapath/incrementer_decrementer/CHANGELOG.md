# Changelog

## [0.1.0] - 2026-08-29

### Added
- ARI-001 incrementer_decrementer 首次物化（A1/P0，Counter 专用 ±1 运算器）。
- 契约：`cbb.yaml` / `behavior.yaml` / `profiles.yaml`（PC-001..004 约束、INV-001..003、ASM-001..004）。
- 文档：Intake（G0）、规格（G1）、设计（G2）、详设 ripple/segmented。
- RTL：`rtl/incrementer_decrementer.sv`（wrapper + ripple 半加器进位链 + segmented 分段进位）。
- FuseSoC Core：`fusesoc/aixsilicon_cbb_incrementer_decrementer.core`。
- 验证：G3 静态基线（VCS 16 矩阵 PASS + 负向拦截 + SpyGlass lint 0F/0E）、
  G4 功能（穷举 256×3 + 边界 + 随机 4000×3 + 等价 + 变异 256/256 检测）、
  G5 配置集（mandatory/boundary/pairwise/negative，check --strict 通过）。
- G6：pdk-scan（PDK_READY）+ DC 综合 sweep（两实现 × W{8,16,32,64} × SEG{4,8}）。
- CG（Carry/Data Gating）PPA 优化：`CG_EN` 参数（0=off/1=on 自动 gate，无需 ICG），
  hold 模式进位链零翻转 + XOR 直通；DC 面积/功耗对比（run-20260829-03）——
  ripple area -1.6%/leak -30%/dyn -6%，segmented area -0.2%/leak -9%/dyn -2.5%；
  CG0/1 输出等价（G4 证明）。
