# comp4_2 详设（PC_IMPL=3，生成器展开）

## 1. 结构

4:2 compressor 归约模型：

- **4:2 compressor**：同权重列每 4 个 bit（a,b,c,d）+ 列间 `cin`，输出
  `sum`（同列）、`carry`（高列）、`cout`（传给高列 4:2 的 cin）：
  ```
  s1 = a ^ b ^ cin;        cout = maj3(a,b,cin)
  sum = s1 ^ c ^ d;        carry = maj3(s1,c,d)
  ```
- **列间链**：连续 `len>=4` 的列构成链，第 k 列的 `cout` → 第 k+1 列的 `cin`；
  链首 `cin=0`，链末 `cout` 作为普通进位抬入高列。
- 不足 4 的列用 FA(3→)/HA(2→)/pass(1→)。
- 归约至每列 ≤2 → 两行 → NBITS 位 ripple-carry 收尾。

**正确性**：4:2 把 4 个权重 w 的 bit + 1 个权重 w+1 的进位，转换为权重 w 的 1 bit +
权重 w+1 的 2 bit（sum/carry/cout 合并），权重守恒。

## 2. 生成器（tools/gen_popcount.py）

- 每轮先找连续 `len>=4` 的列段，生成 4:2 链（链末 cout 复用，不重复声明）。
- 其余列/剩余项用 FA/HA/pass。
- 输出扁平 `assign`（`cs_*`/`cf_*`/`ch_*`）。

## 3. 深度分析

- 每级归约 4→2，级数约 `log_2(DATA_W/2)`（较 Wallace 的 `log_1.5` 更少）。
- 例：W=16 生成 72 行、W=32 生成 113 行、W=64 生成 206 行（见 rtl/gen/）。

## 4. PPA 特点

- 关键路径最短（级数最少 + 列间链规整），适合时序敏感场景（prof_min_latency）。
- 面积略增（每 4 bit 的 4:2 ≈ 2 个 FA）。

## 5. 验证与约束

- 正确性由 G4 随机/等价覆盖。
- 位宽约束：仅 `DATA_W∈{8,16,32,64}`（PC-004）。
