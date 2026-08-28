# CHANGELOG — popcount

格式参照 Keep a Changelog；版本语义 SemVer。

## [0.2.0] — 2026-08-27（Change C2：四实现定稿，candidate）

### Changed
- **四实现定稿**：TREE(默认推荐)/WALLACE/DADDA/LUT（原 impl_lookup、列计数递推 colcmp 淘汰移除）
- WALLACE/DADDA 改为 **Python 生成显式 FA 网表**（gen_schedule.py，W=64 物化），
  零运行时 %// 除法；列计数递推形态被 G6 实证淘汰（W64 面积 10×/时序违例）
- RTL 打平布局：rtl/ 单层（wrapper+tree/lut 直写 popcount.sv；compressed.sv 网表；
  pc_sched_table.svh 调度常量）——不再使用 rtl/impl/ 子目录
- LUT 重构为分级查表（nibble LUT4 → byte 对合并 → 归并树）

### Added
- Python 验证链（随 IP 保留）：verify_schedule.py（调度 506/506）、
  verify_netlist.py（bit-exact 网表 20/20）、gen_schedule.py（SV+Graphviz 架构图生成）
- G6 全量帕累托寻优 run-20260827-03：dadda_w64=271μm²/0.00（FA 显式化 −78% vs 递推、转 MET）；
  tree 124μm²/+0.09 Pareto 支配确认；Graphviz 行交替架构图 W16/W64

### Deprecated/Removed
- impl_column_compress（列计数递推）：双劣实证（面积 ~10×、大 W 时序违例）
- impl_lookup：DC 折叠为 tree 同构，无独立 PPA 价值

## [0.1.0] — 2026-08-27

### Added
- 初版工程包：纯组合 Hamming 权重计数 CBB（SEL-014, A1/P1）
- 契约：cbb.yaml（INPUT_WIDTH[4..256]/CHUNK_W[4..8]/PC-001..002）+ behavior.yaml（INV-001..003）
- 验证：黄金模型仿真（exhaust_w8 全空间穷举/edge 锚点/random3000 固定 seed）、
  fm_shell LEC 实现等价、POPCC_MUT_DIV2MOD 变异注入检出
- 静态基线：VCS 编译矩阵 18 点 + SpyGlass lint_rtl 0E/0W
- PPA：GF CMOS28LP SC9/HVT/tt 真实综合 Sweep（run-20260827-01）
- FuseSoC core：aixsilicon:cbb:popcount:0.1.0（rtl/sim/synth/lint targets）

### Known Issues
- 见 docs/qualification-report.md §2 已知限制（X 输入承诺 / colcmp 大 W 劣势 /
  lookup 与 tree 综合趋同 / PPA E2 单 corner）
