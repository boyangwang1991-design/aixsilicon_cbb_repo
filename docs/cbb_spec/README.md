# CBB 标准工程包规范

本仓库是一个 FuseSoC Library。每个 CBB 的最终交付形态是**标准工程包**，
目录布局遵循 [`docs/architecture/README.md`](../architecture/README.md:1) 第 9.3 节。

当前阶段（初始化）每个 CBB 只是空文件夹 + 需求 README；开发时按下述规范展开。

## 标准工程包结构（9.3 节）

```
components/<category>/<功能名>/  # 如 components/fifo_queue_buffer/sync_fifo
                                  # （或 adapters/<功能名> A0、templates/<功能名> A4）
├── README.md                 # 需求说明文档（当前已生成）
├── cbb.yaml                  # SSOT 元数据（见模板 template/cbb.yaml）
├── rtl/
│   ├── interface/            # 契约/接口文件（所有实现共享）
│   └── impl/                 # 微架构实现（每个实现一个子目录）
├── pkg/                      # 打包/发布产物（可选）
├── verification/
│   ├── common/               # 公共验证组件
│   ├── simulation/           # 仿真
│   ├── formal/               # 形式验证
│   └── assertions/           # SVA / formal properties
├── constraints/              # SDC / UPF 等
├── fusesoc/                  # FuseSoC Core（<vendor>_<library>_<name>.core）
├── characterization/
│   ├── plan.yaml             # 表征计划
│   └── baselines/            # PPA 基线数据
├── examples/                 # 使用示例
├── docs/                     # 设计文档
├── CHANGELOG.md              # 变更历史
└── OWNERS                    # 维护人/负责人
```

## 关键文件

### 1. `cbb.yaml`（SSOT 元数据）

每个 CBB 的机器可读单一事实来源，遵循架构文档第 8 节 Schema。模板见
[`template/cbb.yaml`](template/cbb.yaml:1)。要点：

- `classification`：抽象粒度（A0~A4）与主/次技术域
- `contract`：接口、时钟域、顺序、吞吐等功能契约
- `parameters`：功能参数（与微架构参数分离）
- `implementations`：微架构变体列表（各自挂接 rtl/impl 与 constraints）
- `quality`：必选质量门禁（G0~G6）
- `characterization`：基准环境（benchmark_profile_id）与已表征区域
- `release`：FuseSoC VLNV 与许可证

PPA 结果不塞入 `cbb.yaml`，通过不可变 `run_id` / `dataset_version` 关联到结果库。

### 2. FuseSoC Core（`fusesoc/<vendor>_<library>_<name>.core`）

CAPI=2 格式，VLNV 命名 `aixsilicon:cbb:<cbb_name>:<version>`。模板见
[`template/template.core.tmpl`](template/template.core.tmpl:1)
（`.tmpl` 后缀避免被 FuseSoC 误识别为真实 core）。

- 文件集路径相对 `.core` 所在目录（`fusesoc/`），用 `../rtl/...` 引用包内文件
- 提供 `rtl`、`synth`、`sim`、`formal` target

### 3. `registry.yaml`（根目录内嵌索引）

按 iprepo-management-suite 统一仓规范维护，列出全部 CBB 的 ID、抽象层、分组、路径。
由 `scripts/build_cbb_structure.py` 依据 `cbb_repo_list.md` 自动生成。

## 新增一个 CBB

```bash
# 1) 在 cbb_repo_list.md 对应章节补充一行（ID/构件族/实现变体/级别/优先级/PPA），然后：
bash scripts/init_structure.sh        # 或 python3 scripts/build_cbb_structure.py

# 2) 编辑生成的 components/<category>/<功能名>/README.md 补充需求
# 3) 开发 RTL 后，复制模板并填写（Name 用功能名小写下划线，如 sync_fifo）：
cp docs/cbb_spec/template/cbb.yaml           components/<category>/<功能名>/cbb.yaml
cp docs/cbb_spec/template/template.core.tmpl components/<category>/<功能名>/fusesoc/aixsilicon_cbb_<功能名>.core
```

## VLNV 命名与 SemVer

- Vendor：`aixsilicon`；Library：`cbb`；Name：小写下划线；Version：SemVer（初始 `0.1.0`）

## 成熟度与质量门禁

- 成熟度：E0 Concept → E1 Functional → E2 Verified → E3 Characterized → E4 Released → E5 Proven
- 质量门禁：G0 Intake → G1 Function → G2 Robustness → G3 Implementation → G4 PPA Characterized → G5 Released → G6 Proven

详见 [`docs/architecture/README.md`](../architecture/README.md:1) 第 7 节。
