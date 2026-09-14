# accumulator PPA 表征报告（G6）

> 证据等级：**PPA-E1**（Generic：固定内部库 sc9_cmos28lp_base_hvt tt_1p00v_25c + dc_shell 综合，可复现）。
> 原始数据：`build/eda/ppa/run-20260914-01/`（12 点 sweep，每个点含 area/timing/power rpt + summary）。
> 不预设工艺/频率承诺；结果为固定库与约束下的代表点，非跨工艺泛化。

## 1. 实验上下文（可复现）

| 项 | 值 |
|---|---|
| RTL hash | `accumulator.sv`（cbb.yaml `1d8e5386` 基线） |
| 工艺库 | CMOS28NM `sc9_cmos28lp_base_hvt`（tt_nominal_max_1p00v_25c，.db） |
| 综合工具 | Synopsys DC `V-2023.12-SP3`（dc_shell） |
| 时钟 | create_clock 2.5ns（400MHz）；input/output delay 0.5ns；load 0.01 |
| 综合选项 | `compile_ultra -no_autoungroup`；SVA/assert 不综合（VER-708 忽略） |
| 约束文件 | `constraints/accumulator.sdc` |
| run id | `run-20260914-01` |

## 2. 代表点结果（12 点）

| 配置 (IW/AW/SGN/OP/OVF/LD/ST/ISO) | Area(μm²) | A→A slack(ns) | Dyn(μW) | Leak(nW) |
|---|---|---|---|---|
| 8/16 sgn ADD WRAP LD ST | 123.1 | 0.00 | 6.33 | 18.6 |
| **16/32 sgn ADD WRAP LD ST（默认）** | **260.0** | **0.00** | **17.65** | **35.4** |
| 16/32 sgn ADD_SUB WRAP LD ST | 299.6 | 0.00 | 33.30 | 49.0 |
| 16/32 sgn ADD_SUB SAT LD ST | 306.3 | 0.00 | 32.43 | 49.2 |
| 16/32 uns ADD WRAP LD ST | 222.4 | 0.00 | 11.65 | 27.8 |
| 16/32 sgn ADD WRAP no-LD ST | 245.8 | 0.00 | 15.69 | 36.7 |
| 16/32 sgn ADD WRAP LD no-ST | 203.8 | 0.00 | 10.70 | 24.0 |
| 16/32 sgn ADD_SUB WRAP LD ST **ISO=1** | 304.9 | 0.00 | **24.86** | 48.9 |
| 16/64 sgn ADD WRAP LD ST | 523.9 | 0.00 | 36.08 | 69.1 |
| 16/128 sgn ADD WRAP LD ST | 1053.9 | 0.00 | 75.83 | 137.2 |
| 32/64 sgn ADD WRAP LD ST | 524.0 | 0.00 | 35.16 | 68.5 |
| 32/32 sgn ADD_SUB SAT LD ST | 319.3 | 0.00 | 34.69 | 53.0 |

> A→A slack=0.00：A→A 反馈路径为关键路径（arrival≈2.0ns），达到 400MHz 约束边界；
> data→reg 路径 slack≈1.1~1.2ns（次关键）。无 reg→out/未约束路径未达边界（report_timing 已验证）。

## 3. 观察与趋势

- **位宽**：面积随 ACC_WIDTH 近似线性（16/32:260 → 16/64:524 → 16/128:1054）；功耗同步增长。
- **OP_MODE**：ADD_SUB 比 ADD_ONLY 约 +15% 面积（299 vs 260），功耗 +89%（ADD_SUB 双运算逻辑翻转）。
- **SATURATE**：比 WRAP 约 +2% 面积（306 vs 299），功耗相近。
- **unsigned**：比 signed 小约 14%（222 vs 260）——符号扩展/判定逻辑简化。
- **STATUS_EN=0**：面积最小（204），省去 sticky/事件逻辑约 -22%。
- **OPERAND_ISOLATION=1**：面积 +2%（304.9 vs 299.6）但**动态功耗 -25%**（24.86 vs 33.30 μW）——隔离在低活动率场景有效，满吞吐下 MUX 面积略增（调研 §7.2 结论验证）。
- **LOAD_EN=0**：面积 -5%（245.8 vs 260），移除装载旁路。

## 4. Pareto 与推荐

按 (area, slack, power) 多目标：

| Profile | 推荐 | 依据 |
|---|---|---|
| prof_default | 16/32 ADD WRAP LD ST | 通用基线，功能最全，260μm²/400MHz |
| prof_area_opt | 8/16 ADD WRAP LD ST | 最小面积 123μm²（窄位宽场景） |
| prof_power_opt | 16/32 ADD_SUB WRAP LD ST ISO=1 | 隔离降动态功耗 25%（低活动率） |
| prof_saturating | 16/32 ADD_SUB SAT LD ST | 饱和保护，+2% 面积 |
| prof_nco | 16/32 uns ADD WRAP LD no-ST | unsigned 小面积、无状态输出 |

> 推荐经 Architect + PPA Owner 复核；PPA-E1 等级仅用于趋势与选型，不用于跨工艺 Catalog 推荐。

## 5. 证据位置

- 原始 rpt：`build/eda/ppa/run-20260914-01/acc_<tag>_{area,timing,power}.rpt`（不入库）
- summary：`build/eda/ppa/run-20260914-01/acc_<tag>_summary.txt`（不入库）
- 本报告为可提交归一化摘要（`reports/ppa-report.md`）
- 复现：`IDE_CBB_ROOT=<cbb_root> IDE_RUN_ID=run-<id> IDE_RTL_DIR=<cbb_root>/rtl dc_shell -f characterization/synth_sweep.tcl`
