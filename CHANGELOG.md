# Changelog

本仓库遵循语义化版本（SemVer）管理 CBB 平台整体版本；单个 CBB 在其工程包内独立维护版本。

## [0.1.2] - 2026-08-28

### Added
- 交付 **QUE-007 skid_buffer**（[`components/fifo_queue_buffer/skid_buffer/`](components/fifo_queue_buffer/skid_buffer/README.md)，A3/P0）——
  Valid-Ready 打拍模块（OUT 寄存 + SKID 槽，切断 ready 组合链，满吞吐无气泡、FIFO 保序），
  G3/G4/G6 证据完整（VCS 功能仿真 + DC 400MHz 真实综合 PPA），2026-08-28 交付。

## [0.1.1] - 2026-08-12

### Fixed
- 修复 `adapters/README.md` 与 `templates/README.md` 中 `docs/cbb_spec` 失效相对链接（`../../` → `../`）
- 修复 `scripts/build_cbb_structure.py` 类别 README 相对路径写死问题（按类别深度动态计算，防止 adapters/templates 复发）
- 补齐 `fusesoc.conf` 的 `sync-uri` / `sync-type` / `sync-branch`（含 `init_structure.sh` 模板同步）
- 扩展 `schemas/cbb.schema.yaml` 的 abstraction 枚举，支持组合级别（如 `A1/A2`），与 `registry.yaml` 保持一致
- 修正 `init_structure.sh` 注释中规划文档文件名（`plan.md` → `cbb_repo_plan.md`）

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
