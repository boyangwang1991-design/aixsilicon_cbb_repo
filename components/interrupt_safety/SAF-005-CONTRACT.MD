# Lockstep Comparator Logic CBB — Logic Requirement Specification

> **CBB Name**: `lockstep_comparator_logic`
> **简称**: LCL（Lockstep Comparator Logic）
> **Category**: Functional Safety / Redundancy / Lockstep
> **Type**: Parameterized CBB
> **Target Version**: `1.0.0`
> **Status**: Draft / Implementation Baseline
> **Purpose**: 对 Main / Shadow 两路锁步逻辑的关键输出进行时间对齐、一致性比较和故障检测，同时对 Comparator Logic 自身提供冗余及诊断能力。

---

# 1. Scope

LCL 用于双路 Lockstep 架构：

```text
Main Logic
Shadow Logic
```

之间的一致性监控。

LCL shall 完成：

1. Main / Shadow 输出比较；
2. Lockstep temporal delay；
3. Reset / startup alignment；
4. Static / runtime signal masking；
5. Valid gating；
6. 实时 mismatch detection；
7. Sticky fault capture；
8. LCL Comparator 自身冗余；
9. Comparator redundancy cross-check；
10. LCL internal fault detection；
11. Fault injection；
12. 基础 self-test 支撑。

LCL 不负责：

* Main / Shadow 功能运算；
* Majority Voting；
* Safe-state 决策；
* Safety Manager / SMU；
* System reset generation；
* Clock generation；
* 软件寄存器；
* Interrupt controller。

---

# 2. Safety Architecture

推荐 V1.0 默认结构：

```text
                         Main Logic
                             |
                             |
               +-------------+-------------+
               |                           |
          Delay Path A                 Delay Path B
               |                           |
               v                           v
         +-----------+               +-----------+
         | Compare A |               | Compare B |
         +-----+-----+               +-----+-----+
               |                           |
           cmp_a_fault                 cmp_b_fault
               |                           |
               +-------------+-------------+
                             |
                     +-------+-------+
                     | Result Checker|
                     +-------+-------+
                             |
              +--------------+---------------+
              |                              |
     main_shadow_mismatch             lcl_internal_fault
              |                              |
              +--------------+---------------+
                             |
                       safety_fault
```

Shadow 默认直接送入两个 comparator：

```text
Shadow
 ├── Compare A
 └── Compare B
```

完整冗余模式下 Main temporal delay 也采用两份独立路径：

```text
Main
 ├── Delay A → Compare A
 └── Delay B → Compare B
```

---

# 3. 核心安全原则

## LCL-SAFE-001 — Fail-Safe Detection

单个 Comparator Path 的故障不得导致有效 Main / Shadow mismatch 被完全屏蔽。

因此最终 Main / Shadow fault 推荐采用：

```systemverilog
main_shadow_mismatch =
    cmp_a_mismatch |
    cmp_b_mismatch;
```

不得使用：

```systemverilog
cmp_a_mismatch &
cmp_b_mismatch;
```

作为唯一错误输出。

---

## LCL-SAFE-002 — LCL Internal Fault

Comparator A 和 Comparator B 对同一比较输入产生不同判断时，应报告：

```text
LCL_INTERNAL_FAULT
```

推荐：

```systemverilog
lcl_internal_fault =
    cmp_a_mismatch ^
    cmp_b_mismatch;
```

---

## LCL-SAFE-003 — Safety Fault

系统级安全故障输出应至少包含：

```systemverilog
safety_fault =
      main_shadow_mismatch
    | lcl_internal_fault;
```

---

# 4. Parameter Requirements

## LCL-PARAM-001 — WIDTH

```systemverilog
parameter int unsigned WIDTH = 32;
```

约束：

```text
WIDTH >= 1
```

---

## LCL-PARAM-002 — LOCKSTEP_DELAY

```systemverilog
parameter int unsigned LOCKSTEP_DELAY = 2;
```

定义：

```text
0 : 同周期比较
1 : Main 延迟1周期
2 : Main 延迟2周期
N : Main 延迟N周期
```

比较关系：

```text
main(t - LOCKSTEP_DELAY)
        VS
shadow(t)
```

---

## LCL-PARAM-003 — STARTUP_GUARD_CYCLES

```systemverilog
parameter int unsigned STARTUP_GUARD_CYCLES = 0;
```

用于 temporal delay pipeline ready 后额外延迟比较启动。

---

## LCL-PARAM-004 — CMP_PIPE_STAGES

```systemverilog
parameter int unsigned CMP_PIPE_STAGES = 0;
```

V1.0 至少支持：

```text
0 / 1
```

其含义为 comparator datapath 自身输出流水。

必须与：

```text
LOCKSTEP_DELAY
```

区分。

---

## LCL-PARAM-005 — STATIC_COMPARE_MASK

```systemverilog
parameter logic [WIDTH-1:0]
    STATIC_COMPARE_MASK = '1;
```

定义：

```text
1 = compare
0 = ignore
```

---

## LCL-PARAM-006 — Redundancy Level

建议支持：

```systemverilog
parameter int unsigned LCL_REDUNDANCY_LEVEL = 2;
```

定义：

### Level 0

单 comparator：

```text
Main Delay → Compare
```

用于：

* 非安全场景；
* Debug；
* 低等级诊断场景。

---

### Level 1

共享 delay，Comparator 双冗余：

```text
                 ┌→ Compare A
Main → Delay ----|
                 └→ Compare B
```

检测 comparator core 故障。

---

### Level 2

完整 LCL datapath 双冗余：

```text
Main ─→ Delay A → Compare A
    └→ Delay B → Compare B
```

推荐作为 FuSa 应用默认配置。

---

# 5. Recommended Interface

```systemverilog
module lockstep_comparator_logic #(
    parameter int unsigned WIDTH = 32,

    parameter int unsigned LOCKSTEP_DELAY = 2,
    parameter int unsigned STARTUP_GUARD_CYCLES = 0,
    parameter int unsigned CMP_PIPE_STAGES = 0,

    parameter int unsigned LCL_REDUNDANCY_LEVEL = 2,

    parameter logic [WIDTH-1:0]
        STATIC_COMPARE_MASK = '1,

    parameter bit SUPPORT_RUNTIME_MASK = 1'b1,
    parameter bit SUPPORT_VALID_MASK = 1'b1,
    parameter bit SUPPORT_FAULT_INJECTION = 1'b1

)(
    input logic clk_i,
    input logic rst_ni,

    // Functional lockstep inputs
    input logic [WIDTH-1:0] main_i,
    input logic [WIDTH-1:0] shadow_i,

    // Compare control
    input logic compare_enable_i,

    input logic main_active_i,
    input logic shadow_active_i,

    // Signal qualification
    input logic [WIDTH-1:0] runtime_mask_i,
    input logic [WIDTH-1:0] valid_mask_i,

    // Fault control
    input logic error_clear_i,

    // Fault injection
    input logic fi_enable_i,
    input logic [1:0] fi_target_i,
    input logic [WIDTH-1:0] fi_mask_i,

    // Alignment
    output logic alignment_valid_o,

    // Main/Shadow status
    output logic main_shadow_mismatch_o,
    output logic main_shadow_mismatch_pulse_o,
    output logic main_shadow_mismatch_latched_o,

    // LCL status
    output logic lcl_internal_fault_o,
    output logic lcl_internal_fault_latched_o,

    // Detailed diagnostic
    output logic [WIDTH-1:0] mismatch_vector_o,
    output logic [WIDTH-1:0] mismatch_vector_sticky_o,

    // Summary
    output logic safety_fault_o
);
```

---

# 6. Temporal Alignment Requirements

## LCL-ALIGN-001 — Main Delay

当：

```text
LOCKSTEP_DELAY > 0
```

时，Main path shall 延迟指定周期。

例如：

```text
LOCKSTEP_DELAY = 2
```

则：

```text
main_aligned(t) = main_i(t-2)
```

---

## LCL-ALIGN-002 — Zero Delay

当：

```text
LOCKSTEP_DELAY = 0
```

时：

```text
main_aligned = main_i
```

不得产生无意义 delay registers。

---

## LCL-ALIGN-003 — Independent Delay Paths

当：

```text
LCL_REDUNDANCY_LEVEL = 2
```

时：

```text
Delay A
Delay B
```

shall 使用独立状态存储。

不得直接：

```text
Delay A output
```

复制给 Compare B。

---

# 7. Reset / Startup Requirements

## LCL-RST-001 — Reset Suppression

`rst_ni=0` 时，普通 Main / Shadow 功能比较必须关闭。

要求：

```text
main_shadow_mismatch_o       = 0
main_shadow_mismatch_pulse_o = 0
alignment_valid_o            = 0
```

---

## LCL-RST-002 — Delay Pipeline Initialization

Reset 后所有 temporal delay pipeline valid 状态必须重新初始化。

不得直接将未填充 pipeline 的数据参与比较。

---

## LCL-RST-003 — Alignment Window

Reset deassert 后必须等待：

```text
LOCKSTEP_DELAY
+
STARTUP_GUARD_CYCLES
```

完成后才允许进入有效比较状态。

---

## LCL-RST-004 — Alignment Valid

LCL shall 输出：

```systemverilog
alignment_valid_o
```

表示：

> LCL 已完成 Main / Shadow 时间关系初始化，当前数据具备比较条件。

---

## LCL-RST-005 — Active Qualification

实际比较使能至少应满足：

```systemverilog
compare_active =
       rst_ni
     & alignment_valid
     & compare_enable_i
     & main_active_i
     & shadow_active_i;
```

---

## LCL-RST-006 — Reset During ACTIVE

ACTIVE 工作期间重新进入 reset 时：

```text
comparison
```

必须立即停止。

Alignment 状态重新失效。

下一次 reset release 后必须重新执行 alignment。

---

# 8. Reset Consistency Boundary

普通 Functional Comparator 在 reset window 中应关闭。

但以下内容不应因此被认为“不需要检测”：

```text
Main reset state
Shadow reset state
Clock enable
Sleep state
Power state
Debug state
Lockstep enable
```

如果系统安全架构要求对这些信号检测，应建立：

```text
Independent control consistency checker
```

或独立 LCL channel。

不得因为 functional comparison reset mask 而永久屏蔽这些安全相关控制信号。

---

# 9. Static Mask

## LCL-MASK-001

对于：

```text
STATIC_COMPARE_MASK[n] = 0
```

对应 bit shall 永久不参与比较。

---

## LCL-MASK-002

即使：

```text
main[n] != shadow[n]
```

被静态 mask 的 bit 也不得产生 mismatch。

---

## LCL-MASK-003

静态 mask 应能够在综合阶段裁剪对应比较逻辑。

---

# 10. Runtime Mask

## LCL-MASK-004

当：

```text
SUPPORT_RUNTIME_MASK = 1
```

时：

```text
runtime_mask_i[n] = 1
```

表示参与比较。

```text
runtime_mask_i[n] = 0
```

表示临时屏蔽。

---

## LCL-MASK-005

Runtime mask 主要用于：

* Debug mode；
* 模式切换；
* 动态关闭特定 output；
* temporarily undefined signals；
* power transition；
* system startup sequence。

---

# 11. Valid Mask

## LCL-VALID-001

当：

```text
SUPPORT_VALID_MASK = 1
```

时：

```text
valid_mask_i[n] = 1
```

表示当前 bit 有功能语义。

---

## LCL-VALID-002

如果：

```text
valid_mask_i[n] = 0
```

则对应数据差异不得产生 mismatch。

---

## LCL-VALID-003

建议：

```systemverilog
effective_mask =
      STATIC_COMPARE_MASK
    & runtime_mask
    & valid_mask;
```

---

# 12. Comparator Path A/B

## LCL-CMP-001 — Independent Comparison

Comparator A/B shall 独立产生：

```text
cmp_a_mismatch
cmp_b_mismatch
```

---

## LCL-CMP-002 — Bitwise Difference

逻辑应等价：

```systemverilog
diff_a =
    (main_a ^ shadow_a)
    & effective_mask_a;

diff_b =
    (main_b ^ shadow_b)
    & effective_mask_b;
```

---

## LCL-CMP-003 — Reduction

```systemverilog
cmp_a_mismatch = |diff_a;
cmp_b_mismatch = |diff_b;
```

---

## LCL-CMP-004 — Redundant Logic Independence

在冗余配置下，两份 comparator shall 不共享会导致单点故障同时屏蔽两路检测结果的关键组合节点或状态节点。

---

# 13. Main / Shadow Mismatch

## LCL-ERR-001

在双 comparator 模式：

```systemverilog
main_shadow_mismatch_o =
    cmp_a_mismatch |
    cmp_b_mismatch;
```

---

## LCL-ERR-002

当任意有效 comparator path 检测到 Main / Shadow divergence 时，应产生 Main / Shadow mismatch。

---

## LCL-ERR-003

单 Comparator Path stuck-at-0 不得导致真实 Main / Shadow divergence 完全无法报告。

---

# 14. LCL Internal Fault Detection

## LCL-SELF-001

当：

```text
cmp_a_mismatch != cmp_b_mismatch
```

时：

```text
lcl_internal_fault_o = 1
```

---

## LCL-SELF-002

推荐：

```systemverilog
lcl_internal_fault_o =
    cmp_a_mismatch ^
    cmp_b_mismatch;
```

---

## LCL-SELF-003

`lcl_internal_fault_o` 与 `main_shadow_mismatch_o` 必须为不同 fault class。

原因：

```text
main_shadow_mismatch
```

表示被保护逻辑可能发生 divergence；

```text
lcl_internal_fault
```

表示 Lockstep Safety Mechanism 自身可能失效。

---

# 15. Fail-Safe Fault Combination

## LCL-SAFE-004

最终：

```systemverilog
safety_fault_o =
      main_shadow_mismatch_o
    | lcl_internal_fault_o;
```

---

## LCL-SAFE-005

当出现：

```text
CMP-A = mismatch
CMP-B = match
```

时必须：

```text
main_shadow_mismatch_o = 1
lcl_internal_fault_o   = 1
safety_fault_o         = 1
```

不得等待两套 comparator 同时确认后才报告安全错误。

---

# 16. Mismatch Vector

## LCL-DIAG-001

LCL shall 提供：

```systemverilog
mismatch_vector_o[WIDTH-1:0]
```

用于标识发生差异的具体 bit。

---

## LCL-DIAG-002

推荐 mismatch vector 输出采用：

```text
A/B comparator mismatch vectors OR
```

即：

```systemverilog
mismatch_vector_o =
    diff_a |
    diff_b;
```

这样任一路检测到的差异均保留。

---

# 17. Sticky Fault

## LCL-STICKY-001

Main / Shadow mismatch 一旦产生：

```text
main_shadow_mismatch_latched_o
```

必须保持至显式清除。

---

## LCL-STICKY-002

LCL internal fault 一旦产生：

```text
lcl_internal_fault_latched_o
```

必须保持至显式清除。

---

## LCL-STICKY-003

不得因为后续 Comparator A/B 再次一致而自动清除历史 LCL fault。

---

# 18. Sticky Mismatch Vector

## LCL-STICKY-004

LCL shall 支持：

```systemverilog
mismatch_vector_sticky_o
```

推荐：

```systemverilog
sticky_next =
    sticky_current |
    mismatch_vector_o;
```

---

# 19. Error Clear

## LCL-CTRL-001

`error_clear_i` 用于清除：

```text
main_shadow_mismatch_latched_o
lcl_internal_fault_latched_o
mismatch_vector_sticky_o
```

---

## LCL-CTRL-002

`error_clear_i` 不应：

* 清空 temporal alignment；
* 修改 delay pipeline；
* 修改 compare_enable；
* 修改 Main / Shadow functional state。

---

# 20. Reset 与 Sticky Fault

系统集成时应区分：

```text
Cold Reset / POR
Warm Reset
LCL Local Reset
```

推荐：

### Cold Reset

可以清除所有 sticky safety status。

### Warm Reset

默认不建议自动清除历史安全故障。

### Error Clear

由 Safety Manager / software 显式清除。

其目的为防止：

```text
lockstep fault
→ warm reset
→ fault status simultaneously erased
```

导致 post-mortem 信息丢失。

具体 reset-domain 策略可以由上层 wrapper 决定。

---

# 21. Mismatch Pulse

## LCL-EVENT-001

shall 提供：

```systemverilog
main_shadow_mismatch_pulse_o
```

表示新 Main / Shadow mismatch event。

推荐：

```systemverilog
main_shadow_mismatch_pulse =
      main_shadow_mismatch
    & ~main_shadow_mismatch_latched;
```

---

# 22. Fault Injection

## LCL-FI-001

当：

```text
SUPPORT_FAULT_INJECTION = 1
```

时，应支持向 LCL 内部不同位置注入 fault。

建议目标：

```text
FI_NONE
FI_COMPARE_A
FI_COMPARE_B
FI_DELAY_A
FI_DELAY_B
```

---

## LCL-FI-002 — Compare A Injection

只向 Comparator A datapath 注入错误时：

```text
cmp_a_mismatch != cmp_b_mismatch
```

应至少触发：

```text
lcl_internal_fault
```

---

## LCL-FI-003 — Compare B Injection

行为与 Comparator A 对称。

---

## LCL-FI-004 — Delay Path Injection

Level 2 模式下，应允许对：

```text
Delay A
Delay B
```

分别进行 fault injection。

用于验证完整 LCL datapath 的诊断能力。

---

## LCL-FI-005 — Normal Datapath

Fault injection 不得仅通过：

```text
force safety_fault = 1
```

实现。

必须尽量通过实际：

```text
delay
comparison
reduction
cross-check
sticky logic
```

路径传播。

---

# 23. Comparator Self-Test Support

LCL V1.0 shall 至少提供 fault injection 基础能力，用于系统执行：

```text
startup self-test
```

或：

```text
periodic diagnostic test
```

典型流程：

```text
Inject Comparator A
        ↓
Comparator A reports error
        ↓
Comparator A/B disagreement
        ↓
LCL internal fault
        ↓
Safety Manager observes event
```

随后：

```text
clear
```

并对 Comparator B 重复测试。

---

# 24. Comparator Common-Cause Consideration

两套 Comparator 使用完全相同 RTL 时，可提高随机硬件故障检测能力，但不能完全解决 Common Cause Failure。

因此 physical implementation shall 考虑：

* A/B logic placement separation；
* 避免同一局部 physical fault 同时影响 A/B；
* 独立关键 logic cone；
* 必要的 synthesis optimization barrier；
* 避免 redundant logic merge；
* 避免 retiming 跨越冗余边界；
* 避免 register merging。

---

# 25. Optional Diverse Implementation

V1.0 不强制 Comparator A/B 使用不同算法实现。

但 architecture should 保留未来支持 diversity 的可能，例如：

### Path A

```text
XOR
→ mask
→ OR reduction
```

### Path B

```text
XNOR
→ masked equality
→ AND reduction
→ invert
```

两者逻辑功能等价，但逻辑结构不同。

该能力建议作为后续增强，不作为 V1.0 mandatory implementation。

---

# 26. X / Z Simulation Requirements

## LCL-SIM-001

仿真环境应对 Main / Shadow 比较数据中的：

```text
X
Z
```

进行检查。

---

## LCL-SIM-002

原则：

> Unknown state 不应因为 Main 和 Shadow 同时为 X 而默认视作安全一致。

---

## LCL-SIM-003

X/Z detection 推荐通过：

* SVA；
* simulation checker；
* `$isunknown()`；

实现，不要求映射成硬件逻辑。

---

# 27. PPA Requirements

## LCL-PPA-001

当：

```text
STATIC_COMPARE_MASK[n] = 0
```

时，相应比较逻辑应允许综合裁剪。

---

## LCL-PPA-002

当：

```text
LOCKSTEP_DELAY = 0
```

时，delay registers 必须裁剪。

---

## LCL-PPA-003

当：

```text
LCL_REDUNDANCY_LEVEL = 0
```

时，所有 Comparator B 及 redundancy checker logic 必须裁剪。

---

## LCL-PPA-004

当：

```text
LCL_REDUNDANCY_LEVEL = 1
```

时，不应实现第二套 Main delay pipeline。

---

## LCL-PPA-005

当：

```text
LCL_REDUNDANCY_LEVEL = 2
```

时，应分别构建：

```text
Delay A
Delay B
```

---

## LCL-PPA-006

当 WIDTH 较大时，应允许：

```text
CMP_PIPE_STAGES = 1
```

切断：

```text
wide XOR
→ mask
→ reduction OR
→ status
```

形成的长组合路径。

---

# 28. Functional Output Independence

LCL 不得位于 Main functional output 的主功能路径中。

推荐：

```text
Main ----------------------→ System
    \
     → LCL
    /
Shadow
```

而非：

```text
Main ----\
          LCL ----→ Functional Output
Shadow --/
```

除非上层明确实现 voting 或 fail-safe gating。

---

# 29. Recommended Internal State Machine

建议状态：

```text
RESET
  |
  v
ALIGN_WAIT
  |
  v
ACTIVE
```

## RESET

* functional comparison disabled；
* alignment invalid；
* pipeline 初始化。

## ALIGN_WAIT

* delay pipeline shift；
* 不报告 functional mismatch；
* 等待 alignment 完成。

## ACTIVE

* 正常执行 comparison；
* mask 生效；
* valid 生效；
* redundancy cross-check 生效。

---

# 30. Core Logic Reference

核心行为可近似：

```systemverilog
main_a_aligned =
    delay_a(main_i, LOCKSTEP_DELAY);

main_b_aligned =
    delay_b(main_i, LOCKSTEP_DELAY);

compare_active =
       rst_ni
     & alignment_valid
     & compare_enable_i
     & main_active_i
     & shadow_active_i;

effective_mask =
      STATIC_COMPARE_MASK
    & runtime_mask
    & valid_mask;

diff_a =
    compare_active
    ? ((main_a_cmp ^ shadow_i) & effective_mask)
    : '0;

diff_b =
    compare_active
    ? ((main_b_cmp ^ shadow_i) & effective_mask)
    : '0;

cmp_a_mismatch = |diff_a;
cmp_b_mismatch = |diff_b;

main_shadow_mismatch =
    cmp_a_mismatch |
    cmp_b_mismatch;

lcl_internal_fault =
    cmp_a_mismatch ^
    cmp_b_mismatch;

safety_fault =
    main_shadow_mismatch |
    lcl_internal_fault;
```

---

# 31. Priority Feature Matrix

| ID      | Feature                             |  V1.0 Priority |
| ------- | ----------------------------------- | -------------: |
| LCL-001 | Main / Shadow compare               |             P0 |
| LCL-002 | Parameterized WIDTH                 |             P0 |
| LCL-003 | 0~N temporal delay                  |             P0 |
| LCL-004 | Default 2-cycle delay support       |             P0 |
| LCL-005 | Static signal mask                  |             P0 |
| LCL-006 | Runtime signal mask                 |             P0 |
| LCL-007 | Valid mask                          |             P0 |
| LCL-008 | Compare enable                      |             P0 |
| LCL-009 | Main / Shadow active gating         |             P0 |
| LCL-010 | Reset suppression                   |             P0 |
| LCL-011 | Startup alignment                   |             P0 |
| LCL-012 | Alignment valid                     |             P0 |
| LCL-013 | Mismatch vector                     |             P0 |
| LCL-014 | Main/Shadow sticky fault            |             P0 |
| LCL-015 | Sticky vector                       |             P0 |
| LCL-016 | Explicit error clear                |             P0 |
| LCL-017 | Comparator dual redundancy          |         **P0** |
| LCL-018 | LCL internal fault detection        |         **P0** |
| LCL-019 | Fail-safe OR fault aggregation      |         **P0** |
| LCL-020 | Comparator A/B fault injection      |         **P0** |
| LCL-021 | Delay A/B independent path          | P0 for Level 2 |
| LCL-022 | X/Z simulation checker              |             P0 |
| LCL-023 | Comparator output pipeline          |             P1 |
| LCL-024 | Startup guard cycles                |             P1 |
| LCL-025 | Diverse comparator implementation   |             P2 |
| LCL-026 | Autonomous background self-test FSM |             P2 |

---

# 32. Mandatory Corner Cases

实现及验证至少覆盖以下场景。

## CC-001 Normal Match

```text
Main == Shadow
```

结果：

```text
main_shadow_mismatch = 0
lcl_internal_fault   = 0
```

---

## CC-002 Main / Shadow Divergence

A/B 两个 Comparator 均发现差异：

```text
CMP-A = 1
CMP-B = 1
```

结果：

```text
main_shadow_mismatch = 1
lcl_internal_fault   = 0
```

---

## CC-003 Comparator A Fault

```text
CMP-A = 1
CMP-B = 0
```

结果：

```text
main_shadow_mismatch = 1
lcl_internal_fault   = 1
safety_fault         = 1
```

---

## CC-004 Comparator B Fault

```text
CMP-A = 0
CMP-B = 1
```

结果相同：

```text
main_shadow_mismatch = 1
lcl_internal_fault   = 1
```

---

## CC-005 Reset

Reset 中 Main / Shadow 不一致：

```text
functional mismatch = suppressed
```

不得误报警。

---

## CC-006 Reset Release Alignment

Pipeline 未填满：

```text
alignment_valid = 0
mismatch        = 0
```

---

## CC-007 Masked Difference

Main / Shadow 在被 Mask bit 不同：

```text
mismatch = 0
```

---

## CC-008 Invalid Difference

对应：

```text
valid_mask = 0
```

的数据不同：

```text
mismatch = 0
```

---

## CC-009 Single Comparator Injection

只向 Comparator A 注入故障：

```text
lcl_internal_fault = 1
```

---

## CC-010 Delay-A Injection

Level 2 模式中只破坏 Delay A：

Comparator A/B 应发生 disagreement 或有效安全错误。

不得 silent fail。

---

## CC-011 Sticky

瞬态 fault 消失后：

```text
live fault   = 0
sticky fault = 1
```

---

## CC-012 Clear

明确执行：

```text
error_clear
```

后 sticky status 清零。

---

# 33. Implementation Decomposition

建议 RTL 拆分：

```text
lockstep_comparator_logic
│
├── lockstep_delay_path_a
│
├── lockstep_delay_path_b
│
├── lockstep_compare_unit_a
│
├── lockstep_compare_unit_b
│
├── lockstep_result_checker
│
├── lockstep_fault_latch
│
└── lockstep_fault_injection
```

其中真正值得独立做成底层 CBB 的可以只有：

```text
lockstep_compare_unit
```

其余可以作为 `lockstep_comparator_logic` 内部结构。

不建议拆成大量过小 CBB。

---

# 34. Recommended V1.0 Default Configuration

功能安全应用建议：

```systemverilog
LOCKSTEP_DELAY          = 2;
STARTUP_GUARD_CYCLES    = 0;
CMP_PIPE_STAGES         = 0;

LCL_REDUNDANCY_LEVEL    = 2;

STATIC_COMPARE_MASK     = '1;

SUPPORT_RUNTIME_MASK    = 1;
SUPPORT_VALID_MASK      = 1;
SUPPORT_FAULT_INJECTION = 1;
```

即默认采用：

```text
Dual temporal delay
+
Dual comparator
+
Comparator cross-check
+
Main/Shadow fail-safe fault OR
+
LCL internal fault detection
+
Fault injection
```

---

# 35. Final Architecture Principle

LCL V1.0 应遵循以下原则：

> **LCL 不仅用于发现 Main / Shadow 的不一致，还必须考虑作为 Safety Mechanism 自身发生随机硬件故障的情况。**

因此其安全逻辑应满足：

```text
被保护逻辑故障
        ↓
Main / Shadow mismatch
        ↓
至少一路 comparator 检测
        ↓
Safety Fault
```

同时：

```text
Comparator / Delay Path 自身故障
        ↓
Redundant LCL paths disagree
        ↓
LCL Internal Fault
        ↓
Safety Fault
```

最终形成：

```text
               Protected Logic
                     |
            Main / Shadow Divergence
                     |
                     v
              +---------------+
              | Redundant LCL |
              +-------+-------+
                      |
          +-----------+-----------+
          |                       |
     Logic Divergence       LCL Internal Fault
          |                       |
          +-----------+-----------+
                      |
                 Safety Fault
```

该结构可以作为 CPU、NPU、DMA、安全控制器、SRAM Controller、关键 FSM 等双路锁步设计的通用 Comparator CBB 基线。
