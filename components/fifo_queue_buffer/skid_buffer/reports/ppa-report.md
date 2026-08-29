# PPA Report — skid_buffer（QUE-007, A3）

## 上下文（证据等级 E2：真实综合 + 标准单元库）

| 项 | 值 |
|---|---|
| 工艺 / 库 | GF CMOS28LP 28nm + ARM SC9（`sc9_cmos28lp_base_hvt`） |
| corner | `tt_nominal_max_1p00v_25c` |
| 约束 | 400MHz（`create_clock 2.5`，**绑定 `clk` 端口**——时序模块必须，否则 FF 无 setup 约束） |
| 工具 | `dc_shell`（`compile_ultra -no_autoungroup`） |
| run | `run-20260828-07`（完整报告集 `build/eda/ppa/run-20260828-07/`；指标由 [`characterization/extract_ppa.py`](../characterization/extract_ppa.py) 抽取，可复现不重复综合） |
| 实现 | `impl_output_registered`（OUT 寄存 + SKID 槽，bubble-free） |

## 结果（时序主判据 = **reg→reg 最差 setup slack**；非纯组合构件不用 arrival 判时序）

| DATA_W | area(µm²) | regs | worst_slack(ns) | slack_status | io_arrival(ns) | verdict | dyn(µW) | leak(nW) |
|---|---|---|---|---|---|---|---|---|
| 8  | 70.90 | 18 | 1.35 | MET | 0.65 | **PASS** | 35.4  | 8.1 |
| 32 | 251.90 | 66 | 0.81 | MET | 0.65 | **PASS** | 128.7 | 27.7 |
| 128| 975.43 | 258 | 0.39 | MET | 0.68 | **PASS** | 500.9 | 107.4 |

## 分析

- **时序（主判据，2026-08-29 修正）**：全部配置 **reg→reg 最差 setup slack 为 MET 且为正**
  （W128 最紧 0.39ns，400MHz/2.5ns 收敛）；随 `DATA_W` 增大 slack 减小（数据 mux 扇出
  增大），符合详设"数据/ready 关键路径 ≤1 级组合"；W128 若需更高主频（>500MHz）应评估
  拆分或加流水级（属 QUE-008 范畴）；
- **IO（参考）**：组合输出（`reg→out in_ready`）arrival 0.65–0.68ns，仅作 IO 延迟参考，
  **不作为时序结论**（`report_constraint` 的 leakage power slack 属功耗、非时序）；
- **面积**：随 `DATA_W` 线性（≈2×DATA_W FF + DATA_W 宽 2:1 mux），达保序打拍面积下界；
- **功耗**：与位宽线性；空闲（无输入）时 OUT/SKID 数据寄存器不更新，翻转功耗低；
  数据路径 ICG 为 Profile 层扩展点（未引入，见 `docs/detail-design/skid.md` §4.3）；
- **Pareto**：vs `forward_register_slice`——多 1 槽面积换满吞吐无气泡 + 短 ready 路径；
  vs `full_register_slice`——同面积/时序（skid 为 full 的 skid 变体）。
