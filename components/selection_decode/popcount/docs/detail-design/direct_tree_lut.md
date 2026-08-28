# direct / tree / lut 详设（PC_IMPL=0/1/4，手写）

## direct（PC_IMPL=0）— 直接加法基线

```
acc[0] = 0
acc[i+1] = acc[i] + din[i]     // i = 0..DATA_W-1，W+1 位防溢出
popcnt = acc[DATA_W]
```

- O(W) 级串行加法器链（每级 1 个加法器），深度线性。
- 最直观、面积最小、时序最差；作为 PPA 参照基线（prof_reference）。
- 任意位宽可用（2..1024）。

## tree（PC_IMPL=1）— 平衡归约树

```
lv[0][j] = din[j]                                   // 叶子
lv[s][j] = lv[s-1][2j] + lv[s-1][2j+1]（奇数直通）   // 折半
popcnt = lv[NLEV-1][0]                              // NLEV=clog2(W)+1
```

- O(log W) 级、全并行；末级单节点即结果。
- 深度最小、时序优、面积中等；默认通用（prof_balanced）。
- 任意位宽可用（2..1024）。

## lut（PC_IMPL=4）— LUT 查找表

```
lut4(v) = popcount of 4 bits（case 真值表，0..4 → 3bit）
blk[b] = lut4(din[4b+:4])                           // 子块查表
lv0 = 3bit；折半加法树合并 → popcnt
```

- 每 4 输入位一个 3-bit 计数真值表（综合映射为查找表/复用逻辑），再以折半加法树合并。
- 结构规整、面积可控，适合小位宽面积优先（prof_small_area）。
- 任意位宽可用（2..1024，末块不足 4bit 高位补 0）。

## 三实现共性

- 均为手写参数化 generate（`popcount_impl_*`），任意位宽可用（与生成版互补）。
- 均以 `ripple_add` / `+` 加法为基础，综合后结构稳定。
- 正确性由 G4 穷举/随机/等价覆盖。
