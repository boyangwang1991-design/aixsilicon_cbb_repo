# 统一仓交付件清单（Deliverables）

本文档明确统一建仓（monorepo）模式下，统一仓及各 IP 版本目录所需的**交付件清单**，
以及每类交付件的来源与所有权。

## 1. 统一仓根目录（一次初始化）

| 交付件 | 位置 | 来源 | 说明 |
|--------|------|------|------|
| README.md | 根目录 | 生成 | 统一仓使用指南（添加、搜索、入库） |
| LICENSE | 根目录 | 生成 | 许可证 |
| CHANGELOG.md | 根目录 | 生成 | 统一仓级变更历史 |
| registry.yaml | 根目录 | 生成/维护 | 内嵌索引（schema_version 2.0 + ips 列表） |
| .github/workflows/ci.yml | 根目录 | 生成 | 统一仓 CI（扫描全部 core lint + 索引校验） |
| ips/ | 根目录 | stage 写入 | IP 内容根（`<vendor>/<ip>/<version>/`） |

初始化命令：`ipkg init-repo`（复制 `unified-repo-template/`）。

## 2. 每个 IP 版本目录（`ips/<vendor>/<ip>/<version>/`）

| 交付件 | 来源 | 所有权 | 说明 |
|--------|------|--------|------|
| manifest.yaml | 构建结果原样 | ip-development-suite 18-release-packager | 冻结清单（每文件 SHA-256 / role / owner），建仓证据 |
| release_note.md | 构建结果原样 | 18-release-packager | 发布说明（类别、范围、质量摘要、已知问题） |
| README.md | 生成 | ipkg stage_ip | IP 说明 + 质量门禁表格 |
| LICENSE | 生成 | ipkg stage_ip | 许可证（config.template.license） |
| CHANGELOG.md | 生成 | ipkg stage_ip | 版本变更历史（Keep a Changelog） |
| ip-package.yaml | 生成 | ipkg stage_ip | IP 包描述（VLNV/依赖/门禁/统一仓路径） |
| fusesoc/*.core | 构建结果原样 | 08-fusesoc-packager | FuseSoC CAPI=2 core，**复用不重建** |
| rtl/ | 构建结果原样 | 07-rtl-code-generator | RTL 设计源码 |
| docs/ | 构建结果原样 | 01/03/05/06/17 | LRS/HLD/LLD/验证方案/集成/用户文档 |
| regs/ | 构建结果原样 | 02-reg-model | SystemRDL（可选） |
| sw/ | 构建结果原样 | 02-reg-model | 软件 C header（可选） |
| verification/ | 构建结果原样 | 10/11/12/13/14 | UVM 验证代码（env/tc/th） |
| model/ | 构建结果原样 | extractor | canonical YAML（requirements/architecture/...） |
| trace/ | 构建结果原样 | 16-trace-manager | 追踪矩阵（req/hld/lld/rtl/test） |
| constraints/ | 构建结果原样 | 可选 | SDC 等 |
| reports/ | 构建结果原样（stage 额外复制） | 09/15 | 质量/验证报告证据：quality（gate_report/run_log）、lint/elab/synth/formal/smoke 等 |

## 3. 入库规则（stage_ip）

1. **来源**：只从 ip-development-suite 构建结果（工作区）复制，**不基于 zip**。
2. **文件清单**：以 `release/<ip>_<version>/manifest.yaml` 的 `files[]` 为准；
   每个文件的相对路径即统一仓版本目录内的目标路径。
3. **完整性**：复制后逐文件校验 SHA-256，与 manifest 不一致即报错停止。
4. **排除**：`release/*.zip`、`.git/`、EDA scratch（`simv*`、`*.daidir`、`work/` 等）。
5. **FuseSoC core**：复用 `fusesoc/*.core`（08 产物），不重新生成。
6. **报告证据**：除 manifest 文件外，`stage_ip` 额外复制 `reports/` 下的质量/验证
   报告（quality/lint/elab/synth/formal/smoke 等）作为发布证据，即使 manifest
   未列出这些文件。

## 4. 索引条目（registry.yaml）

`ipkg index` 从每个版本目录的 `ip-package.yaml` 生成 registry 条目，字段：
`name / vendor / library / description / license / path / versions[]`；
`versions[]` 含 `version / tag / released / path / gates / manifest_sha256 / fusesoc.core / dependencies`。

## 5. 消费方交付

统一仓发布后，消费者只需：
```bash
fusesoc library add ip-unified https://github.com/<org>/ip-unified.git
fusesoc run --target sim <vendor>:<library>:<ip>:<version>
```
依赖通过 FuseSoC `depend` + SemVer 约束在统一仓内解析。
