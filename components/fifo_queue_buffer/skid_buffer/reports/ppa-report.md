# PPA Report — skid_buffer（QUE-007, A3）

## 上下文（绑定证据等级 E2：真实综合 + 标准单元库）

| 项 | 值 |
|---|---|
| 工艺 / 库 | GF CMOS28LP 28nm + ARM SC9（`sc9_cmos28lp_base_hvt`） |
| corner | `tt_nominal_max_1p00v_25c` |
| 约束 | 400MHz（`create_clock 2.5`），`constraints/skid_buffer.sdc` |
| 工具 | `dc_shell`（`compile_ultra -no_autoungroup`） |
| run | `run-20260828-01`（证据：`build/eda/ppa/run-20260828-01/skid_w*_summary.txt`） |
| 实现 | `impl_output_registered`（OUT 寄存 + SKID 槽，bubble-free） |

## 结果

| DATA_W | area (µm²) | arrival (ns) | dyn power (µW) | leak (nW) |
|---|---|---|---|---|
| 8  | 70.90 | 0.74 | 4.44  | 7.57 |
| 32 | 251.90 | 0.79 | 16.07 | 26.86 |
| 128| 975.43 | 0.76 | 61.89 | 104.50 |

## 分析

- **面积**：随 `DATA_W` 线性增长（≈2×DATA_W FF + DATA_W 宽 2:1 mux），与详设"保序打拍
  面积下界 ≥2×DATA_W FF"一致；DATA_W=32 时 ~252 µm²；
- **时序**：数据关键路径 arrival ≈0.76–0.79ns，在 400MHz（2.5ns）约束下 slack 充裕
  （MET），符合详设"数据/ready 关键路径 ≤1 级组合"；主频上界远高于 600MHz 上限预期；
- **功耗**：与位宽线性；空闲（无输入）时 OUT/SKID 数据寄存器不更新，翻转功耗低；
  数据路径 ICG 为 Profile 层扩展点（未引入，见 `docs/detail-design/skid.md` §4.3）；
- **Pareto**：vs `forward_register_slice`——多 1 槽面积换满吞吐无气泡 + 短 ready 路径；
  vs `full_register_slice`——同面积/时序（skid 为 full 的 skid 变体）。
