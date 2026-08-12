# 统一仓内嵌索引（registry.yaml）参考

> 参考文档：统一仓内嵌索引的结构、维护、搜索与依赖解析。需要维护索引或解析依赖时阅读本文件。

## 架构

```
ip-unified/                         # 统一仓
├── registry.yaml                   # 内嵌索引（全部 IP 元数据）
├── ips/                            # IP 内容（stage_ip 写入）
│   └── <vendor>/<ip>/<version>/    # 每个版本目录含 ip-package.yaml
└── .github/workflows/
    └── ci.yml                      # 统一仓 CI
```

每个 IP 版本入库（`ipkg stage`）后，其元数据由 `ipkg index`（`update_registry.py`）
upsert 到 `registry.yaml`，与 `ips/` 变更**同一次提交**推送到统一仓。

## 初始化统一仓

使用套件的 `unified-repo-template/` 模板初始化：

```bash
SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"

# 1. 复制模板到新目录
cp -r "$SUITE_DIR/unified-repo-template" ip-unified
cd ip-unified

# 2. 初始化 Git 并推送到 GitHub
git init
git add .
git commit -m "Initialize unified IP repository"
git remote add origin https://github.com/<org>/ip-unified.git
git push -u origin main

# 3. 更新 ipkg 配置指向统一仓
ipkg init --org <org> --unified-repo ip-unified
```

## registry.yaml 索引格式

```yaml
schema_version: "2.0"
updated: "2026-08-10T00:00:00Z"
unified_repo: "https://github.com/rtl-team/ip-unified.git"

ips:
  - name: apb_gpio_lite
    vendor: rtl-team
    library: rtl
    description: "APB GPIO Lite Controller - 8-bit GPIO with rising-edge interrupt"
    license: "MIT"
    path: "ips/rtl-team/apb_gpio_lite"     # 统一仓内相对目录
    versions:
      - version: "1.0.0"
        tag: "apb_gpio_lite-v1.0.0"        # 统一仓 tag（带 IP 前缀）
        released: "2026-08-04"
        path: "ips/rtl-team/apb_gpio_lite/1.0.0"
        gates: {G0: pass, G1: pass, G2: pass, G3: pass, G4: pass, G5: pass}
        description: "APB GPIO Lite Controller"
        manifest_sha256: "abc123..."       # 冻结清单哈希
        fusesoc:
          core: "rtl-team:rtl:apb_gpio_lite:1.0.0"
        dependencies:
          - name: apb_gpio_lite
            version: ">=1.0.0"
            vendor: rtl-team
            library: rtl
```

**字段说明**：
- `unified_repo` - 统一仓 URL（**所有 IP 都在此仓内**，不再有 per-IP repository URL）
- `name` / `vendor` / `library` - 构成 VLNV 标识符（`vendor:library:name`）
- `path` - IP 在统一仓内的相对目录（`ips/<vendor>/<ip>`）
- `versions[].version` - SemVer 版本号
- `versions[].tag` - 统一仓 Git tag（带 IP 前缀）
- `versions[].gates` - G0-G5 质量门禁状态
- `versions[].dependencies` - 可选，依赖的其他 IP（FuseSoC 约束语法）
- `versions[].fusesoc.core` - 完整 VLNV（`vendor:library:name:version`）

## 更新索引

### 自动更新（推荐）

入库 IP 时自动触发（`ipkg stage --then-index` 或 `ipkg index`），在统一仓工作副本内：
1. 打开 `registry.yaml`
2. 从 `ips/<vendor>/<ip>/<version>/ip-package.yaml` upsert IP 条目
3. 版本列表按 SemVer 升序排序
4. 写回 `registry.yaml`（与 `ips/` 变更同一提交）

### 手动更新（全量重建）

```bash
SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"
uv run python "$SUITE_DIR/scripts/update_registry.py" \
  --unified <unified-repo> [--ip <name>] [--config <path>] [--dry-run]
```

不带 `--ip` 时扫描统一仓全部 `ips/**/ip-package.yaml` 重建索引（用于删除/迁移后修复）。

## 搜索与查询

通过 CLI 查询统一仓内嵌索引（见 [`ipkg-cli.md`](ipkg-cli.md)）：

```bash
# 搜索 IP（支持通配符）
ipkg search gpio
ipkg search "*" --format json

# 列出所有 IP
ipkg list
ipkg list --format json

# 查看 IP 详情
ipkg info apb_gpio_lite 1.0.0
```

这些命令从配置的 `github.unified_repo` 获取 `registry.yaml`（raw GitHub URL 或本地统一仓）。

## 依赖管理

### 依赖声明

IP 的 `manifest.yaml` 或 `ip-package.yaml` 中声明依赖：

```yaml
dependencies:
  - name: apb_gpio_lite
    version: ">=1.0.0"      # 版本约束
    vendor: rtl-team
    library: rtl
  - name: mect
    version: "^1.0.0"       # Caret 约束：>=1.0.0 <2.0.0
    vendor: rtl-team
    library: rtl
```

### 版本约束语法（FuseSoC SemVer）

| 操作符 | 含义 | 示例 |
|--------|------|------|
| `=` | 精确匹配 | `=1.0.0` |
| `>=` | 大于等于 | `>=1.0.0` |
| `>` | 大于 | `>1.0.0` |
| `<=` | 小于等于 | `<=1.0.0` |
| `<` | 小于 | `<2.0.0` |
| `^` | Caret 约束 | `^1.2.3` → `>=1.2.3 <2.0.0` |
| `~` | Tilde 约束 | `~1.2.3` → `>=1.2.3 <1.3.0` |

### 依赖解析（FuseSoC 单仓消费）

```bash
# 添加统一仓（一次性，所有 IP 都在此仓内）
fusesoc library add ip-unified https://github.com/<org>/ip-unified.git

# 运行仿真（自动解析依赖，核心 VLNV）
fusesoc run --target sim rtl-team:rtl:my_project:1.0.0
```

> 注：FuseSoC 扫描统一仓内全部 `fusesoc/*.core`；同名不同版本可能产生多 core 歧义，
> 推荐依赖版本用精确约束或通过 registry 解析后 `fusesoc library add` 对应版本目录。

## 与 FuseSoC 集成

```bash
# 1. 添加统一仓
fusesoc library add ip-unified https://github.com/<org>/ip-unified.git

# 2. 使用已入库 IP（my_project.core 声明依赖）
# depend:
#   - ">=rtl-team:rtl:apb_gpio_lite:1.0.0"

# 3. 运行仿真
fusesoc run --target sim my-org:my-projects:my_project:1.0.0
```

## 失败处理

- 统一仓无法访问（404/网络）→ 报告错误，检查 `github.unified_repo` 配置
- `registry.yaml` 格式无效 → 报告解析错误
- 版本重复 → upsert 覆盖旧版本（保持最新）
- 依赖版本不满足约束 → FuseSoC 报告无匹配版本
- 扫描不到 `ip-package.yaml` → 提示先用 `ipkg stage` 入库

## 变更影响

- 入库新 IP/版本后必须更新 `registry.yaml`（`ipkg index`）
- 删除 IP/版本目录后，运行 `update_registry.py --unified ...` 全量重建索引
- 索引条目变化（如 vendor/路径迁移）需手动编辑 `registry.yaml` 并提交
