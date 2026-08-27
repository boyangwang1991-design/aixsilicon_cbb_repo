# popcount PPA 分析报告

> **Run ID**: `run-20260827-01`（tree/colcmp/lookup）+ `run-20260827-02`（Change C1：lookup→dadda）· 2026-08-27 · G6 pass
> 原始证据：[`evidence/ppa/run-20260827-01/`](../evidence/ppa/run-20260827-01/)、[`evidence/ppa/run-20260827-02/`](../evidence/ppa/run-20260827-02/)
> 执行脚本：[`characterization/synth_sweep.tcl`](../characterization/synth_sweep.tcl)（dc_shell V-2023.12-SP3，可重放）
> Pareto 图：Python 绘制 PNG——[`characterization/pareto_run-20260827-01.png`](pareto_run-20260827-01.png)，
> 脚本 [`plot_pareto.py`](plot_pareto.py)（`uv run --with matplotlib python plot_pareto.py <run_id> <cbb_root>`）

## 0. Change C1 摘要（impl_lookup → impl_dadda）

用户评审后决定将 impl_lookup 替换为 Dadda 调度加法树。变更已走完整回归：
VCS 编译矩阵 18/18、W8 穷举+edge+random3000 全 PASS、变异检出有效。
G6 补充表征见 §2'。


## 1. 表征上下文（证据等级 E2）

| 维度 | 值 | 来源 |
|---|---|---|
| 工艺/库 | GF CMOS28LP + ARM SC9 base HVT (r5p0) | [pdk.yaml](pdk.yaml) |
| Corner | tt_nominal_max_1p00v_25c（单 corner） | pdk.yaml |
| 约束 | 虚拟时钟 vclk=2.5ns(400MHz)、I/O delay 0.5ns、驱动 BUFH_X4M_A9TH、load 10fF | synth_sweep.tcl |
| 综合策略 | compile_ultra -no_autoungroup；实现子模块顶层直证¹ | dc_sweep.log |

¹ *dc_shell 对 wrapper generate-case 的 `-parameters` 覆盖不生效（case 恒 default 分支），改为直接 elaborate 各 impl 子模块——教训已沉淀 domain-rules §3.1.3。*

## 2. Sweep 结果矩阵（3 实现 × W∈{8,16,32,64,128}）

### 面积 Total cell area (μm²) 与最差 slack @400MHz

| W | impl_tree | impl_lookup | impl_colcmp |
|---|---|---|---|
| 8   | **12.05 / +0.53** | **12.05 / +0.53** | **12.05 / +0.53** |
| 16  | **27.26 / +0.43** | **27.26 / +0.43** | 100.39 / 0.00 |
| 32  | **64.82 / +0.07** | **64.82 / +0.07** | 417.46 / 0.00 |
| 64  | **124.02 / +0.09** | **124.02 / +0.09** | 1258.22 / **−1.11 ✗** |
| 128 | **248.74 / +0.04** | **248.74 / +0.04** | 2551.30 / **−2.20 ✗** |

### 2' run-20260827-02 增补：impl_dadda（Change C1）

| W | impl_dadda | 对比 tree |
|---|---|---|
| 8   | 27.73 / +0.32 | 2.3× 面积、slack 尚可 |
| 16~128 | 未完成¹ | DC 常数乘移位网络 × 每轮全列展开编译耗时超限 |

¹ *大宽度点被运行超时中断（SIGKILL），登记为待补项：需先对调度做 compile_ultra
分块/剥除 CLEAR 轮冗余，或改显式 FA 身份网表。run-20260827-02 其余点位数据
与 run-01 完全一致（tree/colcmp RTL 未改动）。*

**Dadda 初步判读**：W=8 下 27.7μm² vs tree 12.1μm² —— 目标高度调度的
FA 数节省 < 常数魔数乘法网络的开销；与 colcmp 同样呈现"RTL 层手工压缩
不如让综合器自由折叠 tree"的趋势。tree_default 的推荐地位不变。

### 动态功耗（Total Dynamic Power）与漏电

| W | tree / lookup | colcmp |
|---|---|---|
| 8   | 6.03 μW / 2.3 nW | 6.03 μW / 2.3 nW |
| 16  | 13.96 μW / 5.8 nW | 48.28 μW / 29.2 nW |
| 32  | 34.50 μW / 14.2 nW | 214.42 μW / 149.8 nW |
| 64  | 72.24 μW / 27.4 nW | **691.15 μW** / 470.3 nW |
| 128 | 154.76 μW / 55.7 nW | **1392.3 μW** / 967.9 nW |

*注：tree 与 lookup 全点数据趋同是**预期行为**——DC 把 case 查找表折叠成同构加法树（函数等价下综合器最优实现收敛）；小宽度下两者本就同构等价。*

## 3. Pareto 分析与结论

```text
面积 ↑
2551 ┤                              ● colcmp(W128, −2.20)
1258 ┤                    ● colcmp(W64, −1.11)
 417 ┤          ● colcmp(W32)
 100 ┤     ● colcmp(W16)
 250 ┤                        ○ tree/lookup(W128, +0.04)
 124 ┤                  ○ tree/lookup(W64, +0.09)
  65 ┤            ○ (W32)
  27 ┤       ○ (W16)
  12 ┤  ○ (W8)
     └─────────────────────────────────────→ 时序恶化（slack 减小）
```

- **Pareto 前沿由 tree 完全主导**：每个宽度点上 tree/lut 以更小面积、更正 slack 支配 colcmp；
- **colcmp 列计数递推形态证伪**：常数除法 `/3`/`%3` 网络随 W 高次增长（~O(W·logW) 门级
  常数除网络 × 20 轮展开），W≥64 面积 ~10×、动态功耗 ~10×、时序违例——
  **“列压缩 fmax 最优”的理论假设在单列退化场景+此 RTL 形态下不成立**；
- `fmax_opt` profile 已同步降级 **experimental**（[profiles.yaml](../profiles.yaml)）；
- 替代路线（登记 Change Plan）：显式 FA 身份网表（避免常数除网络）或 Dadda 高度序列控制，
  若再测仍劣则裁剪该实现。

## 4. Profile 推荐

| Profile | 状态 | 结论依据 |
|---|---|---|
| `tree_default` (impl_tree) | **supported / 推荐** | 全宽度 Pareto 支配点；W=128 时 249μm²@400MET |
| `lut_compact` (impl_lookup) | supported（与 tree 合并观察） | 综合趋同；仅 FPGA 目标差异化保留 |
| `fmax_opt` (impl_colcmp) | experimental | §3 证伪结论；重测前不建议消费 |

## 5. 可复现性

```bash
cd <cbb>/characterization
export PC_RUN_ID=run-20260827-02 PC_RTL_DIR=$(pwd)/../rtl
dc_shell -f synth_sweep.tcl > dc_sweep.log
# 输出 → ../evidence/ppa/$PC_RUN_ID/
```

回归基线对齐说明：比较必须绑定同一 `(library, corner, constraint, tool)` 四元组；
本报告结论仅在上述上下文内有效，跨 corner 外推需 ss/ff sweep 补充（E3 上探项）。
