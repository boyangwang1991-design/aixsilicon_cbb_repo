# accumulator 资格评估报告

状态：`candidate`（G0–G4 有证据；G5–G8 未执行）。资产成熟度：`E0`。

> 本报告为候选结果与证据索引，不构成已验证/已合格声明。只有 Workflow Gate 转换
> verified/qualified/released；PPA（G6）与资格（G7/G8）未执行，不宣称支持域。

## 支持矩阵

| 维度 | 覆盖 |
|---|---|
| 参数范围 | INPUT_WIDTH∈{1..128}、ACC_WIDTH∈{1..256}、SIGNED∈{T,F}、OP_MODE∈{0,1,2}、OVERFLOW_MODE∈{0,1}、LOAD_EN/STATUS_EN∈{T,F}、OPERAND_ISOLATION∈{0,1}（config-gen 生成 2+15+51+7 配置） |
| 已测配置（功能仿真） | 默认 16/32/signed/ADD_SUB/WRAP/LOAD/STATUS + OPERAND_ISOLATION{0,1} 隔离等价对 |
| 随机种子 | SEED=0x50002026（TB 固定） |
| 随机序列 | 2000 周期随机控制（空泡/正负/clear/load/status_clear） |
| 限制 | 功能仿真覆盖默认位宽组合；其余位宽/模式配置的数值语义由参考模型 + 负向拦截覆盖，未逐点跑 RTL 仿真 |

## 门禁证据

| 门禁 | 结果 | 证据 |
|---|---|---|
| G0 | pass（Intake 结论） | docs/intake.md、registry.yaml ARI-006 |
| G1 | pass（契约/RTM 校验） | check --phase specify --strict、trace/rtm.yaml |
| G2 | pass（架构/Profile） | docs/design.md、profiles.yaml |
| G3 | pass（编译/负向拦截） | build/eda/evidence/g3_static/compile.txt、negative_elab.txt（8/8 PC 报错） |
| G4 | pass（功能仿真） | build/eda/evidence/g4_functional/functional_sim.txt（4393 checks / 0 errors） |
| G5 | not_run（配置空间覆盖率待扩展） | — |
| G6 | not_run（PPA 未执行） | — |
| G7 | not_run | — |
| G8 | not_run | — |

## 验证汇总

- **功能仿真（G4）**：`verification/scripts/run_functional_sim.sh` → 穷举/随机/边界/连续前缀和/sticky 同拍优先级/隔离等价全 PASS。
- **负向校验（G3）**：`verification/scripts/run_negative_elab.sh` → 8 个非法参数 case 全部 elaboration `$error`（PC-001..008）拦截，非零退出 + 报错 ID。
- **静态基线（G3）**：`verification/scripts/run_static_checks.sh` → 默认配置 VCS compile/elaboration 通过。
- 数值语义（WRAP/SATURATE、上溢/下溢、sticky 优先级）经 Python 独立参考模型交叉验证。

## 豁免与成熟度建议

- 尚无已批准的豁免。
- 成熟度建议：当前为 `needs_verification` 候选（E0）。建议下一步执行 G5 配置空间扩展
  （按 boundary/pairwise 配置逐点跑 RTL 仿真）、G6 PPA 表征（目标库/约束下综合），
  由 Workflow 依据证据转换状态；未完成前不宣称 verified/qualified。
