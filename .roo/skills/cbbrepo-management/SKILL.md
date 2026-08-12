---
name: cbbrepo-management
description: >
  IP 仓库管理套件（统一建仓）。采用「单仓 monorepo + 内嵌索引」架构，将
  ip-development-suite 的构建结果直接入库到唯一 GitHub 统一仓（如 ip-unified），
  按 ips 目录下 vendor 与 ip 与 version 三级组织，内嵌 registry 索引；废弃 per-IP
  独立仓，FuseSoC 只 add 这一个仓。当用户提到 IP 发布、统一建仓、IP 仓库、ipkg、
  registry、IP 索引、IP 搜索、中央仓、monorepo、依赖管理、发布 IP 到
  GitHub 或 GitLab 等任务时，务必使用此 skill。本套件直接消费 ip-development-suite
  的 release 构建结果（manifest.yaml 与 release_note.md 与工作区真实文件），不基于
  zip 重建。当任务涉及 **CBB 平台（PPA 优化基础构件库）**——components/adapters/templates
  目录、cbb_repo_list.md 清单、CBB 元数据/选型/Catalog、PPA 表征数据时，结合
  references/cbb-platform.md 的 CBB 适配约定使用。任务范围较小时，只加载匹配的
  参考文档及其必需内容。
---

# IP 仓库管理套件（统一建仓）

本文件是套件的唯一入口，包含完整架构与「统一建仓」流程（stage → index → publish）。
需要 CLI 命令参数或索引/依赖细节时，再按需阅读对应参考文档。

## 架构概览

采用「**统一仓 monorepo + 内嵌索引**」架构：所有 IP 内容集中到**唯一** GitHub 统一仓，
按 `ips/<vendor>/<ip>/<version>/` 组织，`registry.yaml` 内嵌于统一仓根目录。**不再为每个 IP
单独建仓**。

```
ip-development-suite 构建结果               cbbrepo-management（统一建仓）
┌──────────────────────────┐              ┌──────────────────────────────────────┐
│  ip_<name>/              │              │  ip-unified (GitHub 统一仓 monorepo)   │
│  ├── rtl/ docs/ regs/    │              │  ├── registry.yaml  ← 内嵌索引          │
│  ├── fusesoc/*.core      │   stage      │  ├── ips/                              │
│  ├── verification/ ...   │ ──────────►  │  │   └── <vendor>/<ip>/<version>/      │
│  └── release/            │   (直接复制)  │  │       ├── manifest.yaml + rtl/...   │
│      └── <ip>_<ver>/     │              │  │       └── fusesoc/ + docs/ ...       │
│          ├── manifest.yaml              │  └── .github/workflows/ci.yml           │
│          └── release_note.md            │                                        │
└──────────────────────────┘              └──────────────────────────────────────┘
                                                  │ ipkg index
                                                  ▼
                                          registry.yaml 更新（同一提交）
                                                  │ ipkg publish
                                                  ▼
                                          git commit + push（含 tag）
                                                  │
                                                  ▼
                                     FuseSoC 消费者 add 统一仓一次即可发现全部 IP
```

**关键原则**：输入必须是 ip-development-suite 的**构建结果**（`release/<ip>_<version>/manifest.yaml`
+ `release_note.md` + 工作区真实交付文件），直接按 manifest 的文件清单复制入库；
**不得**解压 `release/*.zip` 重建内容（zip 仅作归档，不作为建仓输入）。

## 统一仓结构（明确）

```
ip-unified/                              # 统一仓（仓库名见 config: github.unified_repo）
├── README.md                            # 统一仓说明 + 使用指南（生成）
├── LICENSE                              # 许可证（生成）
├── CHANGELOG.md                         # 变更历史（生成）
├── registry.yaml                        # 内嵌索引：全部 IP 元数据（ipkg index 维护）
├── .github/workflows/
│   └── ci.yml                           # 统一仓 CI：扫描 ips/ 全部 core 做 lint
└── ips/                                 # IP 内容根
    └── <vendor>/                        # 例 rtl-team
        └── <ip>/                        # 例 apb_gpio_lite
            └── <version>/               # 例 1.0.0（SemVer）
                ├── manifest.yaml        # 冻结清单（构建结果原样，证据）
                ├── release_note.md      # 发布说明（构建结果原样）
                ├── README.md            # IP 说明（生成）
                ├── LICENSE              # 许可证（生成）
                ├── CHANGELOG.md         # 版本历史（生成）
                ├── ip-package.yaml      # IP 包描述：VLNV/依赖/门禁（生成）
                ├── fusesoc/             # FuseSoC core（复用 08-fusesoc-packager 产物）
                │   └── <vendor>_<library>_<ip>.core
                ├── rtl/                 # RTL 设计源码（构建结果）
                ├── docs/                # LRS/HLD/LLD/验证/集成/用户手册（构建结果）
                ├── regs/                # SystemRDL（构建结果，可选）
                ├── sw/                  # 软件 C header（构建结果，可选）
                ├── verification/        # UVM 验证代码（构建结果）
                ├── model/               # canonical YAML（构建结果）
                ├── trace/               # 追踪矩阵（构建结果）
                ├── constraints/         # SDC 等（构建结果，可选）
                ├── reports/             # 质量/验证报告证据（构建结果，stage 额外复制）
                │   └── quality/ lint/ elab/ synth/ formal/ smoke/ ...
                └── ...                  # manifest 中其余 role 文件按原路径复制
```

## 运行合同

- 仅在 Linux 和 Bash 下运行。
- 使用 uv 管理 Python 和项目内 `.venv`。
- 每个 shell 只解析一次套件路径：

  ```bash
  SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"
  ```

- CLI 统一入口为 `ipkg`（详见 [`references/ipkg-cli.md`](references/ipkg-cli.md)）。
- 配置来源（优先级从高到低）：命令行 `--config` > 环境变量 `IPKG_CONFIG` >
  本地 `./ipkg.yaml` > 用户 `~/.config/ipkg/config.yaml` > 系统 `/etc/ipkg/config.yaml`。
- 依赖采用 FuseSoC `depend` 语法和 SemVer 约束（详见
  [`references/registry-index.md`](references/registry-index.md)）。

## 统一建仓流程（stage → index → publish）

将已完成开发并通过 G5 质量门禁的 IP，从其**构建结果**直接入库统一仓，更新内嵌索引后
推送到 GitHub。**不基于 zip 重建**。

### 前置条件

```
输入：IP 工作区（ip_<name>/，ip-development-suite 构建结果）
├── release/
│   └── <ip>_<version>/
│       ├── manifest.yaml        # 冻结清单（必需，含每文件 SHA-256/role/owner）
│       └── release_note.md      # 发布说明（必需）
├── rtl/ docs/ verification/ model/ trace/ ...   # 真实交付文件
├── fusesoc/
│   └── <vendor>_<library>_<ip>.core   # 08-fusesoc-packager 产物（复用，不重建）
└── ipkg.yaml                    # 配置文件（可选，可使用全局配置）

目标：统一仓（ip-unified）已初始化（ipkg init-repo）
```

**发布检查清单**：
- [ ] 构建结果 manifest.yaml 存在且格式有效（含 schema_version / ip_name / version / files）
- [ ] G5 门禁状态为 `pass`（manifest.quality.g5_status 或 model/quality.yaml）
- [ ] 版本号符合 SemVer 规范
- [ ] manifest 中每个文件都能在工作区中找到且 SHA-256 一致
- [ ] FuseSoC core 已存在（复用构建结果，不重建）
- [ ] 统一仓已初始化且 registry.yaml 可读写
- [ ] GitHub 认证配置正确（ssh-key 或 token）

### 三阶段发布

```
阶段 1: ipkg stage（入库）
  输入: ip_<name>/ 构建结果（manifest.yaml + 工作区真实文件）
  输出: 统一仓 ips/<vendor>/<ip>/<version>/ 目录结构
  动作:
    1. 读取 release/<ip>_<version>/manifest.yaml
    2. 按 manifest.files[].path 从工作区复制真实文件到统一仓（不做 zip 解压）
    3. 复制 fusesoc/*.core（复用 08 产物）
    4. 复制 manifest.yaml + release_note.md（证据）
    5. 生成 README.md / LICENSE / CHANGELOG.md / ip-package.yaml
    6. 校验每文件 SHA-256 与 manifest 一致

阶段 2: ipkg index（索引）
  输入: 已入库的 IP 版本目录
  输出: 统一仓 registry.yaml 更新（同一工作副本，同一提交）
  动作:
    1. 读取 ips/<vendor>/<ip>/<version>/ip-package.yaml
    2. upsert 该 IP 条目到统一仓 registry.yaml
    3. 版本列表按 SemVer 升序排序

阶段 3: ipkg publish（发布）
  输入: 更新后的统一仓
  输出: GitHub 统一仓 + git tag
  动作:
    1. git add/commit（含 ips/ 变更 + registry.yaml）
    2. 推送统一仓 main
    3. 打 tag（如 <ip>-v<version> 或 v<ip>_<version>，见下文）
```

### 执行流程

**开箱即用脚本**：`scripts/stage_ip.py`、`scripts/update_registry.py`、`scripts/publish_repo.py`。

```bash
SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"

# 阶段 1：从构建结果入库统一仓
uv run python "$SUITE_DIR/scripts/stage_ip.py" \
  <ip-workspace> --unified <unified-repo> [--config <path>] [--then-index] [--then-publish]

# 阶段 2：更新内嵌索引
uv run python "$SUITE_DIR/scripts/update_registry.py" \
  --unified <unified-repo> [--ip <name>] [--config <path>] [--dry-run]

# 阶段 3：提交推送统一仓
uv run python "$SUITE_DIR/scripts/publish_repo.py" \
  <unified-repo> [--config <path>] [--dry-run] [--no-tag] [--no-push]
```

#### 阶段 1：ipkg stage

**脚本**：`scripts/stage_ip.py`

参数：
- `<ip-workspace>` - IP 工作区路径（含 `release/` 构建结果）
- `--unified <repo>` - 统一仓根目录（默认：`<workspace>/../ip-unified`）
- `--config <path>` - 配置文件路径
- `--then-index` - 入库后立即更新索引
- `--then-publish` - 入库+索引后立即发布（含 index）

执行步骤：
1. 加载配置，确定 vendor / library / 统一仓名
2. 定位 `release/<ip>_<version>/manifest.yaml`（唯一，多版本需 `--version`）
3. 按 `manifest.files[].path` 从工作区**直接复制**文件到
   `<unified>/ips/<vendor>/<ip>/<version>/<path>`（逐文件校验 SHA-256）
4. 复制 `release_note.md` 与 `manifest.yaml` 到版本目录（证据）
5. 复制 `fusesoc/*.core` 到 `ips/<vendor>/<ip>/<version>/fusesoc/`
6. 生成 `README.md`（含质量门禁表格）、`LICENSE`、`CHANGELOG.md`
7. 生成 `ip-package.yaml`（VLNV、依赖、门禁、统一仓相对路径）
8. 校验：所有复制文件 SHA-256 与 manifest 一致；缺失或哈希不匹配则报错

**文件来源规则**：
- 文件**只从工作区复制**（manifest 中的相对路径），**不**从 zip 解压。
- 排除 `release/*.zip`、`.git/`、EDA scratch（`simv*`、`*.daidir`、`work/` 等）。
- 若 manifest 中某 path 在工作区缺失，报告错误并停止（不静默跳过）。

**FuseSoC core 处理**：复用构建结果 `fusesoc/<vendor>_<library>_<ip>.core`
（由 `08-fusesoc-packager` 生成），原样复制，**不重建、不重新推导**。

#### 阶段 2：ipkg index

**脚本**：`scripts/update_registry.py`

参数：
- `--unified <repo>` - 统一仓根目录
- `--ip <name>` - 可选，只更新指定 IP（默认扫描全部）
- `--config <path>` - 配置文件路径
- `--dry-run` - 只打印变更

执行步骤：
1. 打开 `<unified>/registry.yaml`
2. 对每个 `ips/<vendor>/<ip>/<version>/` 读取 `ip-package.yaml`
3. upsert IP 条目（含 repository 指向统一仓、tag、gates、fusesoc core、依赖）
4. 版本列表按 SemVer 升序排序
5. 写回 `registry.yaml`（与 ips/ 变更一起提交）

#### 阶段 3：ipkg publish

**脚本**：`scripts/publish_repo.py`

参数：
- `<unified-repo>` - 统一仓路径
- `--config <path>` - 配置文件路径
- `--dry-run` - 模拟运行，不实际推送/tag
- `--no-tag` - 不创建 Git tag
- `--no-push` - 不推送到远程

执行步骤：
1. 加载配置，确定 GitHub 组织和统一仓名（`github.unified_repo`）
2. 读取 `registry.yaml` 确认待发布内容
3. `git add` + `git commit`（提交信息含本次新增/更新的 IP 与版本）
4. 添加远程并 `git push -u origin main`
5. 为本次入库的每个 IP 版本打 tag（见下）
6. 统一仓 CI（`.github/workflows/ci.yml`）会扫描全部 core 做 lint

**Tag 命名**（统一仓含多 IP，tag 必须带 IP 前缀避免冲突）：
- 单 IP 单版本：`<ip>-v<version>`（如 `apb_gpio_lite-v1.0.0`）
- 也可配置为 `v<version>`（`config: publish.tag_with_ip: false`）

**认证要求**：
- 方式 1（推荐）：SSH Key 已配置到 GitHub
- 方式 2：设置 `GITHUB_TOKEN` 环境变量
- 统一仓需一次性创建（`ipkg init-repo`），发布阶段只 push，不新建仓库

### 使用示例

```bash
# 完整三阶段（分开执行）
cd ip_apb_gpio_lite

# 阶段 1：从构建结果入库统一仓
uv run python "$SUITE_DIR/scripts/stage_ip.py" . --unified ../ip-unified

# 阶段 2：更新索引
uv run python "$SUITE_DIR/scripts/update_registry.py" --unified ../ip-unified --ip apb_gpio_lite

# 阶段 3：发布
uv run python "$SUITE_DIR/scripts/publish_repo.py" ../ip-unified

# 一键入库+发布
uv run python "$SUITE_DIR/scripts/stage_ip.py" . --unified ../ip-unified --then-publish

# 模拟运行
uv run python "$SUITE_DIR/scripts/publish_repo.py" ../ip-unified --dry-run
```

### 更新已发布的 IP

```bash
# 场景：发布新版本 1.1.0
cd ip_apb_gpio_lite
# 修改代码 → 运行回归 → 重新构建结果（18-release-packager）
# 生成新的 release/apb_gpio_lite_1.1.0/manifest.yaml + release_note.md

# 入库并发布新版本（旧版本 1.0.0 保留在统一仓 ips/ 中）
uv run python "$SUITE_DIR/scripts/stage_ip.py" . --unified ../ip-unified --then-publish

# 自动：新增 ips/rtl-team/apb_gpio_lite/1.1.0/ + 更新 registry.yaml + tag apb_gpio_lite-v1.1.0
```

### 规则驱动与决策分工

本套件采用「**规则驱动**」：脚本只做**确定性操作**（复制、校验、生成、git 原子命令），
所有需要**判断、权衡、应变**的决策由大模型按本规则执行。**不得用固定脚本接管全流程**，
尤其禁止脚本自动执行不可逆动作（`git add -A`、push、删 tag）而不经判断。

#### 四阶段执行模型

```
侦查（命令采集事实）→ 决策（LLM 按规则判断）→ 执行（脚本做确定性操作）→ 复查（LLM 核对）
```

| 阶段 | 动作 | 归谁 |
|---|---|---|
| 侦查 | `git status` / `git ls-remote --tags` / 读 manifest / 列文件清单 | 命令（纯事实采集） |
| 决策 | 判断 add 范围、release class、dry-run 语义、tag 策略、异常处理 | LLM（按规则） |
| 执行 | 复制文件、SHA 校验、生成 yaml、git add/commit/push/tag | 脚本/命令（被授权后） |
| 复查 | manifest vs registry vs 包内容 vs git 状态 一致性 | LLM（核对） |

#### 决策规则（R1-R6，LLM 逐条执行）

- **R1 · git add 白名单**：publish 只允许 `git add` 这些路径：`ips/`、`registry.yaml`、
  `.github/`、`docs/`、根 `README.md`、`LICENSE`、`CHANGELOG.md`。add 前先 `git status --porcelain`
  扫描；发现白名单外路径（开发工作区、EDA scratch、`*.log`、`simv*`、`work_lib/`、`.venv/` 等）
  → **停止并提示**，绝不 `git add -A`（本次实测 `git add -A` 曾误跟踪 1138 个含 scratch 的文件）。
- **R2 · release class 判定**：`formal` ⇔ 全部满足（G0-G5 全 pass **且** `source.dirty=false` **且**
  用户明确授权）；任一不满足即 `candidate`。打包后核对 manifest：若 `release_class: formal` 但
  `dirty: true` 或 gate 非 pass → 判定违规，自动降级 `candidate` 并提示（本次实测 formal 误标未被拦截）。
- **R3 · dry-run 语义**：dry-run = 只读演练，只打印将执行的命令与影响（add 范围、commit 信息、
  tag），**不执行任何写操作**（含 add/commit/push/tag）。本次实测 dry-run 曾偷偷执行 commit。
- **R4 · tag 冲突处理**：发布前 `git ls-remote --tags origin` 检查目标 tag；已存在且指向 ≠ 当前
  HEAD → 询问用户或按配置删除重建（`git tag -d` + `git push origin :refs/tags/<tag>` + 重建 +
  `push --force`）。本次实测旧 tag 指向旧提交需手动删除。
- **R5 · evidence 过滤**：stage 复制报告证据时排除 `*.log`（工具运行日志），只保留文档类证据
  （`.md`/`.yaml`/`.html`/`.json`）；`run_log.md` 属文档保留。本次实测 17 个 EDA 日志混入正式包。
- **R6 · 依赖回填**：index 时从 `fusesoc/*.core` 的 `depend` 解析依赖，回填
  `ip-package.yaml.dependencies` 与 registry 条目，保证索引可检索依赖关系（本次实测 dependencies 为空）。

#### 门禁清单（不可逆操作前必须全部通过）

- [ ] `git status` 无白名单外变更（R1）
- [ ] formal 前提满足（R2）；candidate 时 release_note 带候选警告
- [ ] dry-run 演练通过且未产生任何写操作（R3）
- [ ] tag 冲突已处理（R4）
- [ ] 入库内容无 `*.log` 运行日志混入（R5）
- [ ] registry 依赖已回填（R6）

> 规则未覆盖的新情况：**停止并询问用户**，不得擅自决定。

### 失败处理

- 构建结果缺少 `manifest.yaml` → 报告错误并停止（先运行 18-release-packager）
- 版本号非 SemVer → 报告错误并停止
- 存在多个发布版本 → 报告歧义，要求指定 `--version`
- manifest 中文件在工作区缺失或 SHA-256 不匹配 → 报告错误并停止（不静默跳过）
- 缺少 `fusesoc/*.core` → 警告 + 提示先用 08-fusesoc-packager 生成（可继续，文档注明）
- GitHub 认证失败 → 报告错误，提示配置 SSH Key 或 `GITHUB_TOKEN`

### 变更影响

- 构建结果内容变化后，必须重新运行 `stage_ip` 更新统一仓对应版本目录
- 新版本发布后，内嵌 `registry.yaml` 自动更新（同一次提交，无独立 PR）
- 修改 `ipkg.yaml` 配置（如 vendor、统一仓名）后，需重新 stage/index
- 统一仓删除某 IP 版本目录后，需运行 `update_registry.py --unified ...` 重建索引

## 与 ip-development-suite 的关系

```
┌─────────────────────────────────────┐
│     ip-development-suite            │
│  LRS → HLD → LLD → RTL → UVM → G5   │
│   → 18-release-packager             │
└─────────────────┬───────────────────┘
                  │ 构建结果（不依赖 zip）:
                  │  release/<ip>_<version>/manifest.yaml
                  │  release/<ip>_<version>/release_note.md
                  │  工作区真实文件 + fusesoc/*.core
                  ▼
┌─────────────────────────────────────┐
│   cbbrepo-management           │
│  stage → index → publish            │
│  → 统一仓 monorepo + 内嵌 registry  │
└─────────────────────────────────────┘
```

`ip-development-suite` 负责 IP 开发与构建结果生成（manifest 冻结 + 真实交付文件），
本套件负责将构建结果**直接**入库统一仓并维护内嵌索引。FuseSoC core 复用
`08-fusesoc-packager` 的产物，**不再**从 zip 重新生成。

## 共享资源

以下资源由套件共享，通过 `$SUITE_DIR` 引用：

| 资源 | 说明 |
|---|---|
| [`scripts/`](scripts/) | Python 脚本（config / validate_release / stage_ip / publish_repo / update_registry / ipkg_cli） |
| [`templates/`](templates/) | 模板文件（ipkg.yaml / ip-package.yaml / README / CHANGELOG / CI workflow） |
| [`references/`](references/) | 参考文档（FuseSoC Library / VLNV & SemVer / ip-package schema / 交付件清单 / ipkg CLI / 索引与依赖 / CBB 平台适配） |
| [`unified-repo-template/`](unified-repo-template/) | 统一仓初始化模板（ips/ + registry.yaml + CI） |
| [`pyproject.toml`](pyproject.toml) | uv 项目配置（Python 3.11+，依赖 pyyaml） |

> 完整交付件清单见 [`references/deliverables.md`](references/deliverables.md)。
> CLI 命令与参数见 [`references/ipkg-cli.md`](references/ipkg-cli.md)。
> 索引结构、搜索与依赖解析见 [`references/registry-index.md`](references/registry-index.md)。
> **CBB 平台（PPA 优化构件库）适配见 [`references/cbb-platform.md`](references/cbb-platform.md)**。

## 交付件清单

### 统一仓内每个 IP 版本（`ips/<vendor>/<ip>/<version>/`）

| 文件/目录 | 来源 | 描述 |
|------|------|------|
| manifest.yaml | 构建结果原样 | 冻结清单（含每文件 SHA-256 / role / owner） |
| release_note.md | 构建结果原样 | 发布说明 |
| fusesoc/*.core | 构建结果原样（08 产物） | FuseSoC CAPI=2 core，直接复用 |
| rtl/ | 构建结果原样 | RTL 设计源码 |
| docs/ | 构建结果原样 | LRS/HLD/LLD/验证方案/集成/用户文档 |
| regs/ | 构建结果原样 | SystemRDL（可选） |
| sw/ | 构建结果原样 | 软件接口产物（可选） |
| verification/ | 构建结果原样 | UVM 验证代码 |
| model/ | 构建结果原样 | canonical YAML |
| trace/ | 构建结果原样 | 追踪矩阵 |
| constraints/ | 构建结果原样 | SDC 等（可选） |
| reports/ | 构建结果原样（stage 额外复制） | 质量/验证报告证据：quality（gate_report/run_log）、lint/elab/synth/formal/smoke 等 |
| README.md | 生成 | IP 说明（质量门禁表格、统一仓路径、FuseSoC 用法） |
| LICENSE | 生成 | 许可证 |
| CHANGELOG.md | 生成 | 版本变更历史 |
| ip-package.yaml | 生成 | IP 包描述（VLNV、依赖、门禁、统一仓路径） |

### 统一仓根目录

| 文件 | 位置 | 描述 |
|------|------|------|
| registry.yaml | 仓库根目录 | 内嵌索引（全部 IP 元数据） |
| README.md | 仓库根目录 | 统一仓使用指南 |
| ci.yml | `.github/workflows/` | 统一仓 CI |

## 校验

修改本套件后运行：

```bash
SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"
uv sync
uv run pytest "$SUITE_DIR/scripts/tests"
```
