# Qualification Report（G7 候选）— sync_fifo

> 状态：`qualification_candidate`（只有 Workflow Gate G7/G8 可确认 `qualified`/`released`）。
> 执行深度：standard（新 CBB，G0–G6 证据已物化；G5/G7 待 Workflow Gate 状态确认）。
> 审查基准：cbb-development-suite qualify-cbb-release。

## 1. 支持矩阵（与真实验证矩阵一致）

| 参数/配置 | 支持值 | 验证状态 |
|---|---|---|
| `DATA_W` | [1, 1024]（代表点 1/8/32/64/128/1024） | 编译矩阵 + 功能仿真（w1/32） |
| `DEPTH` | [2, 256]（代表点 2/3/16/32/129/256） | 编译矩阵 + 功能仿真（d2/3/16/129） |
| `IMPL` | {0=register(supported), 1=shift(experimental)} | 4 模式功能仿真 + SVA + G6 PPA（shift 实测不占优） |
| `OUTPUT_REG` | {0=comb, 1=reg} | 4 模式功能仿真 + SVA（comb/outreg 场景）+ G6 PPA |
| 非法参数 | DATA_W=0/1025、DEPTH=1/257、OUTPUT_REG=2、IMPL=2 | elaboration `$error` 拦截（G3 负向） |

## 2. Gate 证据完整性

| Gate | 结果 | 证据 | 说明 |
|---|---|---|---|
| G0 | pass | `docs/intake.md` | 边界/查重（QUE-001 已登记物化）/依赖解析/SRAM non_goal |
| G1 | pass | `cbb.yaml`+`behavior.yaml`+`docs/cbb_spec.md`+`trace/rtm.yaml` | check（含 --strict）PASS + config-gen（1/19/13/4）+ 规格确认门 |
| G2 | pass | `docs/design.md`+`profiles.yaml`+`docs/detail-design/{register,shift}.md` | 多实现/Profile/时钟复位 + 详设确认门 |
| G3 | pass | `build/eda/evidence/g3_static/param_matrix.txt` + `negative_*.txt` | VCS compile 矩阵 18 点 + 负向 PC-001..006 |
| G4 | pass | `build/eda/evidence/g4_functional/functional_sim.txt` | VCS 功能仿真 9 配置 PASS + SVA 无失败 |
| G5 | candidate | `verification/configs/`（config-gen 生成） | 覆盖待 Workflow Gate 确认（当前全 Gate 状态见 reports/quality/gates/） |
| G6 | pass | `characterization/pdk.yaml` + `build/eda/ppa/run-20260903-01/` + `reports/ppa-report.md` | DC 8 点 E2 全 MET@400MHz（run-20260903-01，见 §3/§4） |
| G7 | candidate | 本报告 | 支持矩阵/限制/Waiver |
| G8 | candidate | `release/manifest.yaml` | SemVer/SBOM/Hash |

## 3. PPA 结论（G6，run-20260903-01）

| 实现 | DEPTH | area(µm²) | worst slack(ns)@400MHz | dyn(µW) |
|---|---|---|---|---|
| register×comb（默认） | 8 / 32 | 957.6 / 3747.4 | 0.55 / 0.00 | 437.6 / 1621.5 |
| register×reg | 8 / 32 | 1071.1 / 3865.0 | 0.10 / 0.02 | 503.5 / 1685.4 |
| shift×comb | 8 / 32 | 1053.4 / 4105.1 | 0.03 / 0.02 | 482.4 / 1821.4 |
| shift×reg | 8 / 32 | 1040.7 / 4095.0 | 0.03 / 0.00 | 487.8 / 1850.9 |

- **register×comb 为 d8/d32 Pareto 支配点**（面积最小 + slack 最优）；shift 每槽
  "保持/左移" mux 组合开销 > 省读 mux，实测面积/功耗反超 register（详见
  [`reports/ppa-report.md`](../reports/ppa-report.md)）→ shift profiles 降 `experimental`。

## 4. Waiver 清单

| Waiver | Owner | 范围 | 风险 | 替代证据 | 失效条件 |
|---|---|---|---|---|---|
| 功耗无 SAIF | ppa-owner | 动态功耗（默认概率传播估计） | 低 | 面积/时序已 E2 门级；功耗仅相对趋势 | 真实 activity/SAIF 场景补测 |
| Lint Wxxx | rtl-owner | 参数化 generate 分支/未用端口 | 低 | VCS 编译/仿真/SVA 通过 | SpyGlass lint_rtl 落地后按 `lint_waivers.md` 复审 |

## 5. 成熟度判定

- **候选成熟度：E2（Implemented + Verified + Characterized）**——G0–G4 + G6 证据 pass
  （编译/负向/功能仿真 + SVA + DC 门级综合 E2）；
- 未达 E3（Stable）的缺口：G5 状态确认、≥2 独立消费者、Consumer Smoke、Lint 落地、
  ss/ff corner 与 DATA_W/DEPTH 外推域门级数据。

## 6. 已知限制（Known Limitations）

1. `DEPTH` 上界 256（PC-004）；shift 建议 `DEPTH<=32`（PPA 建议，非 error，profiles known_limits）
2. `IMPL=shift` 为移位存储：pop/refill 全体左移使能扇出随 DEPTH 增长（深时功耗/拥塞劣化）；
   **实测 d8/d32 面积/功耗均不优于 register**（run-20260903-01）→ 推荐 register 家族
3. 单时钟域、低有效异步复位；无 FWFT/CDC/override/flush/almost 水位（behavior.yaml non_goals）
4. `IMPL=sram` 未实现：依赖 A0 wrapper `TEC-015 sram_macro_wrapper`（planned），需经用户同意委派
5. PPA 已表征区 DATA_W=32×DEPTH{8,32}（tt/400MHz）；DATA_W>32、DEPTH>32、ss/ff corner
   属外推域（未宣称）

## 6. Release 建议（candidate）

- SemVer：`0.1.0`
- FuseSoC Core：`aixsilicon:cbb:sync_fifo:0.1.0`
- 消费者 Smoke：本次未做（依赖真实下游；建议后续以 IP/子系统为消费者联调）
- SBOM 依赖：无运行时子 CBB（`implementations[].dependencies[]` 为空）
- 开源发布清理：无需 PDK/商业 EDA/内部路径

## 7. 嵌套依赖 Qualification（若有子 CBB）

| 子 CBB | VLNV | 自身 Gate | 联调结论 |
|---|---|---|---|
| （无运行时依赖） | — | — | — |

> sram 宏存储方向依赖未实现 A0 wrapper（TEC-015）——登记 non_goals（intake §3 / run_log），
> 待用户同意委派后扩展，本报告不覆盖。
