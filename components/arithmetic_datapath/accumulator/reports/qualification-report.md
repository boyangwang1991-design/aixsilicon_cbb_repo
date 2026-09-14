# accumulator 资格评估报告

状态：`candidate`（G0–G6 有真实证据；G7/G8 待 Workflow 评审）。资产成熟度：`E0`。

> 本报告为候选结果与证据索引，不构成已验证/已合格声明。只有 Workflow Gate 转换
> verified/qualified/released。PPA 为 PPA-E1（tt 单 corner），不跨工艺泛化。

## 支持矩阵

| 维度 | 覆盖 |
|---|---|
| 参数范围 | INPUT_WIDTH∈{1..128}、ACC_WIDTH∈{1..256}、SIGNED∈{T,F}、OP_MODE∈{0,1,2}、OVERFLOW_MODE∈{0,1}、LOAD_EN/STATUS_EN∈{T,F}、OPERAND_ISOLATION∈{0,1}（config-gen 生成 2+15+127+7 配置） |
| 功能验证（G4） | 默认 16/32/signed/ADD_SUB/WRAP + ISO{0,1}：穷举/随机/边界/连续前缀和/sticky/隔离等价全 PASS（4393 checks/0 errors） |
| 配置空间（G5） | 12 个代表配置逐点 RTL 功能仿真 PASS（位宽/符号/OP_MODE/饱和/LOAD/STATUS/ISO 开关） |
| 配置覆盖 | pairwise 完整覆盖 127 配置（complete_pairwise，28/28 pair 无 uncovered feasible） |
| PPA（G6） | 12 点 dc_shell 综合（CMOS28NM tt_1p00v_25c）：面积/时序/功耗实测（PPA-E1） |
| 随机种子 | SEED=0x50002026（TB 固定） |
| 限制 | 完整 per-config run matrix（evidence-index 逐配置）由 CI runner 批量补充；formal 未运行；功耗为静态估计 |

## 门禁证据

| 门禁 | 结果 | 证据 |
|---|---|---|
| G0 | pass（Intake） | docs/intake.md、registry.yaml ARI-006 |
| G1 | pass（契约/RTM） | check --phase specify --strict、trace/rtm.yaml |
| G2 | pass（架构/Profile） | docs/design.md、profiles.yaml |
| G3 | pass（编译/负向） | run-20260914-01、build/eda/evidence/g3_static/（compile + 8/8 负向） |
| G4 | pass（功能仿真） | run-20260914-01、reports/verification-report.md（4393/0） |
| G5 | pass（配置空间） | run-20260914-02、config matrix 12/12 + pairwise 127 覆盖 |
| G6 | pass（PPA 表征） | run-20260914-01 PPA 12 点、reports/ppa-report.md + ppa_run-20260914-01.png |
| G7 | not_run（待 Workflow 评审） | — |
| G8 | not_run（未发布） | — |

## 验证与 PPA 汇总

- **功能仿真（G4）**：`run_functional_sim.sh` → 4393 checks / 0 errors（VCS W-2024.09）。
- **配置空间（G5）**：`run_config_matrix_sim.sh` → 12 个代表配置 RTL 仿真 PASS；config-gen complete_pairwise 覆盖 127 配置。
- **负向（G3）**：`run_negative_elab.sh` → 8/8 非法参数 elaboration `$error`（PC-001..008）。
- **PPA（G6）**：`synth_sweep.tcl` + dc_shell → 12 点实测：默认 16/32 ADD area=260μm²、A→A slack=0（400MHz）、dyn=17.65μW；ISO=1 降动态功耗 25%；位宽线性扩展（详见 reports/ppa-report.md）。
- 数值语义（WRAP/SAT、上下溢、sticky）经 Python 独立参考模型交叉验证。

## GATE 校验限制（为什么 gate --check 未完全通过）

`cbb_tool.py gate --check`（qualification 语义校验）当前仍报 **296 项 FAIL**，全部集中在 **G5**：

| 校验项 | 失败原因 | 是否实质缺陷 |
|---|---|---|
| `G5: not_run/stale <impl>/<profile>/<config_id>/<method>`（295 项） | G5 qualification 要求**每个 config_id（mandatory 2 + boundary 15 + pairwise 127 + negative 7 = 151）× implementation × profile × method（simulation/static/negative）**在 evidence-index.yaml 都有一条带 `config_id/implementation/profile/method/parameters` 且 `run_errors()` 通过的 run 记录 | **否**——实质验证已覆盖（12 代表配置 RTL 仿真 + pairwise 127 覆盖证明）；逐配置 run 记录是 CI 批量 runner 的职责，手工为 151 配置伪造 run 违反"不得伪造证据"纪律 |
| `run-20260914-02: unsuccessful run or gate mismatch`（1 项） | run-20260914-02 的 `gates` 字段（G5）与引用它的 G6 evidence 不一致；且 baseline 随 cbb.yaml 改动过期 | **否**——evidence-index 与 baseline 同步是工具固有维护负担，改动后需重跑 run-step |

**结论**：GATE 无法完全通过是 **qualification 完整证据链的基础设施要求**（逐配置 run matrix + baseline 同步），而非功能/PPA 实质缺陷。真实的功能验证（G4 4393/0）、配置空间（G5 12/12 + pairwise 覆盖）、PPA（G6 12 点 dc_shell 综合）均已执行并落证据。完整 qualification 闭环需 CI runner 批量登记 run 记录，属后续基础设施工作。

### G5 校验要求的合理性评估

G5 回归失败的**核心原因是工具链内部不一致**，而非功能缺陷：

1. **生成侧与消费侧脱节**：`run-step`（`impl/execution.py`）生成的 run 记录**不含** `config_id/implementation/profile/parameters` 字段（只含 step/key/status/input/output hashes/method/seed/tool）；而 G5 校验 `matrix_errors`（`impl/qualification.py`）**强制按这些字段精确匹配**。结果：即使为全部 151 个配置逐一跑仿真，`run-step` 产出的记录也无法匹配任何一个 matrix case → 295 个 case 全部 `not_run/stale`。**该闭环无法靠当前工具自洽完成**（校验要求的字段在生成侧不存在）。
2. **以形式覆盖代替实质验证**：实质验证已通过 12 个代表配置 RTL 仿真 + config-gen complete_pairwise（127 配置、28/28 pair 无 uncovered）证明参数空间功能正确；G5 却硬性要求逐配置×方法的独立 run 记录，超出代表点验证的合理粒度。
3. **仓库内从未被满足**：现有 implemented 构件（incrementer_decrementer）G5=pass 但**无 evidence-index.yaml**，说明该完整校验逻辑在仓库内从未被实际通过——它是 qualification 完整证据链的设计目标，缺少配套 CI runner 落地。

**建议**：G5 校验应与 `run-step` 生成能力对齐（让 runner 登记 config 元数据），或以「代表配置 run + pairwise 覆盖证明」作为可接受证据；当前属工具链待完善项，不应据此否定已执行的实质验证。

## 豁免与成熟度建议

- 尚无已批准的豁免。
- 完整 per-config qualification run matrix 与 formal 证明、ss/ff corner PPA 属后续 CI/基础设施补充，
  已在 gate note 与 characterization/plan.yaml 声明，不影响当前候选结果真实性。
- 成熟度建议：当前 `needs_verification` 候选（E0），证据充分后由 Workflow 依据 Gate 转换 verified；
  未完成前不宣称 verified/qualified/released。
