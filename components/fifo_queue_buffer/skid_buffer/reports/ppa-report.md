# PPA Report — skid_buffer（QUE-007, A3, 多实现 profile）

## 上下文（证据等级 E2：真实综合 + 标准单元库）

| 项 | 值 |
|---|---|
| 工艺 / 库 | GF CMOS28LP 28nm + ARM SC9（`sc9_cmos28lp_base_hvt`） |
| corner | `tt_nominal_max_1p00v_25c` |
| 约束 | 400MHz（`create_clock 2.5` 绑定 `clk` 端口） |
| 工具 | `dc_shell`（`compile_ultra -no_autoungroup`） |
| run | `run-20260829-01`（完整报告集 `build/eda/ppa/run-20260829-01/`；指标由 [`characterization/extract_ppa.py`](../characterization/extract_ppa.py) 抽取，可复现不重复综合） |
| 实现 | `impl_forward`（IMPL=0）/ `impl_full`（IMPL=1）/ `BYPASS`（组合直通） |

## 结果（时序主判据：forward/full = **reg→reg 最差 setup slack**；BYPASS = 组合 arrival）

| mode | DATA_W | area(µm²) | regs | worst_slack(ns) | slack_status | io_arrival(ns) | verdict | dyn(µW) | leak(nW) |
|---|---|---|---|---|---|---|---|---|---|
| forward | 8  | 23.52 | 9  | 2.02 | MET | 0.02 | **PASS** | 19.3  | 3.7 |
| forward | 32 | 85.76 | 33 | 2.02 | MET | 0.02 | **PASS** | 67.8  | 10.8 |
| forward | 128| 333.68 | 129| 2.02 | MET | 0.02 | **PASS** | 266.0 | 42.1 |
| full | 8  | 70.90 | 18 | 1.35 | MET | 0.65 | **PASS** | 35.4  | 8.1 |
| full | 32 | 251.90 | 66 | 0.81 | MET | 0.65 | **PASS** | 128.7 | 27.7 |
| full | 128| 975.43 | 258| 0.39 | MET | 0.68 | **PASS** | 500.9 | 107.4 |
| bypass | 32| ~0 (wire) | 0 | —(组合) | MET | 0.02 | **PASS** | n/a | n/a |

## 多实现对比（Pareto）

- **面积**：forward ≈ full 的 **1/3**（W32: 85.8 vs 251.9 µm²；regs 33 vs 66 = DATA_W+1 vs 2×(DATA_W+1)），
  达"简单打拍"面积下界；full 多 SKID 槽 + DATA_W 宽 mux；
- **时序**：forward worst_slack 恒定 2.02ns（无 mux，打拍路径极短）；full 随 `DATA_W` 增大
  slack 下降（W128 最紧 0.39ns，mux 扇出）；两者 400MHz 均 MET；
- **BYPASS**：组合直通被 DC 优化为 wire（面积≈0、arrival 0.02ns），零延迟参考；
- **功耗**：与位宽线性；full 略高于 forward（多槽/mux 翻转）；
- **选择建议**：面积/浅流水 → `forward`；满吞吐 + 短反压路径（深流水背压频繁）→ `full`；
  零延迟旁路 → `BYPASS=1`；
- vs `STR-006 full_register_slice`：本 full 实现即其 skid 变体，面积/时序等价。

## 说明

- IO arrival（组合输出 `reg→out`）仅作参考，不作为时序结论；
- 违规只看 vclk slack 的 VIOLATED（`report_constraint` 的 leakage power slack 属功耗、非时序）；
- 完整原始报告（area/timing_max/io/power/regs）保留在 `build/eda/ppa/run-20260829-01/` 供人查看。
