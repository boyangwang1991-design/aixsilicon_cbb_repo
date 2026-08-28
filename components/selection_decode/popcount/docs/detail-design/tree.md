# popcount — impl_tree 详细设计说明书

## 1. 实现标识

| 项 | 值 |
|---|---|
| implementation id | `impl_tree`（cbb.yaml implementations[].id） |
| module / 文件 | `popcount_impl_tree` @ `rtl/popcount.sv`（手写直写） |
| PC 选择值 | `PC_IMPL=0` |
| Profile 挂接 | `tree_default`（supported，默认推荐） |
| 生成方式 | 手写 |

## 2. 微架构说明

平衡二分加法树：W 个 1-bit 起始 dot → generate 分层两两归并，层 k 将两个
(k)-bit 部分和相加得 ((k+1))-bit；奇数末项直通补零。

```
col0  dots ──► [FA/HA 对] ──► [FA/HA 对] ──► ... ──► 根节点 = cnt
       W 个         W/2           W/4                1
```

- **逻辑深度**：LEVELS = ⌈log₂W⌉+1 层；W=64 → 7 层（6 级 FA 加 1 级位展开）；
- 面积要素：层 k 节点数 ⌈W/2^k⌉，全树 ≈ W−1 个加法单元（FA/HA 混合，综合器自选）。

## 3. 权值/功能守恒论证

- 每次两两归并权值不变（a+b 权 = (a,b) 权和）；直通不改权。
  归纳可得根 = Σ data_i[b] = Hamming 权重；
- 边界：全 0 → 各层全零 → 根 0；全 1 → 层 0 全 1，逐层 2 幂和 → 根 = W；
  节点位宽 CNT_W=log₂(W+1) 覆盖最大值 W，无溢出；
- 反模式自查：无 `%//`、无运行时除法、纯 generate 静态展开 ✓。

## 4. 参数化行为

| 参数 | 域 | 敏感度 |
|---|---|---|
| INPUT_WIDTH | 4~256 | 深度 ⌈log₂W⌉+1；面积 ≈ O(W)（折叠后综合器优化为 O(W) 门） |

防护：PC-001（4≤W≤256）elaboration `$error`；CNT_W 一致性卫兵。

## 5. 验证映射

| 需求/不变量 | 手段 | 证据 |
|---|---|---|
| REQ-001/INV-001 | tc_exhaust_w8（256 全空间）+ random3000 | evidence/g4_functional/functional_sim.txt |
| REQ-002/INV-002 | tc_edge 锚点 | 同上 |
| REQ-003 | fm_shell LEC reference | evidence/g4_functional/equiv_lec.txt |
| 编译矩阵 | 6 宽度 × 三实现 | evidence/g3_static/param_matrix.txt |

## 6. PPA 摘录（run-20260827-03）

| W | area μm² | slack ns |
|---|---|---|
| 8 | 12.05 | +0.53 |
| 16 | 27.26 | +0.43 |
| 32 | 64.82 | +0.07 |
| 64 | **124.02** | **+0.09** |
| 128 | 248.74 | +0.04 |

**Pareto 全宽度支配点**——tree_default 推荐依据。

## 7. 已知限制

X 输入不承诺输出（ASM-001）；>256 超出契约域。

## 8. 变更记录

| Change | 日期 | 摘要 |
|---|---|---|
| C0 | 2026-08-27 | 初版 |
| C3 | 2026-08-28 | 打平布局并入 popcount.sv |
