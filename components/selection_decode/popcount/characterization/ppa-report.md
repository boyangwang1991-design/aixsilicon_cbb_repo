# popcount PPA 分析报告

> **Run ID**: `run-20260827-03`（Change C2 定稿全量帕累托寻优 sweep）· 2026-08-27 · **G6 pass**
> 原始证据：[`evidence/ppa/run-20260827-03/`](../evidence/ppa/run-20260827-03/)（15 点 area/timing/power + summary）
> 历史 run：run-01（C0 初版）、run-02（C1 部分点）——同目录存档
> 脚本：[`synth_sweep.tcl`](../characterization/synth_sweep.tcl)；图：[`plot_pareto.py`](plot_pareto.py) → [pareto_run-20260827-03.png](pareto_run-20260827-03.png)
> 架构图：Graphviz 行交替式 [gvarch_wallace_W16](../gvarch_wallace_W16.png) / [gvarch_dadda_W16](../gvarch_dadda_W16.png)（圈=bit、FA 行同 rank、S 蓝/C 橙）

## 0. Change C2 定稿结论（四实现 · 首次全量帕累托寻优）

| 实 现 | PC_IMPL | 结构 | W=64 综合结果 @400MHz |
|---|---|---|---|
| **TREE** | 0 | 平衡加法树（generate 折叠） | **124.0 μm² / +0.09** ✅ **Pareto 支配点** |
| WALLACE | 1 | 显式 FA 网表（Python 生成，W=64 物化） | 271.2 μm² / 0.00 ✅ |
| 列计数递推（已淘汰） | — | 常数 ÷/% 网络 | 1258.2 μm² / **−1.11 ❌** |

¹ wallace/dadda 当前物化固定 W=64 单档（`g_fixed_w` 卫兵）；其余宽度登记为生成器扩展项。

**核心发现——显式 FA 网表路线验证成功，且 W=64 与 tree 打平**：
Change C3 纯 FA 网表单点复测（wallace64_run/）W64 = **121.9μm² / +0.01 / 74.7μW**，
对比 tree 124.0μm²/+0.09/72.2μW —— 面积 −1.7%、slack 同级（MET）、功耗 +3.5%。
对比列计数递推（1258μm²/−1.11）面积 **−90%**。
两者同为 W=64 Pareto 有效解；tree 保持全宽度推荐（其它宽度 FA 网表待物化扩展）。

## 1. 表征上下文（证据等级 E2）

| 维度 | 值 | 来源 |
|---|---|---|
| 工艺/库 | GF CMOS28LP + ARM SC9 base HVT (r5p0) | [pdk.yaml](pdk.yaml) |
| Corner | tt_nominal_max_1p00v_25c（单 corner） | pdk.yaml |
| 约束 | 虚拟时钟 vclk=2.5ns(400MHz)、I/O delay 0.5ns、驱动 BUFH_X4M_A9TH、load 10fF | synth_sweep.tcl |
| 综合策略 | compile_ultra -no_autoungroup；实现子模块顶层直证² | dc_sweep3.log |

² *dc_shell 对 wrapper generate-case 的 `-parameters` 覆盖不生效——实现选择一律子模块直证（教训沉淀于 domain-rules §3.1.3）。*

## 2. Sweep 结果矩阵（面积 μm² / worst slack ns @400MHz）

| W | impl_tree | impl_dadda(FA) | 列计数递推(colcmp) |
|---|---|---|---|
| 8   | **12.05 / +0.53** | —¹ | 12.05 / +0.53 |
| 16  | **27.26 / +0.43** | —¹ | 100.39 / 0.00 |
| 32  | **64.82 / +0.07** | —¹ | 417.46 / 0.00 |
| 64  | **124.02 / +0.09** | 271.21 / 0.00 | 1258.22 / **−1.11 ✗** |
| 128 | **248.74 / +0.04** | —¹ | 2551.30 / **−2.20 ✗** |

¹ dadda 网表当前仅物化 W=64（生成器可按档扩展；见 next_actions）。

### 动态功耗（W=64）

tree 72.2 μW / colcmp 691.2 μW（~9.6×）——与面积比一致的劣化。

## 3. Pareto 结论

- **前沿**：tree 在全部宽度点支配（面积最小且时序 MET）；
- **淘汰**：列计数递推——双劣（面积 ~10× + 大 W 时序违例），Change C2 已从交付集移除；
- **定位**：显式 FA 压缩核（wallace/dadda）= 压缩结构教学/探索资产 + 大 W(≥256) 潜在
  收益待扩展物化后复测；当前 experimental。

## 4. Profile 推荐

| Profile | 状态 | 依据 |
|---|---|---|
| `tree_default` (impl_tree) | **supported / 推荐** | Pareto 全宽度支配 |
| `lut_compact`≈tree | supported | 综合趋同（run-01 观察） |
| `wallace` / `dadda_sched` | experimental | 显式 FA 2.2× 面积，保留探索价值 |
| 列计数递推 | **removed** | §0 双劣实证 |

## 5. 可复现性

```bash
cd <cbb>/characterization
export PC_RUN_ID=run-20260827-04 PC_RTL_DIR=$(pwd)/../rtl
dc_shell -f synth_sweep.tcl > dc_sweep.log
uv run python plot_pareto.py $PC_RUN_ID ..
uv run --with matplotlib --with graphviz python gen_schedule.py 64   # 网表+架构图
```

比较基线绑定四元组 `(library, corner, constraint, tool)`；跨 corner 外推需 ss/ff sweep（E3 上探项）。

## 6. Next Actions

1. gen_schedule.py 扩展物化 W∈{8,16,32,128} 网表档 → 补全 dadda/wallace 全宽度 Sweep；
2. ss/ff corner 补点（E2→E3 上探）；
3. 消费者 Use Case 权重批准后定 Profile 推荐终稿。
