# CBB 平台适配（PPA-aware CBB 仓库）

> 适用范围：当本套件服务于「PPA 优化的 CBB（可配置构建块）基础构件库」仓库时，按本文档调整
> 目录布局、生成流程与索引/发布约定。核心差异是：**CBB 粒度小、按功能类别组织、清单驱动生成**，
> 且 PPA 表征数据与选型是仓库的核心价值。

## 1. 与通用 IP 统一仓的差异

| 维度 | 通用 IP 统一仓 | CBB 平台仓库 |
| --- | --- | --- |
| 组织单位 | IP（业务功能，独立版本） | CBB（构件族，逻辑独立版本） |
| 目录布局 | `ips/<vendor>/<ip>/<version>/` | `components/<类别>/<功能名>/`、`adapters/<功能名>`、`templates/<功能名>` |
| 目录命名 | IP 名 | **功能名**（清单 ID 保留在元数据） |
| 清单来源 | 构建结果 manifest | `cbb_repo_list.md`（候选全集，SSOT 驱动） |
| 入库方式 | `ipkg stage`（复制构建结果） | `scripts/build_cbb_structure.py`（清单解析生成占位） |
| 元数据 | ip-package.yaml + manifest | README + ip-package.yaml +（开发期）cbb.yaml |
| 索引 | registry.yaml（ips 条目） | registry.yaml（cbbs 条目：id/name/abstraction/priority/...） |
| 附加价值 | 交付与消费 | **PPA 表征数据 + 自动选型（CBB Selector）** |

## 2. CBB 仓库目录布局

```
cbb-platform/                       # 本仓库（FuseSoC Library：aixsilicon-cbb）
├── components/                     # A1~A3 构件（按功能类别，共 17 类）
│   ├── <类别>/                     # 如 fifo_queue_buffer、arithmetic_datapath
│   │   └── <功能名>/               # 如 sync_fifo、apb_slave_adapter
│   │       ├── README.md           # 需求说明占位（当前阶段）
│   │       ├── ip-package.yaml     # 元数据（schema 2.0）
│   │       ├── fusesoc/            # FuseSoC core（CAPI=2）
│   │       │   └── aixsilicon_cbb_<功能名>.core
│   │       ├── cbb.yaml            # SSOT 元数据（开发期补齐，plan §8）
│   │       ├── rtl/{interface,impl}/  verification/  constraints/  characterization/  ...
│   ├── adapters/                   # A0 技术适配（TEC，22 个）
│   ├── templates/                  # A4 子系统模板（TMP，24 个，独立治理）
├── recipes/  schemas/  verification/  flows/  tools/
├── cbb_repo_list.md                # CBB 构件完整清单（候选全集，SSOT）
├── registry.yaml                   # 内嵌索引（cbbs 条目）
├── fusesoc.conf                    # FuseSoC 库注册
└── .github/workflows/ci.yml        # FuseSoC core lint + registry 校验
```

> 每个 CBB 目录以**功能名**命名（如 `sync_fifo`），清单 ID（如 `QUE-001`）保留在 README 标题、
> `ip-package.yaml`、`registry.yaml` 与 `.core` 描述中。

## 3. VLNV 与命名

- Vendor：`aixsilicon`；Library：`cbb`
- Name：功能名小写下划线（如 `sync_fifo`、`apb_slave_adapter`）
- VLNV：`aixsilicon:cbb:<功能名>:<version>`（初始 `0.1.0`）
- 抽象层级 A0~A4 与优先级 P0~P3 是元数据标签，不是目录层级
- FuseSoC core 文件：`fusesoc/aixsilicon_cbb_<功能名>.core`

## 4. 清单驱动生成流程（核心差异）

CBB 仓库**清单驱动**：`cbb_repo_list.md` 是候选全集（SSOT），
[`scripts/build_cbb_structure.py`](../../scripts/build_cbb_structure.py:1) 解析后批量生成：

```
cbb_repo_list.md（章节=功能类别；行=ID|构件族|实现变体|级别|优先级|PPA关注点）
        │  build_cbb_structure.py
        ▼
  components/<类别>/<功能名>/  adapters/<功能名>/  templates/<功能名>/
  ├── README.md（需求说明占位）
  ├── ip-package.yaml（schema 2.0）
  └── fusesoc/aixsilicon_cbb_<功能名>.core（CAPI=2）
        │
        ▼
  registry.yaml（根内嵌索引：410 个 cbbs 条目）
```

**命令**：

```bash
# 完整初始化（框架 + CBB 生成 + FuseSoC 脚手架）
bash scripts/init_structure.sh
# 仅按清单重建 CBB 目录/元数据/索引
python3 scripts/build_cbb_structure.py
```

**新增/修改 CBB（占位）**：编辑 `cbb_repo_list.md` 对应章节行 → 重跑生成器 → 编辑生成的 README 补充需求。

## 4.1 外部 CBB 交付件合并入库（stage_cbb）

适用于「**外部写好的 CBB 交付件 → 处理 → 合并到 cbbrepo → 上传**」工作流：

```bash
SUITE_DIR="${SUITE_DIR:-.roo/skills/cbbrepo-management}"

# 1) 校验 + 规划（dry-run，只读）
uv run python "$SUITE_DIR/scripts/stage_cbb.py" <交付件目录> --repo . --dry-run

# 2) 合并入库（自动定位 components/<类别>/<功能名> 或 adapters/、templates/）
uv run python "$SUITE_DIR/scripts/stage_cbb.py" <交付件目录> --repo . --id QUE-099

# 3) 全量重建 cbbs 索引（扫描 components/adapters/templates 的 ip-package.yaml）
uv run python "$SUITE_DIR/scripts/stage_cbb.py" . --repo . --rebuild

# 4) 上传（git commit + push；R1 白名单已含 components/adapters/templates）
uv run python "$SUITE_DIR/scripts/publish_repo.py" .
```

**身份解析优先级**：`cbb.yaml`（cbb.name / classification）> `ip-package.yaml` > 交付件目录名。

**目标定位规则**：
- A0 → `adapters/<功能名>/`；A4 → `templates/<功能名>/`
- A1~A3 → `components/<类别>/<功能名>/`；类别由 `--category` 显式指定，或由 `cbb.yaml` 的 `primary_domain` 经内置映射表推断
- 可选覆盖：`--name`、`--abstraction`、`--priority`、`--id`

**合并动作**：复制交付件内容（排除 `.git/.venv/__pycache__` 等）→ 生成/刷新 `ip-package.yaml`（schema 2.0）→ upsert `registry.yaml` 的 `cbbs` 条目（status=merged）。

### 4.2 分工：LLM vs 脚本（务必区分）

| 环节 | 由谁 | 说明 |
| --- | --- | --- |
| 交付件规范审查、身份/类别/抽象/优先级/ID 判断 | **LLM** | 需要权衡与知识判断 |
| 质量门禁审查（G0~G5）、是否可合并 | **LLM** | 决定是否放行 |
| 文件复制/合并、SHA 校验、生成 ip-package.yaml/registry.yaml | **脚本**（stage_cbb 确定性操作） | 幂等、可 dry-run |
| 重建 cbbs 索引 | **脚本**（stage_cbb --rebuild） | 扫描 ip-package.yaml 生成 |
| `git status` / `git ls-remote --tags` 侦查 | **脚本**（只读） | 纯事实采集 |
| git add 范围审查（R1 白名单）、提交信息、tag 策略 | **LLM** | 判断与决策 |
| **git add/commit/push/tag 执行** | **LLM 授权后执行** | 不放给脚本盲跑；先 dry-run + 白名单审查，再执行；push/tag 覆盖等不可逆动作必须 LLM 明确确认 |

> **关键原则**：脚本只做确定性操作与只读侦查；**git 写操作（add/commit/push/tag）存在误跟踪、误推送、tag 冲突等风险，必须由 LLM 判断后手动执行**（或脚本仅在 LLM 明确授权 + R1~R6 门禁全过时才执行）。`publish_repo.py` 默认先 dry-run、白名单校验，实际推送需 LLM 确认。

## 5. CBB 元数据与索引

### 5.1 `registry.yaml`（cbbs 条目）

```yaml
schema_version: "2.0"
updated: "2026-08-12T00:00:00Z"
vendor: aixsilicon
library: cbb
unified_repo: ""
cbbs:
  - id: QUE-001            # 清单 ID
    name: sync_fifo        # 功能名（目录名）
    group: components/fifo_queue_buffer
    abstraction: A2
    priority: P0
    status: planned
    version: "0.1.0"
    path: components/fifo_queue_buffer/sync_fifo
```

### 5.2 `ip-package.yaml`（每个 CBB）

schema 2.0：`name/version/vendor/library/description/license/path/maturity/classification/quality.gates/fusesoc.core`。

### 5.3 `cbb.yaml`（开发期 SSOT，plan §8）

开发 RTL 时补齐：`classification`（abstraction + domain）、`contract`、`parameters`、
`implementations`、`quality`、`characterization`（benchmark_profiles）、`release`（fusesoc VLNV）。
PPA 结果经 `run_id`/`dataset_version` 关联，不塞入 cbb.yaml。

## 6. 质量门禁与成熟度（CBB 版本）

| 门禁 | 目标 | 说明 |
| --- | --- | --- |
| G0 Intake | 资产定义完整 | 需求、契约、元数据、Owner |
| G1 Function | 功能正确 | Lint、仿真、断言、参考模型 |
| G2 Robustness | 边界与协议正确 | 随机测试、Formal、覆盖率 |
| G3 Implementation | 可实现且约束正确 | 综合、STA、CDC/RDC/DFT |
| G4 PPA Characterized | PPA 可复现 | 表征矩阵、基线、Pareto |
| G5 Released | 可稳定消费 | SemVer、FuseSoC Core、Manifest |
| G6 Proven | 真实项目复用 | 项目反馈、问题闭环 |

成熟度：E0 Concept → E1 Functional → E2 Verified → E3 Characterized → E4 Released → E5 Proven。
CDC/RDC、ICG、Isolation 等实行白名单实现，AI 只能选型与参数化。

## 7. 与 ipkg 三阶段流程的映射

| ipkg 阶段 | CBB 平台对应 | 说明 |
| --- | --- | --- |
| stage（入库） | `build_cbb_structure.py` 生成占位 | 清单驱动批量生成，替代逐 IP 复制 |
| index（索引） | 生成器写 `registry.yaml` | `cbbs` 条目由生成器维护 |
| publish（发布） | 逐 CBB 独立发布（SemVer + FuseSoC Core + Catalog） | 满足 G5 后按 CBB 打 tag；A4 独立治理 |

> 开发完成后，单个 CBB 的发布仍可复用本套件 stage/publish 的校验与 tag 逻辑（manifest 证据、
> SemVer、FuseSoC Core），但内容以 `components/<类别>/<功能名>/` 为准。

## 8. FuseSoC 消费

```bash
fusesoc library add aixsilicon-cbb /path/to/cbb-platform
fusesoc core list                 # 发现全部 CBB（410 个）
fusesoc run --target sim aixsilicon:cbb:sync_fifo:0.1.0   # 需 RTL 就绪
```

> 占位阶段 `.core` 的 filesets 引用 `rtl/interface`、`rtl/impl`（尚为空），`core list/show` 可用，
> `run` 需等 RTL 开发后可用。

## 9. 首期建设范围（P0）

推荐先形成约 **40 个可发布构件族**（见 `cbb_repo_list.md` 第 22 节）：
SRAM/ICG/Clock Mux Wrapper、Mux/Encoder/Decoder/LZC/Popcount、Adder/Accumulator/Compare/Resize、
Parity/SECDED/Gray、Address Decoder/Register Array/SRAM 拼宽拼深/RAW Bypass、
Sync/Async/Fall-through FIFO、Elastic/Skid Buffer、Forward/Backward/Full Slice、
Fixed Priority/RR Arbiter/Credit Manager、单比特/Pulse/Handshake/Gray CDC、Reset 同步/拉伸、
Counter/Timer/Timeout/Event Collector、中断 Conditioner/Aggregator、Generic CSR/APB Adapter/Decoder/Timeout、
AXI/AXI-Lite/AXI-Stream Register Slice/AXI Decoder/Default Slave。
