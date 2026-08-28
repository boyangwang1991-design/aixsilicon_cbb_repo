# wallace 详设（PC_IMPL=2，生成器展开）

## 1. 结构

Wallace tree 归约模型：

- **初始列**：仅权重 0 列含全部 `DATA_W` 个输入位（每输入位权重 1）。
- **归约**：逐级对每列（由低到高）压缩——
  - 3 个同权重 bit → 全加器 FA：`sum` 回同列、`carry` 抬入高权重列；
  - 2 个同权重 bit → 半加器 HA：`sum` 回同列、`carry` 抬入高权重列；
  - 1 个直通。
- **收敛**：每列 ≤2 后构成两行（row0/row1）。
- **收尾**：`NBITS = clog2(DATA_W+1)` 位 ripple-carry 相加（含 carry-in 链），
  最高位进位即结果最高位。

**正确性（权重守恒）**：任一时刻，每列的 bit 数 × 2^权重 之和恒等于输入中 1 的
个数；FA/HA 不改变该守恒。归约到两行后 ripple-carry 精确求和。

## 2. 生成器（tools/gen_popcount.py）

- 每级扫描各列，贪心"每 3 个→FA、每 2 个→HA"。
- 输出扁平 `assign` 网表（`wf_s{st}_{n}`/`wf_c{st}_{n}`），信号名含级/序号，
  结构完全确定。
- 头部注释记录位宽与重新生成命令。

## 3. 深度分析

- Wallace 归约级数：约 `log_1.5(DATA_W)`（FA 3→2）；+ 收尾 ripple-carry
  `NBITS` 级。
- 例：W=32 生成 118 行、W=64 生成 203 行（见 rtl/gen/）。

## 4. PPA 特点

- 门数较省（每 3 位 1 个 FA）；连线较不规则。
- 收尾 ripple-carry 是 W 增大后主要时序瓶颈（可换 carry-lookahead 优化，G6 后记）。

## 5. 验证与约束

- 正确性由 G4 随机/等价覆盖（tc_random/tc_equiv）。
- 位宽约束：仅 `DATA_W∈{8,16,32,64}`（PC-004）。
