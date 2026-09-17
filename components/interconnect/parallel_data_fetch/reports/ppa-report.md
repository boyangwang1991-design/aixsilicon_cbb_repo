# PPA 报告 — parallel_data_fetch（INT-001）

> 证据等级：**PPA-E1（Generic）**——GF 28nm LP 固定内部库、tt 单 corner、dc_shell 固定选项。
> 不泛化到其它工艺/corner，不进入跨工艺比较。比较图见 [`ppa_run-20260917-01.png`](ppa_run-20260917-01.png)。

## 1. 实验上下文（可复现绑定）

| 项目 | 取值 |
|---|---|
| CBB / 版本 | `aixsilicon:cbb:parallel_data_fetch` 0.1.0 |
| 运行 ID | `run-20260917-01`（原始数据 `build/eda/ppa/run-20260917-01/`，不入库） |
| 工艺 / corner | GF 28nm LP（CMOS28NM）；`sc9_cmos28lp_base_hvt`，`tt_nominal_max_1p00v_25c` |
| 库视图 | 取自 `GF21LB004-FB-00000-r5p0-03rel0`（`.db`） |
| 综合工具 | Synopsys DC `dc_shell` V-2023.12-SP3，`compile_ultra -no_autoungroup` |
| 时钟 | 同步：A/B 同钟 2.5 ns（400 MHz）；异步：A/B 各自 2.5 ns，`set_clock_groups -asynchronous` |
| IO 约束 | input/output delay 0.5 ns，`set_driving_cell BUFH_X4M_A9TH`，load 0.01 pF |
| 功耗活动率 | **综合默认估计**（无 SAIF）→ 动态功耗仅供相对比较，非绝对值承诺 |
| 脚本 | [`../characterization/synth_sweep.tcl`](../characterization/synth_sweep.tcl) |
| 计划 | [`../characterization/plan.yaml`](../characterization/plan.yaml)（10 点，与图同序） |

## 2. 结果（10 点，超出 2.5 ns 即 VIOLATED）

| # | 配置 | 面积 (µm²) | slack (ns) | 漏电 (nW) | 动态功耗 (µW) |
|---|---|---:|---:|---:|---:|
| 1 | 256/32 banked（默认） | 3204.9 | **0.00** | 352.2 | 974.0 |
| 2 | 256/32 shift | 3187.7 | 0.03 | 327.1 | 960.9 |
| 3 | 256/32 indexed | 3187.5 | 0.04 | 336.3 | 961.0 |
| 4 | 256/32 pipe=1 | 3297.9 | 0.00 | 354.0 | — |
| 5 | 256/32 pipe=8 | 3973.1 | 0.02 | 424.5 | — |
| 6 | 512/64 banked | 6176.9 | 0.02 | 658.0 | — |
| 7 | 1024/128 banked | 11893.2 | 0.15 | — | — |
| 8 | 64/32 banked | 978.7 | 0.09 | 104.4 | 278.8 |
| 9 | 256/32 async（FIFO=16） | 5787.4 | 0.00 | 652.6 | — |
| 10 | 256/32 async（FIFO=8） | 4519.7 | 0.00 | 506.0 | — |

10 点全部 **MET**（slack ≥ 0），无违例。全部点均可 elaboration 并综合通过（`PPA-DONE` ×10）。

## 3. 对 `docs/design.md` §6 推理的实测校验

| 设计推论 | 实测 | 结论 |
|---|---|---|
| 快照+重组寄存器面积随 `DATA_WIDTH` 近线性 | 64→256→512→1024 bit：978.7 → 3204.9 → 6176.9 → 11893.2 µm² | **成立**（每 bit ≈ 11.4 µm²，线性度高） |
| `banked` 是面积-时序平衡点，`shift/indexed` 面积略小 | shift 3187.7 / indexed 3187.5 / banked 3204.9 µm²（差 <0.6%）；slack：banked 0.00 vs shift 0.03 / indexed 0.04 | **部分成立**：三者面积几乎相同（扇出/写解码抵消了预期差异），但 **shift/indexed 时序裕度更好**——`banked` 的索引 MUX + bank 写解码确实带来时序代价。故 §6 中"banked 时序更优"的说法**不成立**，需修正（见 §5） |
| `LINK_PIPE_STAGES` 增加 → 面积增、时序改善 | pipe=0 (3204.9, 0.00) → pipe=1 (3297.9, 0.00) → pipe=8 (3973.1, 0.02) | **部分成立**：面积 +2.9%/+24%，但时序在 2.5 ns 下**未显著改善**（0.00→0.02），说明当前关键路径不在长线链路而在端点内部（超时/错误合并/重组末拍合并） |
| `async` 增加 async FIFO 成本 | sync 3204.9 → async FIFO=16 5787.4（+80.6%）；FIFO=8 4519.7（+41.0%） | **成立**：FIFO 深度与容量（读指针同步器 + 存储 + 指针逻辑）成本可量化，深度减半约省 22% 面积 |
| `SLICE_IMPL` 三实现共享可观察契约、差异只在 PPA | G4/G5 已证等价；本表面积差异 <0.6% | **成立** |

## 4. 关键时序观察与限制

- 同步默认点 slack **0.00 ns**（恰好 MET）→ 400 MHz 处于该实现的临界；若要更高频率需
  提高 `LINK_WIDTH`（减少 beat 数）或改用 pipeline（但见 §3 第 3 行：端点内部路径是瓶颈）。
- **未逐域细分 slack**：异步点只报了各域最差值（0.00）。`report_timing` 的 3 条路径未按
  `a_clk`/`b_clk` 分组输出，无法确认哪个域更紧——属本报告**限制**（见 §5）。
- 无 reg→reg 的解释：本构件两端点各自有状态机与寄存器，存在 reg→reg 路径；
  跨域路径按 CDC 例外不参与 setup 比较（已在 tcl 中 `set_clock_groups -asynchronous`）。
- 功耗：无 SAIF，动态功耗为综合默认活动率估计；漏电为库报告值。**不作绝对承诺**。

## 5. 设计文档需修正之处（诚实记录）

1. **`docs/design.md` §6 与 `docs/detail-design/slice_impl.md` 称 banked 时序优于 shift/indexed
   —— 实测相反**（banked slack 0.00 vs shift 0.03 / indexed 0.04，面积三者几乎相同）。
   应将"默认推荐 banked"的依据改为**翻转率/功耗**（banked 每拍只动 1 个 bank，shift 动全宽），
   而非时序；或按消费者约束重新选择默认实现。
2. **`LINK_PIPE_STAGES` 的收益在本工艺/约束下未被证实**（面积 +24% 换 slack +0.02 ns）——
   应在文档中标注"收益取决于长线实际延迟与后端约束，本表征未体现"。

## 6. 未覆盖（不夸大范围）

| 项 | 状态 |
|---|---|
| ss/ff corner | 未跑（仅 tt） |
| SAIF 动态功耗 | 未做 |
| 布局/拥塞代理 | 未做——**本构件核心价值是长距布线资源**，逻辑门面积无法体现其收益；需与"同宽并行总线"做物理对比（`plan.yaml` planned 已列） |
| BEAT_COUNT 极大（如 4096→1） | 未表征（上界到 1024→128） |
| 异步逐域 slack 分组 | 未按域细分（见 §4） |

## 7. 复现

```bash
cd repos/aixsilicon_cbb_repo/components/interconnect/parallel_data_fetch
export IDE_CBB_ROOT=$(pwd) IDE_RTL_DIR=$(pwd)/rtl IDE_RUN_ID=run-<id>
dc_shell -f characterization/synth_sweep.tcl                      # 综合 + 抽取（≈5.5 min/10 点）
uv run --with matplotlib python characterization/plot_ppa_comparison.py \
    --run-dir build/eda/ppa/run-<id> --out reports/ppa_run-<id>.png