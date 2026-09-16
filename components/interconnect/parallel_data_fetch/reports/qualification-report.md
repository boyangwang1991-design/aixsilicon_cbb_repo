# 资格评估 — parallel_data_fetch（INT-001）

> 状态：**development_candidate（G0–G4 通过）**；成熟度 **E0**（无门级 PPA 表征）。
> 只有 Workflow Gate 可转换 qualified/released；本报告不自行升级状态。

## 1. 结论摘要

| 项目 | 结果 | 证据 |
|---|---|---|
| G0 Intake | pass | [`docs/intake.md`](../docs/intake.md)（边界/查重/依赖/风险） |
| G1 Contract | pass | [`cbb.yaml`](../cbb.yaml)、[`behavior.yaml`](../behavior.yaml)、[`profiles.yaml`](../profiles.yaml)；`check --phase specify --strict` PASS；[`trace/rtm.yaml`](../trace/rtm.yaml) 22 条 |
| G2 Architect | pass | [`docs/design.md`](../docs/design.md)、[`docs/detail-design/slice_impl.md`](../docs/detail-design/slice_impl.md) |
| G3 RTL Static | pass | [`../build/eda/evidence/g3_static/summary.txt`](../build/eda/evidence/g3_static/summary.txt)：positive 21/21，negative 15/15（VCS W-2024.09） |
| G4 Verify（功能） | pass | [`../build/eda/evidence/g4_functional/summary.txt`](../build/eda/evidence/g4_functional/summary.txt)：12/12 参数化用例（VCS） |
| G5 配置空间 | not_run | 219 条配置已生成（mandatory 1 / boundary 28 / pairwise 147 / risk 2 / consumer 4 / negative 33），未跑矩阵回归 |
| G6 Characterize | blocked（OPTIONAL_UNAVAILABLE） | 本机无可提交标准单元库快照；PPA 为结构推理（PPA-E0），未伪造门级数据 |
| G7 Qualify / G8 Release | not_run | 未发布；`release/manifest.yaml` 为 candidate |

## 2. 已实现范围

- **双端点物理边界**：`parallel_data_fetch_requester`（仅 A 域）与 `parallel_data_fetch_provider`（仅 B 域）
  可独立集成；`parallel_data_fetch` 仅为同层封装。
- **链路单元**：`pdf_link_pipe`（同步长线同级 bundle 流水）、`pdf_async_fifo`（Gray 指针跨域 FIFO）、
  `pdf_sync_ff` / `pdf_alive_check`。
- **切片三实现**：`SLICE_IMPL=0/1/2`（shift/indexed/banked），同一可观察契约，仿真等价比对通过。
- **错误模型**：`ERR_TIMEOUT/PROVIDER/PARITY/PROTOCOL/REMOTE_RESET/FIFO/INTERNAL` 与优先级合并；
  失败结果输出 RESET_VALUE 语义值。
- **同步模式**：完整功能验证；异步模式提供结构实现与静态基线（elaboration 通过）。

## 3. 验证覆盖与统计（本轮）

- G3：wrapper 17 组参数化正向 + 端点独立 4 组；15 组负向参数由 `generate` 内 `$error` 在
  elaboration 期拒绝（工具非零退出 + 参数诊断）。
- G4：12 个参数化用例（默认 / BEAT_COUNT=1 / 非 2 次幂 9 / pipe1 / pipe8 / slice 三实现 /
  MSB-first / 奇校验 / 无校验 / 宽链路），每用例 52 事务、SVA 全程开启、`bubbles=0`。
- 事务类型：零等待/固定/随机 provider 延迟、长背压、provider error、parity 注入、复位。

## 4. 剩余风险与限制

| 风险 | 影响 | 处置 |
|---|---|---|
| 异步模式（ASYNC_MODE=1）未做定向/随机回归 | 跨域正确性仅有结构与 elaboration 证据（`profiles.yaml`: experimental） | 后续补双时钟 TB（A 快 B 慢 / A 慢 B 快 / 相异相位 / 时钟停摆 / 两端独立复位） |
| `pdf_async_fifo` 为构件内联同构实现 | 未复用 registry 中的 async_fifo（QUE-002 仍为 planned、无实现） | 待 QUE-002 通过 G3/G4 后改为 VLNS 依赖（见 profiles.yaml `implementation_notes`） |
| 无门级 PPA | 无法给出面积/时序/功耗实测（E0） | 在具备库上下文时由 `characterization/plan.yaml` 声明比较点后运行 G6 |
| 配置集抽样上限 | 13 参数采样域超出 config-gen 有界枚举（10000），未生成 `random` 集合 | 随机激励由 TB 内 `tc_random` 承担；已在 intake §7 与 config-inputs 记录 |
| G5/G7/G8 未执行 | 不能声明支持全配置域或发布资格 | 保持 development_candidate；不夸大支持域 |

## 5. 可复现入口

```bash
cd repos/aixsilicon_cbb_repo/components/interconnect/parallel_data_fetch
./verification/scripts/run_static_checks.sh      # G3（Compile/Elaboration/负向）
./verification/scripts/run_functional_sim.sh     # G4（参数化功能矩阵）
```

原始 EDA 日志与产物在 `build/eda/`（不入库）；本报告与 Gate 记录在 `reports/`。
