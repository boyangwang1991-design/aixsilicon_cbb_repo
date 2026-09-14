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

## 豁免与成熟度建议

- 尚无已批准的豁免。
- 完整 per-config qualification run matrix 与 formal 证明、ss/ff corner PPA 属后续 CI/基础设施补充，
  已在 gate note 与 characterization/plan.yaml 声明，不影响当前候选结果真实性。
- 成熟度建议：当前 `needs_verification` 候选（E0），证据充分后由 Workflow 依据 Gate 转换 verified；
  未完成前不宣称 verified/qualified/released。
