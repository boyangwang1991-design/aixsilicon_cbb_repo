# incrementer_decrementer 资格报告（G7）

## 1. 支持矩阵

| 参数 | 值 | 状态 |
|---|---|---|
| `DATA_W` | 2..1024 | 支持（elab 矩阵 {8,16,32,64} 通过；其余由 PC-001/002 约束） |
| `ID_IMPL=0` ripple | 任意位宽 | 验证通过（G4） |
| `ID_IMPL=1` segmented | 任意位宽（SEG_W∈[2,16]） | 验证通过（G4） |
| `SEG_W` | 2..16 | 支持（elab 矩阵 {4,8} 通过；PC-004 约束） |
| inc/dec 互斥 | 仅单使能 | 行为假设 ASM-002（不同时断言）；TB 强制互斥 |
| 非法参数 | — | elaboration $error 拦截（PC-001..004，G3） |

## 2. Gate 证据

| Gate | 状态 | 证据 |
|---|---|---|
| G0 intake | ✅ | docs/intake.md |
| G1 spec | ✅ | docs/cbb_spec.md |
| G2 design | ✅ | docs/design.md + detail-design/{ripple,segmented}.md |
| G3 static | ✅ | build/eda/evidence/g3_static/{compile,negative_elab,lint}.txt |
| G4 functional | ✅ | build/eda/evidence/g4_functional/{functional_sim,mutation}.txt |
| G5 configs | ✅ | verification/configs/{mandatory,boundary,pairwise,negative}.yaml（check --strict 通过） |
| G6 PPA | ✅ | reports/ppa-report.md + build/eda/ppa/run-20260829-01/ |
| G7 qualification | candidate | 本文档 |
| G8 release | candidate | fusesoc core + registry + release/manifest.yaml |

## 3. 功能覆盖

- 穷举：W=8 全空间 256 向量 × 两实现 × {inc,dec,hold}（3 模式）= 1536 向量。
- 边界：全 0 / 全 1（溢出/借位 carry_out）/ 单 bit 逐位 inc/dec / 保持。
- 随机：4000 个 seed 向量 × W∈{8,16,32} × 两实现，黄金模型（独立算术）+ 跨实现等价。
- 负向：非法参数（DATA_W=1/1025、ID_IMPL=2、SEG_W=1/17）elaboration 拦截。
- 变异：借位传播条件写反，256/256 向量被黄金模型检测（checker 有效）。

## 4. 已知限制（Waiver / 计划）

1. **多 corner STA 未跑**：G6 目前 tt 单 corner；ss/ff 计划在后续 Gate 补。
2. **功耗为静态估计**：未加翻转率约束（toggle activity），动态功耗仅供相对比较。
3. **消费者 Smoke 未做**：跨 IP 实例化 smoke 计划。
4. **ripple 宽位宽时序**：O(W) 进位链在 >128 位宽时序差（详设已注明；建议 segmented）。
5. **无时钟/复位**：若下游需周期计数，应组合本构件与 CTL/MON 计数器。

## 5. 结论

- 成熟度：**E1**（Implemented + 单元验证）。G0–G6 通过，G7/G8 为 candidate。
- 建议后续：补 ss/ff corner、功耗翻转率约束、消费者 smoke 后晋升 E2。
