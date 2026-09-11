# apb_register_slice 架构设计（G2）

> 生命周期 C2 产物。前置：契约（`cbb.yaml`/`behavior.yaml`）已通过 G1。
> 详设（微架构/逻辑深度/PPA 优化点/生成方式）见 [`docs/detail-design/`](detail-design/)（request/response/full）。

## 1. 模块划分

```
apb_register_slice（单文件，极简风格）
├── 参数检查：generate $error（PC-001..006，elaboration 期拦截）
├── 前向通路（main → sub）
│   ├── SLICE_MODE=0/2：psel/penable/paddr/pprot/pwrite/pwdata/pstrb 打拍 1 拍
│   └── SLICE_MODE=1：组合直通
├── 反馈通路（sub → main）
│   ├── SLICE_MODE=1/2：pready/prdata/pslverr 打拍 RESP_STAGES 级
│   └── SLICE_MODE=0：组合直通
├── 反馈保持（mode=1/2）：完成事件寄存传播，避免首拍数据丢失
│   ├── stage1：resp_stage1 <= {pslverr_sub, prdata_sub, pready_sub}
│   └── stage2（RESP_STAGES=2）：resp_stage2 <= resp_stage1
└── 就近 SVA：@(posedge clk) 并发断言（INV-001..006，PROP-ARS_*）
```

- RTL 布局：**默认单文件** `rtl/apb_register_slice.sv`（三模式由 SLICE_MODE 编译期
  generate 分派，同居单文件；无 package/interface）。
- 嵌套依赖：无（`implementations[].dependencies[]` 为空）。

## 2. 多实现与 Profile

**共享同一可观察 APB 透传契约**（相位语义/事务顺序不变），差异仅在打拍位置与级数
（domain-rules §4）。

| Profile | implementation | SLICE_MODE/RESP_STAGES | 优化目标 | Use Case | 支持状态 |
|---|---|---|---|---|---|
| `request_slice` | impl_request | 0 / 1 | zero_resp_latency | 前向割断、反馈路径短 | supported |
| `response_slice` | impl_response | 1 / 1 | timing | PREADY 返回路径割断（经典） | supported |
| `full_slice` | impl_full | 2 / 1 | balanced | 两侧组合路径均长 | supported |
| `full_slice_deep` | impl_full | 2 / 2 | pipeline | 反馈两级流水 | experimental |

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 单 `clk`（全模式均使用；request 模式反馈直通仍需 clk 供前向打拍） |
| 复位 | 异步 `rst_n`（低有效）；释放后前向寄存组（mode=0/2）与反馈寄存组（mode=1/2）清零 |
| X 语义 | 输入 X/Z 不承诺（ASM-001）；2-state 仿真语义 |
| 异常行为 | 纯透传：不产生/终止事务、不注入 PSLVERR、不做超时（BUS-008 职责） |

## 4. 关键数据路径（契约细化）

### 4.1 前向通路（mode=0/2）

- `{psel_sub, penable_sub, paddr_sub, pprot_sub, pwrite_sub, pwdata_sub, pstrb_sub}`
  `<= {psel_main, penable_main, ...}`（1 拍；异步复位清零）
- 关键点：**psel/penable 与地址/数据同拍寄存**，保证子侧相位与地址原子到达（INV-001）。

### 4.2 反馈通路（mode=1/2）

- `resp_stage1 <= {pslverr_sub, prdata_sub, pready_sub}`（1 拍）；
  `RESP_STAGES=2` 时再打一级 `resp_stage2 <= resp_stage1`
- 关键点：pready/prdata/pslverr **三信号同组寄存**，完成与数据/错误天然对齐（INV-003）；
  固定延迟 = RESP_STAGES（INV-002），子侧 PREADY 保持多少拍不影响主侧呈现
  （完成事件以寄存沿捕获）。

### 4.3 组合直通（mode=0 反馈 / mode=1 前向）

- mode=0：`pready_main = pready_sub`、`prdata_main = prdata_sub`、`pslverr_main = pslverr_sub`
- mode=1：前向信号逐位 `assign` 直通

## 5. 可验证性论证

- 每个 Profile 有验证路径：SVA（模块内 `@(posedge clk)` 并发断言，TB 驱动在 negedge
  更新避开采样沿）+ Simulation（定向相位/延迟/对齐/边界 + 随机 2000+ 拍）+ 负向 elab
  （非法参数）+ 变异（破坏对齐/相位语义应被 SVA 检出）。
- 关键不变量映射 PROP：`PROP-ARS_PHASE-001`/`PROP-ARS_RESPDLY-002`/`PROP-ARS_ALIGN-003`/
  `PROP-ARS_REQDLY-004`/`PROP-ARS_FULL-005`/`PROP-ARS_RESET-006`（见 trace/rtm.yaml）。
- Profile 差异验证重点：三模式跨模式空闲等价（tc_equiv）+ 延迟参数化
  （RESP_STAGES=1/2 定向）+ 随机 PREADY 抖动下的固定呈现延迟。

## 6. PPA 预筛（E0/E1 → G6 实证）

- 定性：全模式面积 ≈ 寄存器量（前向 AW+DW+DW/8+7 bit 或反馈 DW+2 bit）+ 极薄组合；
  时序关键路径为两侧寄存器间纯一级逻辑，fmax 友好（这正是本构件用途）。
- 面积驱动要素：DATA_WIDTH（pwdata+prdata+pstrb）> ADDR_WIDTH > 模式差异；
  request/full 模式面积近似（full 多一组反馈寄存），response 最小。
- 证据等级：G6 计划 E1（DC 综合 sweep：SLICE_MODE×{AW16,DW32} 代表点）。

## 7. 子依赖（若有）

无运行时子依赖。非目标：译码/mux（BUS-004/005）、CDC（BUS-006）、位宽（BUS-007）、
超时（BUS-008）、协议 VIP（aixsilicon_vip_repo）。
