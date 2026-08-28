# Qualification Report（G7 候选）— fixed_priority_arbiter

> 状态：`qualification_candidate`（只有 Workflow Gate G7/G8 可确认 qualified/released）。

## 1. 支持矩阵（与真实验证矩阵一致）

| 参数/配置 | 支持值 | 验证状态 |
|---|---|---|
| NUM_REQ | 2..64（partitions 2/4/8/16/32/64） | 边界抽样（2/3/4/8/16/32/33/64）+ 随机全 N 已验（G4/G5） |
| PRIORITY | {0=LSB 优先, 1=MSB 优先} | G4 tc_priority/tc_exhaust_w4 穷举 + 黄金比对 |
| REQ_TYPE | {0=level, 1=latched} | G4 tc_latched（锁存/ack/清除时序） |
| FAST_GRANT | {0=组合, 1=寄存授权} | G4 tc_registered（1 拍延迟 + 组合参考一致） |
| PC_IMPL | {0=linear, 1=tree, 2=grouped} | G4 tc_equiv 三实现跨实现一致 + G6 综合收敛实证 |

## 2. Gate 证据完整性

| Gate | 结果 | 证据 |
|---|---|---|
| G0 Intake | pass | run_log：边界判定 A2、查重无重复、无嵌套依赖 |
| G1 Contract | pass | cbb.yaml/behavior.yaml Schema + 约束求值通过 |
| G2 Architecture | pass | profiles.yaml 5 Profile + 详设三文件（PPA 优化点/生成方式） |
| G3 RTL Static | pass | VCS 编译矩阵 18 点 + 负向 elab + SpyGlass lint 0F/0E（build/eda/evidence/g3_static/） |
| G4 Functional | pass | FPA_TB PASS（穷举+优先级+边界+随机2000×N64+等价+锁存+寄存） |
| G5 Config Space | pass | config-gen 14 配置 + RTM 16 条 + check --strict PASS |
| G6 PPA | pass | pdk-scan PDK_READY + DC sweep 15 点 + ppa-report.md（三实现收敛） |
| G7 Qualification | candidate | 本报告 |
| G8 Release | candidate | release/manifest.yaml |

## 3. Waiver 清单

| Waiver | Owner | 范围 | 风险 | 替代证据 | 失效条件 |
|---|---|---|---|---|---|
| 断言/=== 综合忽略（SYNTH_5064/5058） | rtl-owner | SVA immediate/concurrent 断言、`===` | 低（综合网表无断言） | G4 仿真断言触发验证 | 移除断言后复审 |
| 组合中间态断言误报规避（@(posedge clk) 采样） | rtl-owner | 组合关键不变量 | 低（黄金模型 TB 独立校验） | fpa_tb golden 比对 | 断言语义变更 |
| PPA 三实现综合收敛（无独立 Pareto 点） | rtl-owner | linear/tree/grouped | 低（多实现价值=代码清晰性） | ppa-report.md 诚实定性 | 综合策略变更 |

## 4. 成熟度判定

- 候选成熟度：**E2（Implemented + Verified）**；未达 E3 的缺口：消费者 Smoke（外部 IP 实例化回归）、
  FAST_GRANT=1 单独 PPA 表征、Multi-corner STA（当前单 corner tt_1p00v_25c）。
- 升级建议：首个外部消费者落地后进入 E3（Proven）。
