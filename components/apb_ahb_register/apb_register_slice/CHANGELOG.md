# Changelog — apb_register_slice

格式参考 Keep a Changelog；版本语义 SemVer。所有条目倒序。

## [0.1.0] — 2026-09-11

### Added（首次发布，BUS-003 planned → released 候选，G0–G8 全 pass）

- 规格：`cbb.yaml`（SSOT，内嵌参数/约束/需求/实现）+ `behavior.yaml`（INV-001..006 /
  ASM-001..004）+ `profiles.yaml`（4 Profile）+ `docs/cbb_spec.md` / `docs/intake.md`。
- 设计：`docs/design.md` + `docs/detail-design/response.md`、`docs/detail-design/request_full.md`。
- RTL：`rtl/apb_register_slice.sv`（极简单文件；SLICE_MODE/RESP_STAGES 编译期 generate
  分派；generate `$error` 拦截 PC-001..006；就近 SVA `PROP-ARS_*-00x`）。
- 验证：`verification/plan.yaml`（10 tc_*）；`simulation/apb_register_slice_tb.sv`
  （复位/定向/RS=2/随机 300 事务/三模式等价/变异）；`formal/negative_elab_tb.sv`；
  `scripts/run_static_checks.sh`（G3）与 `scripts/run_functional_sim.sh`（G4，固定 seed）。
- 配置：`config-gen` 生成 mandatory/boundary/pairwise/negative 4 集合 37 配置
  （去重 + 约束过滤）。
- 构建：`fusesoc/aixsilicon_cbb_apb_register_slice.core`（sim=vcs / lint=spyglass）。
- PPA：G6 真实综合表征（PPA-E2，DC compile_ultra 29 点 @tt_1p00v_25c/2.5ns）——
  [`reports/ppa-report.md`](reports/ppa-report.md) + `reports/ppa_{area,timing}_sweep.png`。
- 发布：`release/manifest.yaml`（SBOM 无嵌套依赖 + SHA-256 哈希 + 已知限制）。
