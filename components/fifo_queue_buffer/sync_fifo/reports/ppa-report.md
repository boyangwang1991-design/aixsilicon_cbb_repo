# PPA 报告 — sync_fifo（G6）

> 实验上下文（E2：固定内部库 + 工具基线完整）：
> - CBB `aixsilicon:cbb:sync_fifo:0.1.0`（QUE-001）；RTL `rtl/sync_fifo.sv`
>   （IMPL×OUTPUT_REG 四 generate 分支单文件，无嵌套子 CBB 依赖）
> - 工艺库：`sc9_cmos28lp_base_hvt` tt corner `tt_nominal_max_1p00v_25c`
>   （GF CMOS28LP 28nm，ARM SC9 HVT C30），`characterization/pdk.yaml` 为库上下文事实源
> - 工具：Design Compiler（dc_shell）`V-2023.12-SP3`；`compile_ultra -no_autoungroup`
> - 约束：`create_clock -period 2.5ns [get_ports clk]`（400MHz，**绑定源端口**）；
>   input/output delay 0.2ns；`BUFH_X4M_A9TH -pin Y` driving；0.01 load
> - 数据宽固定 `DATA_W=32`；深度代表点 `DEPTH∈{8,32}`；活动率默认概率传播估计（无 SAIF）
> - Run ID：`run-20260903-01`（原始报告：`build/eda/ppa/run-20260903-01/`，本地可复现不入库）

## 1. 数据（8 配置，全部 reg→reg slack MET @400MHz）

| 实现 (IMPL×OUT) | DEPTH | area(µm²) | cells(comb/seq) | regs | worst slack(ns) | dyn(µW) | leak(nW) |
|---|---|---|---|---|---|---|---|
| register×comb | 8  | 957.6  | 750 (484/266) | 266 | 0.55 | 437.6 | 124.0 |
| register×comb | 32 | 3747.4 | 2919 (1879/1040) | 1040 | 0.00 | 1621.5 | 483.8 |
| register×reg  | 8  | 1071.1 | 846 (547/299) | 299 | 0.10 | 503.5 | 128.1 |
| register×reg  | 32 | 3865.0 | 3018 (1945/1073) | 1073 | 0.02 | 1685.4 | 484.0 |
| shift×comb    | 8  | 1053.4 | 866 (606/260) | 260 | 0.03 | 482.4 | 114.7 |
| shift×comb    | 32 | 4105.1 | 3304 (2274/1030) | 1030 | 0.02 | 1821.4 | 435.8 |
| shift×reg     | 8  | 1040.7 | 848 (587/261) | 261 | 0.03 | 487.8 | 113.2 |
| shift×reg     | 32 | 4095.0 | 3284 (2253/1031) | 1031 | 0.00 | 1850.9 | 446.5 |

对比图：[`reports/ppa_run-20260903-01.png`](ppa_run-20260903-01.png)（面积 / slack / 动态功耗 × DEPTH）。

## 2. 解读

### 2.1 面积：register×comb 最小，shift 不占优（反直觉，实测纠正）

- **`register×comb` d8=957.6 / d32=3747.4 面积最小**，`shift*` d8≈1041–1053 / d32≈4095–4105 略大
  （shift×comb d32 比 register×comb 大 **9.5%**）。
- **根因（实测 cell 统计）**：shift 组合单元显著多于 register
  （d8: shift 606 vs register 484；d32: shift 2274 vs register 1879）——shift 每个存储 FF
  需要"保持/左移/尾写"选择 mux（≈DEPTH×DW 个 2~3 选 mux），而 register 的寄存器堆
  仅需每槽写入使能 + **单个**读侧 DEPTH 选 1 mux。**移位每槽移动 mux 的组合开销
  > 省下的读 mux 开销** → 详设/架构中"shift 省读 mux 面积占优"的**理论预判在本工艺/
  本深度区间不成立**（ECC/控制小、存储占主导的场景）。
- 例外边界：DEPTH 极小（≤4）或读侧多端口（多个并发 pop，register 读 mux 成倍放大）时
  shift 可能反转占优——本次未测，属**未表征区**（不宣称）。

### 2.2 时序：register×comb slack 最好（d8 0.55ns），d32 全逼近临界

- d8：`register×comb` slack 0.55ns 显著优于其余（0.03–0.10ns）——comb 直读 head 路径
  短、reg→reg 主路径为 count→写使能；shift 的 refill 左移 mux 使能链深导致 slack 收紧。
- d32：四种实现全部 slack ≤0.02ns（register×comb/shift×reg = 0.00，**临界 MET**）——
  深度 32 时读侧 mux（register）或移位使能网络（shift）都成为主路径；400MHz 为临界点，
  **>400MHz 需放松深度或分割输出级**。d8 slack 与面积结论一致指向 register×comb 在
  中浅深度的 PPA 优势。
- reg 输出级（OUTPUT_REG=1）面积 +10–12%（输出 FF），d8 slack 比 comb 差
  （0.10 vs 0.55）——因为输出级 FF 在满吞吐下也计入 reg→reg 路径（refill→输出级）；
  其价值在**下游 ready 组合链隔离**（本 CBB 输出非组合 ready 回压，故收益不显著，
  属功能/timing-closure 取舍而非本模块自身 PPA 收益）。

### 2.3 功耗

- 动态功耗 d8≈438–504µW、d32≈1621–1851µW；**shift 动态功耗略高**（d32 shift 1821–1851
  vs register 1621–1685，+12–14%）——移位链全体翻转使能（pop/refill 全链平移）耗能，
  印证移位链功耗随深度线性劣化的预判（profiles known_limits）。漏电与面积正相关
  （register×comb d32 484nW 最低）。
- 功耗无 SAIF（默认概率传播），证据等级 E2 的功耗子项为**估计级**，仅作相对趋势。

## 3. Pareto 与推荐（E2，@400MHz / DATA_W=32 / DEPTH 8–32 已表征区）

| 目标 | 推荐 | 依据 |
|---|---|---|
| 面积+时序（默认，中浅深度） | **`default_register`（register×comb）** | d8/d32 面积最小 + slack 最优，Pareto 支配 shift 点 |
| 高深度时序余量 | `register_registered_out`（register×reg） | 输出级寄存切断读路径（d32 slack 0.02 与 shift 相当，面积略小） |
| （shift 家族） | 建议降级 `shift_shallow`/`shift_registered_out` 为 `experimental` | 实测 d8/d32 面积/功耗均劣于 register，**PPA 无优势**；仅在 DEPTH≤4 / 多读口等未表征区可能反转（需补测） |

> 注：shift profile 支持状态变更属架构决策（profiles.yaml SSOT），本报告给出候选建议，
> 需 CBB Architect 复核后更新（当前文档仍标 supported 为未决状态）。

## 4. 证据等级与边界

- 证据等级：**E2**（固定内部库 + 工具/约束基线完整，可复现：`PC_RUN_ID=run-20260903-01
  dc_shell -f characterization/synth_sweep.tcl` + `extract_ppa.py` + `plot_ppa_comparison.py`）。
- 已表征区：DATA_W=32 × DEPTH{8,32} × IMPL{0,1} × OUTPUT_REG{0,1}（8 点）。
- 未表征/外推域（不宣称）：DATA_W>32、DEPTH>32、ss/ff corner、DEPTH≤4 shift 反转区、
  活动率真实 SAIF；`IMPL=sram` 未实现（non_goal）。
- 回归：功能 G3/G4 未受 PPA 影响（纯综合实验，无 RTL 变更）；负结果（shift 不占优）
  未隐藏，如实记录于 §2.1/2.3。

## 5. 复现

```bash
# 从 CBB 根目录
uv run python <suite>/cbb_tool.py pdk-scan --pdk /home/eda/pdk --root . --cbb components/fifo_queue_buffer/sync_fifo  # 已固化 pdk.yaml
cd build/eda/ppa && PC_CBB_ROOT=<cbb> PC_RTL_DIR=<cbb>/rtl PC_RUN_ID=run-<new> dc_shell -f <cbb>/characterization/synth_sweep.tcl
uv run python <cbb>/characterization/extract_ppa.py <cbb> <new-run>
uv run --with matplotlib python <cbb>/characterization/plot_ppa_comparison.py --run-dir build/eda/ppa/<new-run> --out reports/ppa_<new-run>.png
```
