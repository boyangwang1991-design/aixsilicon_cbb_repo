# AixSilicon CBB Platform

**PPA-aware CBB Platform**：经过功能验证、实现验证和多维 PPA 表征，可按设计约束自动检索、比较、选型和集成的芯片公共基础构件平台。

本仓库是一个 **FuseSoC Library**（布局遵循 iprepo-management-suite 统一仓规范）。
完整规划见 [`docs/architecture/README.md`](docs/architecture/README.md:1)（V1.0）。

## 体系框架

四类资产 × 四个支撑平面：

| 资产 | 说明 |
| --- | --- |
| 构件资产 | A0 技术适配 / A1 原子机制 / A2 通用复合 / A3 协议构件 / A4 子系统模板 |
| 实现变体 | 同一功能契约下的多个微架构（承载面积/频率/功耗/延迟 trade-off） |
| 参考架构与优化配方 | 多构件组合方法与选型规则（Recipe） |
| PPA 数据与证据 | 综合、时序、功耗、验证、适用范围与回归结果 |

支撑平面：质量验证、PPA 表征与模型、生成集成与发布、检索推荐与智能选型。

抽象分层（纵向）与技术域（横向标签）见 [`docs/architecture/README.md`](docs/architecture/README.md:1)。

## 目录结构

```text
.
├── components/          # A1~A3 构件（按 cbb_repo_list.md 功能类别，17 类 364 个）
├── adapters/            # A0 技术适配构件（22 个）
├── templates/           # A4 子系统模板（24 个，独立治理）
├── recipes/             # 参考架构与优化配方
├── schemas/             # cbb.yaml 与结果 Schema
├── verification/        # 公共 VIP、Formal 与测试框架
├── flows/               # 表征、回归和发布流程
├── tools/               # 工具链（10 个）
├── docs/                # 架构、PPA 体系、CBB 规范、入门
├── scripts/             # 通用脚本（目录初始化 + CBB 生成器）
├── tests/               # 顶层测试
├── examples/            # 使用示例
├── cbb_repo_list.md     # CBB 构件完整清单（SSOT 候选全集）
├── cbb_repo_plan.md     # 整体规划（V1.0）
├── fusesoc.conf         # FuseSoC 库注册
├── registry.yaml        # 内嵌索引（410 个 CBB 元数据）
└── .github/workflows/   # CI：扫描 *.core 做 FuseSoC lint
```

## FuseSoC 使用

```bash
fusesoc library add aixsilicon-cbb /path/to/aixsilicon_cbb_repo
fusesoc core list
fusesoc run --target sim aixsilicon:cbb:<cbb_name>:0.1.0
```

VLNV 命名：`aixsilicon:cbb:<cbb_name>:<version>`。详见 [`docs/getting_started/README.md`](docs/getting_started/README.md:1)。

## 每个 CBB 的当前形态

当前每个 CBB 为**空工程包 + README 需求说明占位**（目录以功能名命名，如 `components/fifo_queue_buffer/sync_fifo`，清单 ID 保留在元数据中），
开发时按 [`docs/cbb_spec/README.md`](docs/cbb_spec/README.md:1) 的 9.3 节标准工程包展开
（`rtl/interface`、`rtl/impl`、`verification`、`characterization`、`fusesoc/*.core` 等）。

## 首期建设范围（P0）

推荐先形成约 **40 个可发布构件族**（见 [`cbb_repo_list.md`](cbb_repo_list.md:1) 第 22 节）：
SRAM/ICG/Clock Mux Wrapper、Mux/Encoder/Decoder/LZC/Popcount、Adder/Accumulator/Compare/Resize、
Parity/SECDED/Gray、Address Decoder/Register Array/SRAM 拼宽拼深/RAW Bypass、
Sync/Async/Fall-through FIFO、Elastic/Skid Buffer、Forward/Backward/Full Slice、
Fixed Priority/RR Arbiter/Credit Manager、单比特/Pulse/Handshake/Gray CDC、Reset 同步/拉伸、
Counter/Timer/Timeout/Event Collector、中断 Conditioner/Aggregator、Generic CSR/APB Adapter/Decoder/Timeout、
AXI/AXI-Lite/AXI-Stream Register Slice/AXI Decoder/Default Slave。

## 快速开始

```bash
# 初始化/补齐目录骨架（幂等，可重复执行；含按 cbb_repo_list.md 生成 CBB 目录与 registry.yaml）
bash scripts/init_structure.sh

# 仅重新生成 CBB 目录与 registry.yaml
python3 scripts/build_cbb_structure.py
```
