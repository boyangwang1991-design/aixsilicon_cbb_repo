# Changelog

本仓库遵循语义化版本（SemVer）管理 CBB 平台整体版本；单个 CBB 在其工程包内独立维护版本。

## [0.1.0] - 2026-08-12

### Added
- 初始化 CBB 平台目录骨架（FuseSoC Library 形态，遵循 iprepo-management-suite 统一仓规范）
- 依据 `cbb_repo_list.md` 建立 410 个 CBB 空工程包 + README 需求说明占位：
  - `adapters/` A0 技术适配（22）
  - `components/` A1~A3 构件（17 个功能类别，364）
  - `templates/` A4 子系统模板（24）
- 为每个 CBB 生成 `fusesoc/*.core`（CAPI=2，VLNV `aixsilicon:cbb:<name>:0.1.0`）与 `ip-package.yaml`
- 生成根 `registry.yaml` 内嵌索引、`fusesoc.conf`、GitHub Actions CI
- 新增 `scripts/init_structure.sh`（幂等初始化）与 `scripts/build_cbb_structure.py`（清单解析生成器）
- 新增 `docs/`（architecture / cbb_spec / ppa / getting_started）与 recipes / schemas / verification / flows / tools 框架

> 当前各 CBB 为规划占位（成熟度 E0），未含 RTL 与 PPA 表征数据。
