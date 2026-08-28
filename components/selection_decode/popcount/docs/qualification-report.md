# popcount 资格报告（G7）

## 1. 支持矩阵

| 参数 | 值 | 状态 |
|---|---|---|
| `DATA_W` | 2..1024 | 支持（elab 矩阵 {8,16,32,64} 通过；其余由 PC-001/002 约束） |
| `PC_IMPL=0` direct | 任意位宽 | 验证通过（G4） |
| `PC_IMPL=1` tree | 任意位宽 | 验证通过（G4） |
| `PC_IMPL=2` wallace | {8,16,32,64} | 验证通过（G4）；其余位宽 PC-004 拦截 |
| `PC_IMPL=3` comp4_2 | {8,16,32,64} | 验证通过（G4）；其余位宽 PC-004 拦截 |
| `PC_IMPL=4` lut | 任意位宽 | 验证通过（G4） |
| 非法参数 | — | elaboration $error 拦截（PC-001..004，G3） |

## 2. Gate 证据

| Gate | 状态 | 证据 |
|---|---|---|
| G0 intake | ✅ | docs/intake.md |
| G1 spec | ✅ | docs/cbb_spec.md |
| G2 design | ✅ | docs/design.md + detail-design/ |
| G3 static | ✅ | build/eda/evidence/g3_static/{compile,negative_elab,lint}.txt |
| G4 functional | ✅ | build/eda/evidence/g4_functional/functional_sim.txt |
| G5 configs | candidate | verification/configs/mandatory.yaml |
| G6 PPA | candidate | reports/ppa-report.md + build/eda/ppa/run-20260828-01/ |
| G7 qualification | candidate | 本文档 |
| G8 release | candidate | fusesoc core + registry |

## 3. 功能覆盖

- 穷举：W=4 全空间 16 向量 × 五实现。
- 边界：全 0 / 全 1 / 单热逐位 / 0101 交错。
- 随机：4000 个 seed 向量 × W∈{8,16,32,64} × 各实现，黄金模型 + 跨实现等价。
- 负向：非法参数 elaboration 拦截。

## 4. 已知限制（Waiver / 计划）

1. **多 corner STA 未跑**：G6 目前 tt 单 corner；ss/ff 计划在后续 Gate 补。
2. **Wallace/compressor 位宽集受限**：生成器仅 {8,16,32,64}；更大位宽（128/256）
   需扩展 `tools/gen_popcount.py` 并更新 PC-004 与验证配置。
3. **收尾 ripple-carry 时序瓶颈**：Wallace/compressor 收尾可用 carry-lookahead 优化
   （prof_min_latency 关注项）。
4. **消费者 Smoke 未做**：跨 IP 实例化 smoke 计划。
5. **无时钟/复位**：若下游需周期计数，应组合本构件与 CTL/MON 计数器。

## 5. 结论

- 成熟度：**E1**（Implemented + 单元验证）。G3/G4 通过，G5–G8 为 candidate。
- 建议后续：补 ss/ff corner、扩展生成位宽、消费者 smoke 后晋升 E2。
