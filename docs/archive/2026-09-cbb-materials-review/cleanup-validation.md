# 清理验证记录（2026-09-13）

- 两仓 registry 校验通过，README 派生视图一致；当前主清单无跨仓同名条目。
- IP Skill 全部测试通过（174 passed，1 skipped）；CBB Skill 全部 33 个测试通过。
  新增回归覆盖编号复用拒绝、退役条目禁止重建、stage 不写入及旧 generate 不恢复历史规划且保留扩展字段。
- IP/CBB 套件自检及 skill-creator quick_validate 通过；canonical 修改已重新物化到 workflow `.roo/skills/`。
- 工作区 `make check` 通过（125 个测试、Ruff、6 个 Schema 同步）；`pre-commit run --all-files` 通过。
  这些工作区检查不代替资产 RTL 或 Skill 测试，后者已分别执行。
- 迁移前 Git HEAD 的 APB 36 个文件、diversity comparator 1 个文件与迁移后逐字节一致。
  只读 Git 对象用于文件完整性诊断；仓库状态/差异通过 `aix repo` 查询。
- FuseSoC 在 IP 仓库配置下发现旧 APB Core，Core 根路径指向新工程目录。
- 新路径下运行原 APB `verification/scripts/run_functional_sim.sh`：VCS 功能测试 PASS，
  包括复位、定向、RS=2、300 次随机事务及等价测试；反馈错位变异被检出（610 行诊断）。
  首次沙箱内许可证连接失败，正常本地环境重试成功；本次没有重新授予全部 IP 发布 Gate。

## 保留的存量差异

- planned `watchdog` 的包版本与清单不一致；planned `memory_protection_controller` 的包名
  `axi_mpu` 及版本与清单不一致。指导 YAML 同样保留规划身份；本轮未更改其设计身份或升级状态。
- 全仓 FuseSoC 扫描会报告旧 axi_mpu Core 的 fileset `is_include_file` 格式问题，
  以及未清理本地 build 缓存内的同名 Core。APB Core 本身可被正确发现；不声称全仓依赖闭包已通过。
- APB 旧 CBB 元数据、Gate 报告、Core 标识为迁移兼容保留；新 IP 发布身份需在正式发布任务中
  生成与验证。历史 EDA build 内路径相关软链接不作为新位置的可复现基线。

本地详细日志、输入快照、迁移哈希与回归输出在 workflow `tmp/ip_cbb_cleanup/audit/`。
资产归档快照与退出/恢复记录保存在本仓 `docs/archive/`、`governance/`。
