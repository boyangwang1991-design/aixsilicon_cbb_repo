# 详设：切片三实现（SLICE_IMPL=0/1/2）— parallel_data_fetch

三种切片结构共享**同一可观察契约**：任一实现下，
`link_beat_data_o` 在 beat `i` 必须等于 `snapshot_q` 的第 `i` 个 `LINK_WIDTH` 切片（按 `LSB_FIRST` 定向）。
该等价关系由 provider 内的 SVA `ap_slice_matches_snapshot` 直接约束，并由仿真按相同参数
分别运行三种实现后逐 bit 比对（REQ-006 / tc_slice_equivalence）。

## 实现 A：shift（`SLICE_IMPL=0`）

- 数据：`sh_q` 为 `DATA_WIDTH` 寄存器副本，`data_fire` 当拍载入 `data_i`；
  发送期间每拍向发送方向移位 `LINK_WIDTH` 位；输出取低（LSB-first）或高（MSB-first）`LINK_WIDTH` 位。
- 逻辑深度：1 级宽 MUX/连线（输出始终取固定的 `LINK_WIDTH` 位），控制最简。
- 代价：每拍翻转约 `DATA_WIDTH - LINK_WIDTH` 个寄存器位 → 动态功耗随 `DATA_WIDTH` 近线性上升。
- 适用：`BEAT_COUNT` 小或对宽 MUX 深宽敏感、对功耗不敏感的场景。

## 实现 B：indexed（`SLICE_IMPL=1`）

- 数据：`snapshot_q` 全程不变；输出为 `snapshot_q[beat_cnt*LINK_WIDTH +: LINK_WIDTH]`（或 MSB 定向）。
- 逻辑深度：索引 MUX 深度随 `BEAT_COUNT` 增长（`log2(BEAT_COUNT)` 级选择）。
- 代价：寄存器翻转率最低（只有快照一次载入）；面积代价在 MUX 网络。
- 适用：`BEAT_COUNT` 适中、功耗敏感场景；大 `BEAT_COUNT` 时受 MUX 深度限制。

## 实现 C：banked（`SLICE_IMPL=2`，默认）

- 数据：按 `LINK_WIDTH` 切成静态数组 `bank_q[BEAT_COUNT]`，`data_fire` 时一次性并行写入所有 bank；
- 输出：`bank_q[beat_cnt_q]`，索引位宽仅 `$clog2(BEAT_COUNT)`。
- 逻辑深度：与 `BEAT_COUNT` 同阶但选择网络位宽更小（每 bank 独立，无跨 bank 全宽 MUX）。
- 代价：写入侧为 `BEAT_COUNT` 路并行写（解码器 + 位切片），面积与 `DATA_WIDTH` 同阶。
- 适用：默认推荐；在翻转率与 MUX 深度之间平衡，大 `BEAT_COUNT` 时相对 indexed 的时序优势明显。

## Pareto 分布：实测修正（2026-09-17）

原表为结构推理（PPA-E0）。GF 28nm LP `sc9_cmos28lp_base_hvt tt_1p00v_25c` 真实综合
（256→32，10 点之一，见 [`../../reports/ppa-report.md`](../../reports/ppa-report.md)）结果：

| 实现 | 面积 (µm²) | slack (ns) | 漏电 (nW) | 动态功耗 (µW) |
|---|---:|---:|---:|---:|
| shift | 3187.7 | **0.03** | 327.1 | 960.9 |
| indexed | 3187.5 | **0.04** | 336.3 | 961.0 |
| banked | 3204.9 | 0.00 | 352.2 | 974.0 |

修正结论：

1. **面积三者几乎相同（差 <0.6%）**——原推论"shift 面积小、banked 面积中"未成立：
   banked 的写解码开销被 shift 的全宽移位网络抵消。
2. **时序上 shift/indexed 反而更好**（0.03/0.04 vs 0.00 ns）——与原文"banked 时序更优"**相反**。
   原因：banked 需 beat counter 索引 + 每 bank 写解码，在 400 MHz 下成为端点内较紧的路径之一。
3. **功耗上 banked 略差**（漏电 352.2 vs 327.1/336.3 nW，动态 974.0 vs 960.9/961.0 µW）——
   翻转率优势**未在综合默认 activity 下体现**；要证实"banked 翻转率更低"必须用 SAIF 实测
   （当前 `plan.yaml` planned 已列）。

三者仍不构成"实现契约差异"：可观察行为（数据、顺序、last、错误）由 SVA
`ap_slice_matches_snapshot` 与 G4/G5 等价回归证明完全一致；差异只在 PPA 空间。

**默认实现的处理**：`cbb.yaml` 的 `SLICE_IMPL` 默认仍为 2（banked），但依据从"时序更优"
改为**翻转率/功耗在连续发送场景的潜在优势（待 SAIF 证实）**；`profiles.yaml` 三个切片 Profile
的 `support` 保持 `experimental`，不因单次表征升级。

## 表征状态

已用 GF 28nm LP（`sc9_cmos28lp_base_hvt tt_nominal_max_1p00v_25c`）完成真实综合表征
（PPA-E1，`run-20260917-01`）。仍属**单 corner tt**：ss/ff 差异、SAIF 功耗与布局拥塞
均未覆盖（见 [`../../reports/ppa-report.md`](../../reports/ppa-report.md) §6 未覆盖清单），
不得据此声称跨工艺或跨 corner 结论。