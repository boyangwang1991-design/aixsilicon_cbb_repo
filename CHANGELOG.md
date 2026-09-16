# Changelog

本仓库遵循语义化版本（SemVer）管理 CBB 平台整体版本；单个 CBB 在其工程包内独立维护版本。

## [Unreleased]

### Added
- 新增类别 `components/interconnect` 与 CBB **INT-001 parallel_data_fetch**
  （[`components/interconnect/parallel_data_fetch/`](components/interconnect/parallel_data_fetch/README.md)，A3/P2）——
  单请求远端原子快照经窄链路连续回传并在请求端重组，以传输时延换取长距布线资源。
  - **双端点集成边界**：`parallel_data_fetch_requester`（A 端，仅 A 域）与
    `parallel_data_fetch_provider`（B 端，仅 B 域）可分别放置于相距较远的区域，窄链路作为跨区布线；
    `pdf_async_fifo`（Gray 指针）作为链路跨域单元挂在端点之外，`parallel_data_fetch` 仅为同层封装。
  - 参数与约束（PC-001～PC-011）：`DATA_WIDTH/LINK_WIDTH/LSB_FIRST/ASYNC_MODE/PARITY_EN/ODD_PARITY/
    TIMEOUT_EN/TIMEOUT_CYCLES/REQ_SYNC_STAGES/RSP_FIFO_DEPTH/LINK_PIPE_STAGES/SLICE_IMPL`；
    非法组合由 RTL `generate` 内 `$error` 在 elaboration 期拦截。
  - 切片三实现 `SLICE_IMPL=shift/indexed/banked`，共享同一可观察契约（SVA 约束输出恒等于快照切片）。
  - 证据：G3 静态基线 positive 21/21 + negative 15/15；G4 功能 12/12 参数化用例
    （BEAT_COUNT=1/非 2 次幂、pipe1/8、三切片、MSB-first、奇/偶校验、宽/窄链路），
    每用例 52 事务、SVA 全程开启、`bubbles=0`（VCS W-2024.09）。
  - 未完成：G5 配置矩阵回归、异步模式定向/随机回归、G6 门级 PPA（`OPTIONAL_UNAVAILABLE`，E0）
    与 G7/G8；见工程内 `reports/qualification-report.md` 剩余风险。

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

> 0.1.0 初始化时，各 CBB 为规划占位（成熟度 E0），未含 RTL 与 PPA 表征数据。

## 2026-09-16 noc_interconnect 分类退出

- 按需求方要求退出 `components/noc_interconnect` 整类规划（NOC-007 crossbar_fabric、NOC-009
  credit_return_channel、NOC-010 link_register_slice、NOC-011 link_cdc_adapter、NOC-012
  link_width_converter）：退出前仅为需求草案与 README 占位，无实现、无验证/PPA 证据。
- `registry.yaml` 移除 5 条登记（292 条，implemented=10）；`README.md` 派生视图经
  `scripts/update_registry_readme.py` 刷新。
- 退出记录写入 `governance/retired-assets.yaml`（`source_files: archived` + `archive_path`）；
  ID 与名称继续保留在 `governance/reserved-ids.yaml`，编号不复用。
- 需求草案与 README 占位归档至 `docs/archive/2026-09-cbb-materials-review/noc_interconnect/`。

## 2026-09-13 IP/CBB 分类清理

统一 registry 管理入口、状态和编号纪律；按指导清单精简规划，保留退出记录与工程材料，迁移 APB 桥及 diversity comparator。历史记录见 docs/archive/2026-09-cbb-materials-review/cleanup-2026-09.md。
