# apb_register_slice 规格说明（G1 可读视图）

> **派生视图**：SSOT 为 [`cbb.yaml`](../cbb.yaml)（+[`behavior.yaml`](../behavior.yaml)），本文件仅为人工程序可读副本，**语义以 YAML 为准**（不双维护）。

## 1. 定位

APB 寄存切片：在 APB 主↔从之间的**前向通路（地址/写数据/控制）**与**反馈通路
（PREADY/PRDATA/PSLVERR）**上按模式插入 1~2 级寄存，割断长组合路径（PREADY 返回
路径为典型场景），不改变 APB 事务相位语义（SETUP→ACCESS）与事务顺序。

- 抽象粒度：`A3`（协议构件：APB 握手/时序语义绑定）
- 技术域：`apb_ahb_register`（次：无）
- Registry ID：`BUS-003`

## 2. 需求（REQ）

| ID | 需求 | 属性（PROP） | 测试（tc_*） | 配置（cfg_*） |
|---|---|---|---|---|
| REQ-001 | 相位使能保持（反馈打拍期间主/子 PSEL/PENABLE 相位一致） | `PROP-ARS_PHASE-001` | tc_phase, tc_random | cfg_..._slice_mode1/2_resp_stages1 |
| REQ-002 | 固定反馈延迟——子完成恰 RESP_STAGES 拍后主 PREADY 高 | `PROP-ARS_RESPDLY-002` | tc_resp_delay, tc_random | cfg_..._slice_mode1/2、resp_stages1/2 |
| REQ-003 | 反馈对齐——PRDATA/PSLVERR 与 PREADY 同拍生效 | `PROP-ARS_ALIGN-003` | tc_data_align, tc_random | cfg_..._slice_mode1/2_resp_stages1 |
| REQ-004 | request 模式——前向打拍 1 拍、反馈组合直通 | `PROP-ARS_REQDLY-004` | tc_req_mode, tc_random | cfg_..._slice_mode0_resp_stages1 |
| REQ-005 | full 模式——前向/反馈各 1 拍独立生效 | `PROP-ARS_FULL-005` | tc_full_mode, tc_random | cfg_..._slice_mode2_resp_stages1 |
| REQ-006 | 复位清洁——无事务时主/子侧 psel/penable/pready=0 | `PROP-ARS_RESET-006` | tc_reset, tc_equiv | cfg_..._slice_mode0/1/2 |
| REQ-007 | 非法参数组合在 Elaboration 期被拦截 | （负向编译证据） | tc_negative_elab | cfg_addr_width7 / data_width65 / slice_mode3 / resp_stages3（negative） |

> 完整映射见 [`trace/rtm.yaml`](../trace/rtm.yaml)（工具生成）。

## 3. 参数与约束

| 参数 | 类型 | 默认 | 合法域 | 语义 |
|---|---|---|---|---|
| `ADDR_WIDTH` | int | 16 | 8..32 | PADDR 位宽 |
| `DATA_WIDTH` | int | 32 | 8..64 | PWDATA/PRDATA 位宽 |
| `SLICE_MODE` | int | 2 | {0,1,2} | 0=request（前向打拍）/1=response（反馈打拍）/2=full（双打拍） |
| `RESP_STAGES` | int | 1 | 1..2 | 反馈寄存级数（SLICE_MODE!=0 时有效） |

约束（PC）：

| ID | 表达式 | 语义 |
|---|---|---|
| PC-001 | `ADDR_WIDTH >= 8` | APB 最小地址位宽 |
| PC-002 | `ADDR_WIDTH <= 32` | 地址通路时序上界 |
| PC-003 | `DATA_WIDTH >= 8` | 数据通路下界 |
| PC-004 | `DATA_WIDTH <= 64` | 数据通路上界 |
| PC-005 | `SLICE_MODE ∈ {0,1,2}` | 枚举合法域 |
| PC-006 | `RESP_STAGES ∈ {1,2}` | 反馈级数合法域 |

> 非法组合在 Elaboration 前被拦截（`cbb_tool.py check` + RTL `$error` generate 双拦截）。

## 4. 行为不变量（INV）与假设（ASM）

- 不变量：`INV-001` 相位使能保持 / `INV-002` 固定反馈延迟 / `INV-003` 反馈对齐 /
  `INV-004` 前向打拍 / `INV-005` 完整模式双打拍 / `INV-006` 复位清洁
- 时序：SLICE_MODE=0 前向 1 拍、反馈 0 拍；=1 前向 0 拍、反馈 RESP_STAGES 拍；
  =2 前向 1 拍、反馈 RESP_STAGES 拍。每事务完成延迟相应 +0/+1/+1~2 拍
- 假设：`ASM-001` 输入 X/Z 不承诺；`ASM-002` 上游遵守 APB 两相位协议（本构件为透传，
  不做协议检查）；`ASM-003` 参数编译期固定；`ASM-004` SLICE_MODE=0 主↔子环回组合
  路径由消费方评估
- 异常：复位期间与释放后无进行中事务时主/子侧选中/完成信号清零

## 5. 接口与时钟复位

- 接口：`apb_passthrough`（信号级 APB 主侧→子侧透传；不引用 SV interface——
  极简单文件纪律，协议契约归 HWIF，本构件只保存绑定语义）
- 端口（主侧 `_main` / 子侧 `_sub` 成对）：
  - 前向：`psel`、`penable`、`paddr[ADDR_WIDTH-1:0]`、`pprot[2:0]`、`pwrite`、
    `pwdata[DATA_WIDTH-1:0]`、`pstrb[DATA_WIDTH/8-1:0]`
  - 反馈：`pready`、`prdata[DATA_WIDTH-1:0]`、`pslverr`
  - 时钟复位：`clk`、`rst_n`（低有效异步复位）
- 说明：`pprot`/`pstrb` 为前向跟随信号（与 paddr 同路打拍），保持 APB 完整性

## 6. 假设与非目标（non-goals）

| 项 | 内容 |
|---|---|
| 非目标 1 | APB 协议检查/BFM（VIP → aixsilicon_vip_repo） |
| 非目标 2 | 地址译码/多从 mux（BUS-004/BUS-005） |
| 非目标 3 | CDC（BUS-006）、位宽转换（BUS-007）、超时保护（BUS-008） |
| 非目标 4 | PPROT/AUSER 等扩展信号（可扩展不阻塞） |

## 7. 集成限制

- 限制 1：SLICE_MODE=0（request）时 PREADY 主↔子为组合直通，环回时序由消费方评估（ASM-004）
- 限制 2：RESP_STAGES=2 仅 SLICE_MODE=1/2 有意义；SLICE_MODE=0 时忽略（契约仍合法）
- 限制 3：本构件不终止/产生事务；慢速外设长期无 PREADY 的超时保护请叠加 BUS-008
