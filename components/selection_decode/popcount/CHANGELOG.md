# CHANGELOG — popcount

格式参照 Keep a Changelog；版本语义 SemVer。

## [0.1.0] — 2026-08-27（candidate，待 Workflow Gate 发布确认）

### Added
- 初版工程包：纯组合 Hamming 权重计数 CBB（SEL-014, A1/P1）
- 三微架构实现：impl_tree（默认推荐）/ impl_column_compress（experimental）/ impl_lookup
- 契约：cbb.yaml（INPUT_WIDTH[4..256]/CHUNK_W[4..8]/PC-001..002）+ behavior.yaml（INV-001..003）
- 验证：黄金模型仿真（exhaust_w8 全空间穷举/edge 锚点/random3000 固定 seed）、
  fm_shell LEC 实现等价 ×2、POPCC_MUT_DIV2MOD 变异注入检出
- 静态基线：VCS 编译矩阵 18 点 + SpyGlass lint_rtl 0E/0W
- PPA：GF CMOS28LP SC9/HVT/tt 真实综合 Sweep 15 点（run-20260827-01）+
  Pareto 结论（tree_default 推荐，fmax_opt 因列计数递推形态降级 experimental）
- FuseSoC core：aixsilicon:cbb:popcount:0.1.0（rtl/sim/synth/lint targets）

### Known Issues
- 见 docs/qualification-report.md §2 已知限制（X 输入承诺 / colcmp 大 W 劣势 /
  lookup 与 tree 综合趋同 / PPA E2 单 corner）
