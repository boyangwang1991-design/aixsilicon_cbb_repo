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

## 预期 Pareto 分布

| 实现 | 面积 | 动态功耗 | 时序（关键路径） |
|---|---|---|---|
| shift | 小（无 bank 阵列） | 高（宽移位翻转） | 浅（输出位固定） |
| indexed | 中（MUX 网络） | 低 | 深（随 BEAT_COUNT 增长） |
| banked | 中（阵列 + 写解码） | 低 | 浅（小位宽索引） |

三者不构成"实现契约差异"：对外可观察行为（数据、顺序、last、错误）完全一致；
仅在面积/功耗/时序空间上分散，属 PPA 选型而非功能变体。

## 未表征说明

本机无可提交的标准单元库快照（`characterization.status: OPTIONAL_UNAVAILABLE`），
上表为**结构推理**（PPA-E0），不是门级综合结论；正式 Pareto 数据需在具备库上下文时由
`characterization/plan.yaml` 声明比较点后运行 G6。