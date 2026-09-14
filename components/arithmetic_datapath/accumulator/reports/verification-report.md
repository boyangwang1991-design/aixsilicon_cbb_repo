# accumulator 验证报告（G3/G4）

> 本报告汇总 G3 静态基线与 G4 功能仿真证据（VCS W-2024.09-SP1）。
> 状态为 `needs_verification` 候选；仅 Workflow Gate 可确认 verified。

## 1. 验证形态

| 形态 | 内容 | 证据 |
|---|---|---|
| Simulation | 穷举 + 随机 + 边界 + 连续前缀和 + sticky 同拍优先级 + 隔离等价（黄金模型：独立无限精度算术） | build/eda/evidence/g4_functional/functional_sim.txt |
| Negative | 非法参数 elaboration `$error`（PC-001..008）逐 case 拦截 | build/eda/evidence/g3_static/negative_elab.txt |
| Static | 默认配置 VCS compile + elaboration | build/eda/evidence/g3_static/compile.txt |

## 2. 功能仿真结果（G4）

| 用例 | 覆盖需求 | 结果 |
|---|---|---|
| tc_reset | REQ-005 | PASS |
| tc_seq（连续前缀和） | REQ-001/004/005 | PASS |
| tc_exhaust_w8（128 步穷举） | REQ-001 | PASS |
| tc_edge（LOAD/WRAP/STCLR/SUB） | REQ-002/003 | PASS |
| tc_random（2000 周期） | REQ-001/002/003 | PASS |
| tc_sticky（同拍优先级 + idle event 清零） | REQ-003 | PASS |
| tc_continuous（停顿/恢复） | REQ-004 | PASS |
| tc_iso_equiv（OPERAND_ISOLATION=0/1） | REQ-007 | PASS |

**汇总**：`=== PASS: accumulator_tb checks=4393 errors=0 ===`

### 关键覆盖

- **连续前缀和**：每拍验证 `acc_o` 等于参考模型逐步结果（不只验最终总和，ACC-VER-007）。
- **WRAP 回绕**：LOAD 2147483640 后 +10 → 回绕 + sticky 置位（ACC-NUM-002）。
- **sticky 同拍优先级**：LOAD 近 max 后有效溢出与 status_clear 同拍 → sticky 置 1（新溢出优先，ACC-CTL-003）。
- **SUB 路径**：LOAD 20 后 -4 → 16（调研 §5.1 edge 7）。
- **隔离等价**：OPERAND_ISOLATION=0 vs 1 同输入序列 acc_o/event/sticky 逐拍一致（REQ-007）。

## 3. 负向校验结果（G3）

| case | 非法参数 | 期望 | 结果 |
|---|---|---|---|
| NEG_IW0 | INPUT_WIDTH=0 | PC-001 | PASS（报错拦截） |
| NEG_IW129 | INPUT_WIDTH=129 | PC-007 | PASS |
| NEG_AW0 | ACC_WIDTH=0 | PC-003 | PASS |
| NEG_AW257 | ACC_WIDTH=257 | PC-008 | PASS |
| NEG_IWGT | INPUT_WIDTH=32>ACC_WIDTH=16 | PC-002 | PASS |
| NEG_OP3 | OP_MODE=3 | PC-004 | PASS |
| NEG_OVF2 | OVERFLOW_MODE=2 | PC-005 | PASS |
| NEG_ISO2 | OPERAND_ISOLATION=2 | PC-006 | PASS |

全部非法参数在 elaboration 期 `$error` 拦截（非零退出 + PC 报错 ID），不以工具崩溃代替诊断。

## 4. 静态基线（G3）

- 默认配置（INPUT16/ACC32/signed/ADD_SUB/WRAP/LOAD/STATUS/no-iso）VCS compile + elaboration 通过，无 error/warning。

## 5. 结果解释与剩余风险

- 功能仿真覆盖默认位宽组合（16/32 signed）。其它位宽/OP_MODE/OVERFLOW_MODE 组合的数值语义由
  独立参考模型交叉验证（workflow/tmp/acc_verify.py 覆盖 WRAP/SAT/SUB/下溢），
  但未逐点跑 RTL 仿真 → **G5 配置空间覆盖率待扩展**。
- 未跑 Formal 证明（关键 SVA 内嵌于 RTL，但无独立 formal 引擎 run）；属性已定义。
- 未跑 PPA（G6）与资格（G7/G8）。
- 数值语义 bug（溢出漏检/饱和方向/下溢钳零）已在 G4 仿真回归中定位并修复，回归后全绿。

## 6. 复现

```bash
# 功能仿真（从 CBB 根目录）
bash verification/scripts/run_functional_sim.sh
# 静态 + 负向
bash verification/scripts/run_static_checks.sh
```

固定 seed=0x50002026；证据落盘 build/eda/evidence/{g3_static,g4_functional}/。
