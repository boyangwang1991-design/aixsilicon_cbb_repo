# apb_register_slice 资格评估报告（G7）

状态：`qualification_candidate`。资产成熟度：`E2`（Implemented + Verified + Characterized）。
评估日期：2026-09-11。评估依据：G0–G6 实测证据（见门禁证据表）。

## 支持矩阵

| 参数 | 已测范围 / 采样点 | 状态 |
|---|---|---|
| ADDR_WIDTH | 8..32；采样 {8, 16, 32}（G3 编译矩阵 9 AW×DW 点 + G6 综合 3 点） | supported |
| DATA_WIDTH | 8..64；采样 {8, 32, 64}（同上） | supported |
| SLICE_MODE | {0, 1, 2} 全覆盖（G4 功能 + G6 综合 27 点） | supported |
| RESP_STAGES | {1, 2} 全覆盖（G4 tc_resp_delay + G6 full_rs1/rs2） | supported |
| 集合外组合 | 未测组合默认 `experimental`（domain-rules §4），可通过 G3 参数矩阵按需补测 | experimental |

- 随机验证 seed：`A85_2026_0911`（`process::self.srandom`，300 事务可重放）。
- 变异检出：610 次（`PROP_ARS_ALIGN_003`，mutant 编译期注入，checker 有效性证明）。

## 门禁证据

| 门禁 | 结果 | 证据 |
|---|---|---|
| G0 | pass | [docs/intake.md](../docs/intake.md)（BUS-003 物化，A3/P1） |
| G1 | pass | [docs/cbb_spec.md](../docs/cbb_spec.md) + `check --phase specify --strict` PASS |
| G2 | pass | [docs/design.md](../docs/design.md) + detail-design/ |
| G3 | pass | `build/eda/evidence/g3_static/compile.txt`（54 参数点 + 负向拦截 + lint 0F/0E） |
| G4 | pass | `build/eda/evidence/g4_functional/functional_sim.txt` + `mutation_sim.txt` |
| G5 | pass | `verification/configs/manifest.yaml`（4 集合 37 配置，RTM 闭环） |
| G6 | pass | [reports/ppa-report.md](ppa-report.md)（PPA-E2，run-20260911-032845-01） |
| G7 | pass | 本报告（消费者 Smoke 复跑 G3/G4 全 PASS） |
| G8 | not_applicable | 发布另行走 Release 流程（本报告不构成发布） |

## 消费者 Smoke（G7，2026-09-11）

- 从 CBB 根以默认参数复跑 `run_static_checks.sh` / `run_functional_sim.sh`：
  退出码 0/0（54 点静态 + 全场景功能 + 变异检出）。
- FuseSoC Core 文件集与 RTL 同步（`fusesoc/aixsilicon_cbb_apb_register_slice.core`，
  sim=vcs / lint=spyglass target 已声明）。

## 已知限制（集成必读）

1. SLICE_MODE=0 时主↔子 PREADY 环回为组合直通（ASM-004），环回时序由消费方评估。
2. 本构件为纯透传，不做协议检查/超时保护（叠加 BUS-008 需消费方集成）。
3. 未测参数组合属 experimental；`full_slice_deep` Profile 保持 experimental（语义已验，场景较少）。

## 豁免与成熟度建议

- 无已批准豁免（lint 4 W/3 I 均 warning/info 级，无阻断项）。
- **成熟度建议：E2（qualification candidate）**——Workflow Gate 批准 G7 后可进入
  Release 流程（G8 SemVer/SBOM/Manifest/Catalog）。实际发布状态由 Release 流程确认，
  本报告不替代。
