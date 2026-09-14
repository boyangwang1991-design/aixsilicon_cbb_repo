# 2026-09 IP/CBB 清理报告

依据用户提供的分类原则与核心精简版 v2 YAML。主清单从 **410** 项调整为 **298** 项，当前 implemented 为 **10** 项。

- 完整 APB 工程从 CBB `BUS-003 / apb_register_slice` 迁入 IP `MIG-IP-BUS-003 / apb_register_bridge`。保留实际 implemented 状态与 0.1.0 版本，覆盖指导清单的 planned 占位；保留旧 Core 和全部原始交付件，无重复 RTL。
- IP `SAF-015 / diversity_comparator` 设计契约迁入 CBB `MIG-CBB-SAF-015`，继续为 planned。
- 本仓共有 113 个退出记录，完整原条目、迁移目标、原文件处置和恢复方法见 `governance/retired-assets.yaml`。其余移出主清单的现有工程留在原路径，没有删除源码。
- 指导清单未保留的条目不推定功能等价，不自动合并实现；同族候选在明确功能契约后再合并。
- IP 旧 Python 规划源归档，旧 --generate 入口仅规范化当前 registry；两仓统一 registry 直接维护、只读校验、可选规范化和 README 刷新。
- 历史编号（包括更早退出的 IP 编号）永久预留；校验拒绝更改或复用历史编号。

迁移保留 RTL、约束、测试、Core 和历史报告原文。APB 的旧 CBB VLNV 仍可由 IP 仓库发现；历史 CBB Gate 不构成新 IP 身份的发布资格。旧 build 缓存包含与路径深度有关的工具软链接，应重新构建，不能作为新位置的可复现发布基线。

验证结果见本仓 `docs/cleanup-validation.md`。

两套 canonical 开发 Skill 已同步分类与管理交接，CBB scaffold 拒绝按退出记录重建源资产；IP 00-workspace 先查 registry 和历史记录。详细流程由各 Suite 的 references/repository-management.md 维护。

后续材料整理：IP 根 plan.md、空上游清单及 89 个已退出的空占位目录已归档；文件最新位置以治理记录的 archive_path 为准。详见 [过时材料排查](stale-materials-audit.md)。
