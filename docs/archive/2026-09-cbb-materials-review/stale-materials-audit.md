# 过时材料排查（2026-09-13）

| 材料 | 处理 | 原因 |
|---|---|---|
| IP 根 plan.md | 移入 docs/archive/2026-09-ip-cbb-cleanup | 全量规划与当前精简清单冲突 |
| IP docs/opentitan-ip-build-list.md | 同目录归档 | 0 字节，不能作为上游纳管清单 |
| IP 89 个已退出规划目录 | 原路径结构归档，更新治理映射 | 均仅含空占位文件，无实现与设计正文 |
| CBB scripts/init_structure.sh | 原脚本归档为 .txt，入口只报退役并退出 | 会删除目录、覆盖配置且吞掉错误 |
| CBB adapters/README.md | 修正 | 写死旧数量，仍列已退出的 CAM 候选 |
| IP/CBB 索引脚本说明 | 修正 | 旧 Python 生成入口、plan.md 依据及空工程交付描述不准确 |
| CBB Skill plan.md/design.md | 移出 Skill 树到 skill_repo/docs/archive | 旧边界规则与现行合同冲突，不能继续列为当前依据 |
| Skill 导航/校验/管理交接 | 同步修正 | 校验当前合同，默认不加载历史材料 |

保留：CHANGELOG、日期化清理报告、真实工程的设计与验证证据。
已退出主清单但仍有实质工程内容的 apb_secure_demux 继续保留原路径，属于治理记录中的保留工程；
不把其已有 RTL 或报告当作空占位删除，也不自动认定与其他资产功能等价。
现行 planned 资产的空文件不作为过时文件删除，规划存在不表示设计已完成。

归档以目录和 FUSESOC_IGNORE 隔离；旧规划不再位于日常入口，原 ID/路径映射仍可恢复。
未改变 RTL、接口、实现状态或历史 Gate 证据。

## 仓库根报告泄漏

原 reports/quality/run_log.md 混合多个 CBB 的历史日志，已逐字节归档到
docs/archive/2026-09-ip-cbb-cleanup/repository-root-reports/quality/run_log.md。
根因是 log 默认 workspace=. 与仓库根运行约定组合，缺少工程身份校验。
现已取消默认值，log/gate 强制工程及路径检查；仓库 registry 校验拒绝根 reports/。
原日志未拆分或改写为各工程的新 Gate 证据。

验证：CBB 套件 42 个测试通过，覆盖两种 CLI 缺 workspace 拒绝、仓根/分类目录/未登记工程拒绝、符号链接拒绝、合法工程增量追加、Gate 根目录拒绝及仓库 reports 检出；套件自检和仓库索引校验通过，canonical Skill 已重新物化。
