# popcount Intake（G0）

## 边界判定

- **目标**：人口统计/位计数（Population Count）：对 `DATA_W` 位输入返回 1 的个数。
- **抽象粒度**：A1（原子数据通路算子，纯组合、无状态、无时钟）。
- **技术域**：`selection_decode`（次：`arithmetic_datapath`）。

## 查重

| 候选 | 判定 | 说明 |
|---|---|---|
| `ARI-005 adder_tree` | 非目标 | 多操作数**加法**树（如乘法部分积归约），非位计数；本组件专注位向量计数。 |
| `ARI-003 carry_save_adder` | 非目标 | CSA 为乘法器等归约原语；popcount 可复用其思想（3:2/4:2 压缩）但不依赖。 |
| `CTL-*/MON-* counter` | 非目标 | 带时钟/事件的**周期计数/累加**，有状态；popcount 为纯组合单次计数。 |
| `ARI-001 incrementer_decrementer` | 非目标 | ±1 递增/递减，不同语义。 |

> 结论：`SEL-014 popcount` 在 registry 中为 planned 独立条目，无既有实现，物化本组件不重复。

## 消费者（预期）

- QoS/准入控制/流量统计中的 `$countones` 硬件化。
- 仲裁、缓存（行内有效位统计）、纠错（Hamming weight）等场景。
- 作为 adder_tree / compressor 教学与 PPA 基准构件。

## 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| Wallace/compressor 结构随位宽剧变 | 中 | 用生成器显式展开扁平网表（结构确定、可复现） |
| 生成器位宽集有限 | 低 | 当前 {8,16,32,64}；其余位宽回退 direct/tree/lut，PC-004 拦截 |
| 多实现 PPA 差异显著 | 低 | G6 综合 sweep 实证，profiles.yaml 记录推荐画像 |

## Gate 判定

- **G0 通过**：边界清晰、无重复、消费者明确、风险可控。
