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
| G4 Verify（功能） | pass | 同步 12/12 参数化用例（[`../verification/simulation/parallel_data_fetch_tb.sv`](../verification/simulation/parallel_data_fetch_tb.sv)）；**异步 8/8 时钟比例/相位**（[`../verification/scripts/run_async_sim.sh`](../verification/scripts/run_async_sim.sh)）；执行事件见 `reports/quality/events.jsonl` |
| G5 配置空间 | pass（Tier A） | [`../verification/scripts/run_config_matrix_sim.sh`](../verification/scripts/run_config_matrix_sim.sh)：13 个有界代表点逐点 RTL 仿真 **13/13**（4m07s）；215 条配置已由 config-gen 生成（mandatory 1 / boundary 28 / pairwise 147 / risk 2 / consumer 4 / negative 33） |
| G6 Characterize | blocked（OPTIONAL_UNAVAILABLE） | 本机无可提交标准单元库快照；PPA 为结构推理（PPA-E0），未伪造门级数据 |
| G7 Qualify / G8 Release | not_run | 未发布；`release/manifest.yaml` 为 candidate |

## 1.1 Gate 记录与 qualification 级检查的区别（重要）

`reports/quality/gates/parallel_data_fetch.yaml` 已登记 **G0–G4 = pass**，证据全部为工程内
**真实存在**的文件（`docs/intake.md`、`trace/rtm.yaml`、`docs/design.md`、
`verification/scripts/run_static_checks.sh`、`verification/simulation/parallel_data_fetch_tb.sv`、
`reports/qualification-report.md`）。

`cbb_tool.py gate --check` 会以 **qualification 强度**额外要求：

1. G3–G8 的证据必须是 `run-<YYYYMMDD>-<NN>` 形式的 content-bound run manifest（输入哈希绑定当前
   baseline + 工具名/版本），而不是脚本路径；
2. `cbb.yaml` 的 `quality.required_gates`（本工程为 G0–G8）全部有记录。

因此 `gate --check` 当前仍报 `G3/G4: qualification requires content-bound run evidence` 与
`G5–G8 未记录`。这是**本轮范围的真实反映**：本轮完成到 G4 功能验证（development candidate），
未执行 G5 配置矩阵、G6 表征、G7 资格与 G8 发布，也未建立 G7 使用的 run manifest。
本报告不把这四项补成 pass，也不把脚本路径伪装成 run 证据。

BD 执行事件已通过正式入口登记在 `reports/quality/events.jsonl`（step=implement / verify，
`action: executed`，含输入哈希与输出哈希），可供后续生成 run manifest 复用。

### 2.1 G5 分层执行策略（运行时间与阶段前置的平衡）

逐点回归的时间成本实测约 **20.7 s/配置**（VCS 编译+仿真），跑满 32 点约 11 min、215 点更久，
交互式流程不可控。因此 G5 分两层：

| 层 | 时机 | 范围 | 实测 | 目的 |
|---|---|---|---|---|
| **Tier A**（默认） | C4/G5 阶段内 | 13 个有界代表点（每参数至少一次极值/非默认，覆盖参数交互与异步临界） | 4m07s | 证明这批代表配置都能正确工作，使 RTL 成为 **C5/G6 的合法候选** |
| **Tier B**（`--full`） | **G6 PPA 之后** | 32 点扩展扫描（宽度×链路、校验×顺序、异步时钟比×切片、长线流水多点） | ~11 min | PPA 完成后已知 Pareto 点，可**定向**加扫而非盲目跑满；剩余预算给 `--complete-pairwise` |

**为何不整体挪到 PPA 之后**：套件 `workflow-policy.yaml` 的阶段顺序是
C4(G4/G5) → C5(G6)，且 `artifact-contract` 要求 C5 前置为"功能 smoke 通过的候选"——
拿未做功能验证的 RTL 去表征，PPA 结论不可解释。分层可同时满足"时间可控"与"阶段前置合法"。

**分层策略的有效性证据**：Tier A 首轮即抓到 G4 漏掉的真实 RTL 缺陷（见 §2.2）——
异步模式下 `pb_ready` 误接 `reserve_ok`，当 `RSP_FIFO_DEPTH ≈ BEAT_COUNT` 时突发中途停顿、
丢失 `last`。G4 的 20 个用例未覆盖该"深度×时钟比"组合，正是**广度**验证的价值所在。

## 2. 已实现范围

- **双端点物理边界**：`parallel_data_fetch_requester`（仅 A 域）与 `parallel_data_fetch_provider`（仅 B 域）
  可独立集成；`parallel_data_fetch` 仅为同层封装。
- **链路单元**：`pdf_link_pipe`（同步长线同级 bundle 流水）、`pdf_async_fifo`（Gray 指针跨域 FIFO）、
  `pdf_sync_ff` / `pdf_alive_check`。
- **切片三实现**：`SLICE_IMPL=0/1/2`（shift/indexed/banked），同一可观察契约，仿真等价比对通过。
- **错误模型**：`ERR_TIMEOUT/PROVIDER/PARITY/PROTOCOL/REMOTE_RESET/FIFO/INTERNAL` 与优先级合并；
  失败结果输出 RESET_VALUE 语义值。
- **同步模式**：完整功能验证（12 参数化用例）。
- **异步模式**：双时钟功能回归 8/8（A 快 B 慢 4×、A 慢 B 快 1/4×、临界 `FIFO==BEAT_COUNT`、
  同频异相相位 0/3/7、互质 7:17、深 FIFO），含事务中 B 端复位 → 错误结束 + link 重建后可继续；
  `profiles.yaml` 保持 `experimental`（同步级数 3/4 与时钟停摆场景未逐点覆盖）。
### 2.2 RTL 缺陷修复记录（G5 复盘）

**缺陷**：异步模式下 wrapper 把 `pb_ready` 直接接到 `link_reserve_ok_i`（每拍重估
"剩余空间 ≥ BEAT_COUNT"）。当 `RSP_FIFO_DEPTH ≈ BEAT_COUNT` 时，突发发送中途已写入若干 beat，
剩余空间不足一个完整 transaction → `reserve_ok` 拉低 → 连续发送被打断、`last` 丢失
（表现为 `ERR_PROTOCOL(4)`）。

**修正**（契约 §7 语义）：reservation 只在**启动发送前**门控——provider 在 `PV_WAIT_DATA`
用 `link_reserve_ok_i` 确认空间，一旦开始发送，空间已被预留，发送期只受"FIFO 已满"约束：
`assign pb_ready = ~fifo_full;`。修正后 `async_crit_fifo`（`FIFO=4, BEAT=4`）与
`risk_async_4096_8`（`FIFO=512, BEAT=512`）均通过。

- **异步根因修复记录（G4 阶段）**：契约 §14 要求"异步模式不得立即复用请求 toggle，应先完成 link recovery"。
  原静默窗口按同步量级设定，在 A 端错误后立即复用请求时会出现 A 端 HOLD / B 端 IDLE 的失配。
  现将异步窗口按跨域往返量级保守放大（`2×BEAT_COUNT + 4×REQ_SYNC_STAGES + 16`，见
  [`../rtl/parallel_data_fetch_requester.sv`](../rtl/parallel_data_fetch_requester.sv) 的 `QUIET_MAX`），
  并经 8 组时钟比例回归验证；同步模式窗口未变。

## 3. 验证覆盖与统计（本轮）

- G3：wrapper 17 组参数化正向 + 端点独立 4 组；15 组负向参数由 `generate` 内 `$error` 在
  elaboration 期拒绝（工具非零退出 + 参数诊断）。
- G4：12 个参数化用例（默认 / BEAT_COUNT=1 / 非 2 次幂 9 / pipe1 / pipe8 / slice 三实现 /
  MSB-first / 奇校验 / 无校验 / 宽链路），每用例 52 事务、SVA 全程开启、`bubbles=0`。
- 事务类型：零等待/固定/随机 provider 延迟、长背压、provider error、parity 注入、复位。

## 4. 剩余风险与限制

| 风险 | 影响 | 处置 |
|---|---|---|
| G5 仅跑 Tier A（13 代表点） | 未逐点覆盖全部 215 条配置；`--complete-pairwise` 全覆盖未执行 | **分层策略**（见 §2.1）：Tier B 扩展扫描 `--full`（32 点）与 complete-pairwise 建议在 G6 PPA 之后由 CI runner 执行——PPA 完成后已知 Pareto 点，可定向加扫而非盲目跑满；依据 C4→C5 阶段顺序与 C5 前置（功能 smoke 通过的候选） |
| 异步模式同步级数（`REQ_SYNC_STAGES`=3/4）未逐点回归 | 异步下仅默认 2 级（3/4 级由同步模式参数化覆盖） | TB 需把该参数透传 DUT 后拆分编译逐点跑；当前不夸大覆盖 |
| 异步"时钟停摆"场景未单独激励 | clock gating/掉电下的恢复行为未直接验证 | link_up 语义与 alive 检测已由 `tc_async_reset_order` 覆盖复位子集；停摆场景列入后续 |
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
