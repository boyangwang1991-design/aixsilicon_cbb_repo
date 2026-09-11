# apb_register_slice PPA 表征报告（G6）

> **上下文绑定**：GF CMOS28LP（CMOS28NM）· ARM SC9 `sc9_cmos28lp_base_hvt`（HVT）·
> corner `tt_nominal_max_1p00v_25c` · `create_clock 2.5ns`（400MHz）·
> in/out delay 0.5ns · 驱动 `BUFH_X4M_A9TH` · 负载 0.01pF。
> **证据等级：PPA-E2**（DC `compile_ultra` 真实综合 sweep，30 点，单 corner，脚本可复现）。
> Run ID：`run-20260911-032845-01`（原始报告在 `build/eda/ppa/<run-id>/`，本地不入库）。

## 1. 总览（29 综合点：27 模式×宽度 + 2 反馈级数）

| 指标 | 结论 |
|---|---|
| 面积 | 26.1–459.2 µm²（SC9 面积单位，随 DW 主导线性变化） |
| 时序 | 全部收敛：reg→reg 路径 slack +1.48ns @2.5ns（400MHz）余量充足；mode1/2 最大路径为输出端口路径（0.38–0.52ns arrival，unconstrained 输出延迟报告，无违例） |
| 功耗 | 见原始 `*_power.rpt`（组合占比极低，寄存器主导） |

## 2. 模式对比（AW16/DW32 代表点，RESP_STAGES=1）

| SLICE_MODE | 面积 | 相对 | 寄存器构成 | 反馈延迟 |
|---|---|---|---|---|
| 0 request | 150.23 | 1.69× | 前向组（AW+3AW/8+DW+7=60 FF） | 0（组合） |
| 1 response | 88.33 | 1.00× | 反馈组（DW+2=34 FF） | 1 拍 |
| 2 full | 239.03 | 2.71× | 前向组 + 反馈组（94 FF） | 1 拍 |

- **response 最小**（纯反馈组寄存，符合详设预期）；
- **full ≈ request + response 面积叠加**（两组寄存独立，无共享——239 ≈ 150+89，验证详设守恒）。

## 3. 宽度阶梯（面积随 DW/AW 线性，SC9 面积单位）

| 点 | mode0 | mode1 | mode2 |
|---|---|---|---|
| AW8/DW8 | 59.55 | 26.09 | 85.76 |
| AW16/DW32 | 150.23 | 88.33 | 239.03 |
| AW32/DW64 | 285.71 | 171.17 | 459.22 |

- mode1 面积只随 DW 变化（AW 无关——前向组合直通），与契约一致；
- mode0/2 面积随 AW、DW 双线性增长；Δ(mode2−mode1) ≈ mode0 − 34FF 折算，一致。

## 4. 反馈级数（full 模式，AW16/DW32）

| RESP_STAGES | 面积 | Δ |
|---|---|---|
| 1 | 239.03 | — |
| 2 | 328.19 | +89.16（≈ 反馈组 34FF×2 + 综合重排） |

RESP_STAGES=2 仅流水加深，无组合增量；时序收敛等价。

## 5. Pareto 位置与 Profile 推荐

| Profile | 位置 | 推荐 |
|---|---|---|
| `response_slice`（mode1） | 面积最小 + 割断 PREADY 返回路径 | **默认推荐**（经典用途） |
| `request_slice`（mode0） | 面积中 + 零反馈延迟 | 前向扇入隔离专用 |
| `full_slice`（mode2） | 面积最大 + 两侧割断 | 物理隔离/远距从设备 |
| `full_slice_deep`（mode2,RS2） | 面积最大 + 反馈两级 | 反馈流水长距离场景 |

## 6. 复现

```bash
cd <cbb根>/build/eda
PC_RUN_ID=run-<id> PC_RTL_DIR=<cbb>/rtl PC_CBB_ROOT=<cbb根> \
  dc_shell -f ../characterization/synth_sweep.tcl
```

脚本：[`characterization/synth_sweep.tcl`](../characterization/synth_sweep.tcl)（29 点确定性 sweep）。
库路径精确快照：`build/eda/pdk.local.yaml`（本地）；脱敏摘要：[`characterization/pdk.yaml`](../characterization/pdk.yaml)（可提交）。
