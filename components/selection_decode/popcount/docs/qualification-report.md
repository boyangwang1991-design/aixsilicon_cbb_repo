# popcount Qualification Report（G7 · candidate）

> 生成：2026-08-27；依据 cbb-development-suite qualify-cbb-release。
> 状态：**qualification_candidate（E2+）**——Workflow Gate 确认后方为 qualified/released。

## 1. 支持矩阵

| 参数域 | 支持状态 | 证据 |
|---|---|---|
| INPUT_WIDTH ∈ [4,256]（整数） | supported | G3 编译矩阵 18 点（含非 2 幂）+ G4 W∈{8,16,64} 黄金模型 |
| W=8 全输入空间 | supported | tc_exhaust_w8（256 向量穷举 × 三实现） |
| CHUNK_W ∈ [4,8]（仅 impl_lookup） | supported | PC-002 拦截 + 编译矩阵 |
| PC_IMPL ∈ {0,1,2} | {0:supported, 1:experimental, 2:supported} | LEC 两两互等 + PPA plan.yaml |
| 非法参数组合 | 在 elaboration 被拦截（不可综合/不可例化） | negative_w3/cw9.txt |

## 2. 已知限制

1. X 输入不承诺输出值（ASM-001）；SVA 仅对 2-state 有效；
2. `fmax_opt`（impl_column_compress 列计数递推形态）W≥64 时序违例、面积 ~10×，
   experimental——显式 FA 网表重测前不建议消费（plan.yaml 结论）;
3. `impl_lookup` 综合与 tree 趋同（case 表折叠），未提供独立 PPA 值；
4. PPA 证据等级 E2：单 corner（tt 1.00V 25C）、无物理感知；
5. 无 CDC/RDC/DFT 专项（纯组合原子构件，非目标）。

## 3. Waiver 记录

| 项 | 级别 | 理由 | 消解路径 |
|---|---|---|---|
| fmax_opt 支持状态 experimental | profile | G6 数据不优而非功能缺陷 | 显式 FA 形态 Change Plan 重测 |
| 多 corner 缺失 | E2 上探约束 | 单 tt corner 已满足发布候选门槛 | ss/ff sweep 后补 E3 |

## 4. 消费者 Smoke

- 定向验证已含三实现并行实例一致性比对（跨 impl 同拍观测，INV-003）；
- 正式 consumer smoke 待首个消费者 IP 接入时执行（未阻塞 release 候选）。

## 5. Gate 状态汇总

| Gate | 判定 | 核心证据 |
|---|---|---|
| G0 Intake | pass | docs/intake.md（CBB/A1、零重复、零依赖） |
| G1 Contract | pass | check PASS（strict 引用完整 PASS @G5 复核）+ RTM 9 条 |
| G2 Architecture | pass | profiles.yaml 三实现 + design.md 冻结稿评审通过 |
| G3 RTL Static | pass | compile 18/18 + 负向×2 + SpyGlass 0E/0W |
| G4 Functional | pass | exhaust_w8 256×3 + edge anchors + random3000 + LEC SUCCEEDED×2 + 变异检出 |
| G5 Config Space | pass | config-gen 4 组（1/12/2/4）+ check --strict 通过 |
| G6 PPA | pass | PDK_READY 真实综合 15 点（run-20260827-01）+ Pareto 结论 |
| G7 Qualification | pass（candidate） | 本报告 |
| G8 Release | pending → 候选产出见 release/manifest.yaml | Workflow Gate 最终确认 |

成熟度判定：**E2（Implemented + Verified）**，PPA E2 局部证据支持 → 达不到 E3
（缺消费者实测与多 corner 上探），登记于限制第 4 条。
