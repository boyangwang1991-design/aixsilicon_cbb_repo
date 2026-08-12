# 发布流程（Release）

CBB 版本化发布与 Catalog 更新（架构文档第 9 节）。

## 步骤

1. 满足 G5 门禁（SemVer 包、FuseSoC Core、文档、Manifest）
2. 接口/行为不兼容升级 Major；新增兼容功能升级 Minor；修复升级 Patch
3. PPA 数据集、表征流程和技术适配包分别版本化，不与 RTL 版本混成一个版本号
4. 生成 FuseSoC Core、Release Manifest，更新 `registry.yaml` / Catalog
5. 弃用须提供替代构件、迁移说明和最后支持版本

## 当前状态

空（规划中）。VLNV 与 SemVer 规范见 [`docs/cbb_spec/README.md`](../../docs/cbb_spec/README.md:1)。
