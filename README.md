# AixSilicon CBB Repository

**CBB（公共基础构件）交付发布仓**：存放经过验证的 CBB 交付件，管理版本，并作为 **FuseSoC Library** 提供消费入口。

CBB 的需求/规格/RTL 实现/验证/PPA 表征的开发方法与工具链在 **cbb-development-suite**（Skill）中定义与执行；本仓库只接收其**交付件**。

## 目录结构

```text
.
├── adapters/            # A0 技术适配交付件（22 条候选；实现后落位）
├── components/          # A1~A4 已交付 CBB 工程包（每构件含 cbb.yaml + rtl + verification + evidence + fusesoc/core）
├── fusesoc.conf         # FuseSoC 库注册
├── registry.yaml        # 交付件索引（唯一 SSOT：id/name/family/group/abstraction/priority/implementation/description/status/version/path）
├── reports/quality/     # 交付证据（run_log.md 等）
├── CHANGELOG.md         # 平台版本
└── LICENSE              # Apache-2.0
```

## FuseSoC 使用

```bash
# 将本仓库注册为 FuseSoC 库
fusesoc library add aixsilicon-cbb /path/to/aixsilicon_cbb_repo

# 列出 / 运行交付构件
fusesoc core list
fusesoc core show aixsilicon:cbb:<cbb_name>:<version>
fusesoc run --target sim aixsilicon:cbb:<cbb_name>:<version>
```

VLNV 命名：`aixsilicon:cbb:<cbb_name>:<version>`。

## registry.yaml

`registry.yaml` 是 CBB 交付件的机器可读索引（唯一 SSOT），每条含：

| 字段 | 说明 |
| --- | --- |
| `id` | 构件 ID（如 `QUE-012`） |
| `name` | 英文功能名（VLNV name，如 `width_conversion_fifo`） |
| `family` | 中文名（构件族） |
| `group` | 类别路径（如 `components/fifo_queue_buffer`） |
| `abstraction` | 抽象粒度 A0~A4 |
| `priority` | P0~P3 |
| `implementation` | 主要实现变体 |
| `description` | PPA/工程关注点 |
| `status` | `planned`（未实现）或 `implemented`（目录存在且通过验证） |
| `version` | 版本（SemVer） |
| `path` | 交付件相对路径 |

`status=implemented` 的条目在 `components/` 下存在完整工程包；`planned` 条目仅为规划候选，无物理目录。

类别说明：`group=adapters`（A0 技术适配，22 条候选）、`group=components/*`（A1~A3 构件）、`group=templates`（A4 子系统模板，24 条候选）。A4 模板为候选索引，实现后以交付件形式进入对应类别。

## 当前已交付构件

暂无（2026-08：QUE-001 sync_fifo / QUE-012 width_conversion_fifo / SEL-014 popcount 工程包已移除、
registry 条目回退 planned，等待重新开发交付；历史证据见 `reports/quality/run_log.md`）。

更多条目见 [`registry.yaml`](registry.yaml:1)（410 条候选）。

## 贡献交付件

新 CBB 交付流程（需求→契约→RTL→验证→PPA→发布）由 cbb-development-suite 定义；本仓库在交付件就绪后：

1. 在 `components/` 对应类别下放置完整工程包（含 `fusesoc/aixsilicon_cbb_<name>.core`）；
2. 在 [`registry.yaml`](registry.yaml:1) 中登记/更新条目（`status=implemented`）；
3. 更新 `CHANGELOG.md` 与版本。

## 许可

Apache-2.0（见 [`LICENSE`](LICENSE:1)）。
