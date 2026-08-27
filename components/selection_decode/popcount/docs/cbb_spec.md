# popcount 规格说明（G1 可读视图 · 方案冻结稿）

> **派生视图**：SSOT 为 [`cbb.yaml`](../cbb.yaml)（+[`behavior.yaml`](../behavior.yaml)），本文件仅为人工程序可读副本，**语义以 YAML 为准**（不双维护）。
> **状态**：方案冻结稿——YAML 契约将在线下评审通过后写入并跑 `cbb_tool.py check`。

## 1. 定位

纯组合 Hamming 权重计数原子构件：对 `INPUT_WIDTH` 位输入向量输出其 1 的个数。无时钟、无状态、无握手。

- 抽象粒度：`A1`（原子机制）
- 技术域：`selection_decode`
- Registry ID：`SEL-014`；VLNV 目标：`aixsilicon:cbb:popcount:0.1.0`

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） |
|---|---|---|---|
| REQ-001 | cnt_o 恒等于 data_i 的 Hamming 权重 | `PROP-PC_FUNC-001` | tc_exhaust_w8 / tc_random |
| REQ-002 | 数值域边界正确：全 0→0，全 1→INPUT_WIDTH | `PROP-PC_BOUND-002` | tc_edge |
| REQ-003 | 三实现共享同一可观察契约且两两等价 | `PROP-PC_EQV-003` | tc_equiv_lec |
| REQ-004 | 非法参数在 Elaboration 期被拦截 | （负向编译证据） | tc_negative_elab |

> 完整映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)（G1 后工具生成）。

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `INPUT_WIDTH` | int | 64 | 4~256 | 输入向量位宽（计数对象宽度） |
| `CHUNK_W` | int | 8 | 4~8 | lookup 实现分段位宽（2^CHUNK_W 项表）；仅影响 impl_lookup |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | `INPUT_WIDTH >= 4` | 防退化零宽/过窄场景失去构件意义 |
| PC-002 | `CHUNK_W >= 4 and CHUNK_W <= 8` | 控制查找表规模在 16~256 项的可映射区间 |

> 非法组合（如 INPUT_WIDTH=3、CHUNK_W=9、非整数）由 RTL generate `$error` 在 Elaboration 期拦截，
> 与 `cbb_tool.py check` 双拦截（评审关注点 #2 讨论后定稿）。

## 4. 行为不变量（INV）与假设（ASM）

- 不变量：
  - `INV-001` 函数一致性：任意合法输入 cnt_o == popcount(data_i)（error）
  - `INV-002` 值域封闭性：0 ≤ cnt_o ≤ INPUT_WIDTH 且端点可达（error）
- 时序：无时钟端口；逻辑深度随 impl/W 变化（见 design.md §6 度量计划）
- 假设：
  - `ASM-001` 输入为 2-state 数据时结果才有定义；X 输入不承诺输出值
  - `ASM-002` 消费侧若需时序收敛自行寄存打拍
- 异常：无非目标性行为分支（无状态构件）

## 5. 接口与时钟复位

- 接口：原生向量接口（不引用 HWIF——无总线协议语义，理由登记于契约 YAML `contract.interface: native_vector`）
- 端口：`data_i[INPUT_WIDTH-1:0]` → `cnt_o[CNT_W-1:0]`，`CNT_W = $clog2(INPUT_WIDTH+1)`
- 时钟：0 个；复位：无

## 6. 非目标（non-goals）

| 项 | 内容 |
|---|---|
| NG-1 | 流水化/寄存输出版本（消费侧职责；A1 保持原子性） |
| NG-2 | 加权/掩码 popcount（mask 交由调用方先与运算） |
| NG-3 | CDC 处理（纯单域组合） |

## 7. 集成限制

- 限制 1：最大推荐 INPUT_WIDTH=256；>128 时优先选 `impl_column_compress` profile
- 限制 2：输出不做截断可选配置——全精度固定，防隐式截断误用
- 用途建议：ECC 编码器 / 性能事件统计 / 调度权重 / DSP 稀疏度估计

## 8. 追踪与验证形态

需求→属性→测试→配置映射：[`trace/rtm.yaml`](../trace/rtm.yaml)；
验证矩阵与用例定义：[`verification/plan.yaml`](../verification/plan.yaml)、
[`verification/configs/`](../verification/configs/)（config-gen 生成）。
