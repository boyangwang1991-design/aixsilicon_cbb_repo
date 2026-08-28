# Qualification Report（G7 候选）— parity_gen_check

> 状态：`qualification_candidate`（只有 Workflow Gate G7/G8 可确认 `qualified`/`released`）。
> 执行深度：<fast / standard / qualification>。审查基准：cbb-development-suite qualify-cbb-release。

## 1. 支持矩阵（与真实验证矩阵一致）

| 参数/配置 | 支持值 | 验证状态 |
|---|---|---|
| `<PARAM_A>` | `<合法域>` | <边界抽样 / 已验证（G4 仿真+SVA）> |
| `<PARAM_B>` | `< … >` | <代表点验证> |
| 非法参数 | <非法组合> | elaboration `$error` 拦截（G3 负向） |

## 2. Gate 证据完整性

| Gate | 结果 | 证据 | 说明 |
|---|---|---|---|
| G0 | pass | `docs/intake.md` | 边界/查重/依赖解析 |
| G1 | pass | `cbb.yaml`+`behavior.yaml`+`trace/rtm.yaml` | check PASS |
| G2 | pass | `docs/design.md`+`profiles.yaml` | 多实现/Profile/时钟复位 |
| G3 | pass | `evidence/g3_static/` | VCS compile/elab + Lint + 负向 |
| G4 | pass | `evidence/g4_functional/` | 仿真+SVA+变异 |
| G5 | pass | `verification/configs/` | mandatory/boundary/pairwise/negative |
| G6 | <pass/blocked> | `characterization/plan.yaml` | `OPTIONAL_UNAVAILABLE(E0)` 或实体表征 |
| G7 | candidate | 本报告 | 支持矩阵/限制/Waiver |
| G8 | candidate | `release/manifest.yaml` | SemVer/SBOM/Hash |

## 3. Waiver 清单

| Waiver | Owner | 范围 | 风险 | 替代证据 | 失效条件 |
|---|---|---|---|---|---|
| <G6 PPA 缺失> | ppa-owner | 面积/时序/功耗门级 | 低-中 | RTL 结构定性（E0） | 提供标准单元库后补 Sweep+Pareto |
| <Lint Wxxx> | rtl-owner | <参数化分支/未用端口> | 低 | 编译/仿真通过 | <去除 generate 裁剪后复审> |

## 4. 成熟度判定

- **候选成熟度：<E1/E2%E2>**；依据：G1–G5 证据 pass（非目录存在）；
- 未达下一级（<E3/Stable>）的缺口：PPA 门级证据 / ≥2 独立消费者 / Golden 全链 / Consumer Smoke。

## 5. 已知限制（Known Limitations）

1. <限制 1（含对应约束 ID，如 PC-005 DEPTH>=RATIO）>
2. <限制 2（如 仅整数比、单时钟域）>
3. <…>

## 6. Release 建议（candidate）

- SemVer：`<0.1.0>`
- FuseSoC Core：`aixsilicon:cbb:<cbb_name>:<version>`
- 消费者 Smoke：<已执行（列出消费者+版本锁定） / 本次未做（依赖真实下游）>
- SBOM 依赖：<嵌套子 CBB 列表 VLNV+pinned；无则写 "无运行时依赖">
- 开源发布清理：<无需 PDK/商业 EDA/内部路径 / 已清理>

## 7. 嵌套依赖 Qualification（若有子 CBB）

| 子 CBB | VLNV | 自身 Gate | 联调结论 |
|---|---|---|---|
| <sub_cbb> | `aixsilicon:cbb:<sub>:<version>` | <G0–G…> | <G4 联调通过 / 子未达者高位风险> |