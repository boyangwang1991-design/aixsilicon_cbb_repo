# ipkg CLI 参考（统一建仓）

> 参考文档：ipkg CLI 的命令、配置与参数。需要执行命令或配置 ipkg 时阅读本文件。

ipkg（IP Package Manager）是 IP 仓库管理套件的命令行工具，负责将 ip-development-suite
的构建结果入库统一仓（monorepo）、维护内嵌索引并发布。

## 运行环境

```bash
SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"
cd "$SUITE_DIR"
uv sync                      # 安装依赖（pyyaml）
uv run python scripts/ipkg_cli.py --help   # 查看帮助
```

## 命令概览

| 命令 | 功能 | 示例 |
|------|------|------|
| `init` | 创建默认配置 | `ipkg init --org rtl-team` |
| `init-repo` | 初始化统一仓（monorepo） | `ipkg init-repo --org rtl-team --name ip-unified` |
| `config` | 显示生效配置 | `ipkg config` |
| `validate` | 验证构建结果（manifest + 文件） | `ipkg validate <ip-workspace>` |
| `stage` | 从构建结果入库统一仓 | `ipkg stage <ip-workspace> --unified <repo>` |
| `index` | 更新内嵌 registry.yaml | `ipkg index --unified <repo>` |
| `publish` | 提交推送统一仓 + tag | `ipkg publish <unified-repo>` |
| `search` | 搜索 IP | `ipkg search gpio` |
| `list` | 列出所有 IP | `ipkg list` |
| `info` | 查看 IP 详情 | `ipkg info apb_gpio_lite 1.0.0` |

## 配置管理

### 配置文件位置

配置文件路径：`~/.config/ipkg/config.yaml` 或工作区根目录 `ipkg.yaml`

### 配置优先级

1. 命令行参数 `--config <path>`
2. 环境变量 `IPKG_CONFIG`
3. 工作区根目录 `./ipkg.yaml`
4. 用户配置 `~/.config/ipkg/config.yaml`
5. 系统配置 `/etc/ipkg/config.yaml`

### 配置结构

```yaml
# ipkg.yaml（统一建仓）
schema_version: "2.0"

# GitHub 配置（必需）
github:
  org: rtl-team               # GitHub 组织或用户名
  auth: ssh-key               # 认证方式：ssh-key | token
  # token_env: GITHUB_TOKEN   # 当 auth = token 时使用
  unified_repo: ip-unified    # 统一仓名（monorepo，唯一）

# FuseSoC 配置（VLNV 命名空间）
fusesoc:
  vendor: rtl-team
  library: rtl
  cores_dir: fusesoc

# 发布配置
publish:
  default_class: formal
  auto_tag: true
  auto_push: true
  tag_with_ip: true           # tag 带 IP 前缀（<ip>-v<version>）
  checks:
    - g5_pass
    - valid_manifest
    - files_hash_ok

# IP 包模板配置
template:
  license: MIT
  changelog: true
  readme_template: default
```

### 环境变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `GITHUB_TOKEN` | GitHub Personal Access Token | `ghp_xxxx` |
| `IPKG_CONFIG` | 配置文件路径 | `/path/to/ipkg.yaml` |
| `IPKG_UNIFIED_REPO` | 覆盖统一仓名 | `ip-unified` |

## 命令详细说明

### ipkg init

```bash
ipkg init [OPTIONS]

选项:
  --org <org>               GitHub 组织/用户名
  --unified-repo <name>     统一仓名（默认 ip-unified）
  --output <path>           输出路径（默认 ~/.config/ipkg/config.yaml）

示例:
  ipkg init --org rtl-team
  ipkg init --org rtl-team --unified-repo ip-unified
```

### ipkg init-repo

```bash
ipkg init-repo [OPTIONS]

选项:
  --org <org>                GitHub 组织/用户名
  --name <name>              统一仓名（默认 ip-unified）
  --output <path>            输出目录（默认 ./ip-unified）

示例:
  ipkg init-repo --org rtl-team --name ip-unified
```

从 `unified-repo-template/` 复制模板并生成 `registry.yaml` 骨架、CI workflow。

### ipkg config

```bash
ipkg config [--config <path>]

# 显示当前生效的配置（含所有默认值）
```

### ipkg validate

```bash
ipkg validate <ip-workspace> [--config <path>] [--strict]

参数:
  <ip-workspace>              IP 工作区路径（ip-development-suite 构建结果）

选项:
  --strict                    要求 manifest 中每个文件 SHA-256 都精确匹配

# 验证项：
# - manifest.yaml 存在且格式有效
# - 必需字段（schema_version, ip_name, version）
# - 版本号符合 SemVer
# - G0-G5 质量门禁全部 pass
# - manifest 中每个文件在工作区存在且 SHA-256 匹配（不依赖 zip）
```

### ipkg stage

```bash
ipkg stage <ip-workspace> [OPTIONS]

参数:
  <ip-workspace>              IP 工作区路径

选项:
  --unified <path>            统一仓根目录（默认 <workspace>/../ip-unified）
  --config <path>             配置文件路径
  --version <version>         指定版本号（多版本时）
  --then-index                入库后更新索引
  --then-publish              入库+索引后立即发布

示例:
  ipkg stage ip_apb_gpio_lite --unified ./ip-unified
  ipkg stage ip_mect --unified ./ip-unified --then-publish
```

从构建结果直接复制入库（不基于 zip）。详细流程见主 SKILL.md「统一建仓流程」章节。

### ipkg index

```bash
ipkg index --unified <repo> [OPTIONS]

选项:
  --unified <repo>            统一仓根目录
  --ip <name>                 可选，只更新指定 IP（默认扫描全部）
  --config <path>             配置文件路径
  --dry-run                   只打印变更

示例:
  ipkg index --unified ./ip-unified
  ipkg index --unified ./ip-unified --ip apb_gpio_lite --dry-run
```

### ipkg publish

```bash
ipkg publish <unified-repo> [OPTIONS]

参数:
  <unified-repo>              统一仓路径

选项:
  --config <path>             配置文件路径
  --dry-run                   模拟运行，不实际推送/tag
  --no-tag                    不创建 Git tag
  --no-push                   不推送到远程

示例:
  ipkg publish ./ip-unified
  ipkg publish ./ip-unified --dry-run
```

### ipkg search

```bash
ipkg search <pattern> [OPTIONS]

参数:
  <pattern>                   搜索模式（支持通配符，默认 *）

选项:
  --format <fmt>              输出格式：table | json

示例:
  ipkg search gpio
  ipkg search "*" --format json
```

### ipkg list

```bash
ipkg list [--format <fmt>]

# 列出统一仓内嵌索引中的所有 IP
# 输出：IP Name | Latest | Versions | Path
```

### ipkg info

```bash
ipkg info <ip> [<version>]

参数:
  <ip>                        IP 名称
  <version>                   版本号（默认最新版本）

示例:
  ipkg info apb_gpio_lite
  ipkg info apb_gpio_lite 1.0.0

# 输出：名称、描述、统一仓路径、版本、tag、发布日期、FuseSoC core、质量门禁
```

## 依赖管理

依赖声明位于 IP 的 `manifest.yaml` 或 `ip-package.yaml` 中（详见
[`registry-index.md`](registry-index.md) 的依赖管理章节）。

## 运行与测试

```bash
cd "$SUITE_DIR"

# 运行单元测试
uv run pytest -v

# 端到端验证（dry-run）
uv run python scripts/ipkg_cli.py init-repo --org rtl-team --output /tmp/ip-unified
uv run python scripts/ipkg_cli.py validate <ip-workspace>
uv run python scripts/ipkg_cli.py stage <ip-workspace> --unified /tmp/ip-unified
uv run python scripts/ipkg_cli.py index --unified /tmp/ip-unified
uv run python scripts/ipkg_cli.py publish /tmp/ip-unified --dry-run
```

## 常见错误与排查

| 错误 | 原因 | 解决 |
|------|------|------|
| `No module named 'scripts'` | 未用 `uv run` 运行 | 使用 `uv run python ...` |
| `No manifest.yaml found` | 构建结果结构不符合标准 | 用 ip-development-suite 18-release-packager 重新生成 |
| `Multiple manifests found` | 存在多个版本 | 指定 `--version` |
| `failed to fetch registry` | 统一仓 URL 无效/无网络 | 检查 `github.unified_repo` 配置 |
| `file hash mismatch` | 工作区文件被改动，与 manifest 不一致 | 重跑 18-release-packager 冻结最新 manifest |
| `no gh CLI and no GITHUB_TOKEN` | 无法创建统一仓 | 安装 gh 或设置 GITHUB_TOKEN，手动创建仓库 |
