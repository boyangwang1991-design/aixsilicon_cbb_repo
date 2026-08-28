# popcount 设计（G2）

## 1. 模块划分

```
popcount.sv（wrapper）
├── 参数检查 generate（PC-001..004 $error）
├── 实现分派 generate（PC_IMPL 0..4）
│   ├── popcount_impl_direct   （0 direct）
│   ├── popcount_impl_tree     （1 tree）
│   ├── rtl/gen/（生成器产物）  （2 wallace / 3 comp4_2）
│   └── popcount_impl_lut      （4 lut）
└── 就近 SVA（INV-001/002 黄金参考断言，验证期生效）
```

- `popcount.sv` 通过 `` `include "gen/..." `` 引入生成模块；`include_dirs=rtl/`。
- 生成模块非参数化（端口一致：`din[DATA_W-1:0]`、`popcnt[NBITS-1:0]`），由
  generate 内 `if (W==..)` 实例化。

## 2. 多实现设计要点

### direct
```
acc[0]=0; acc[i+1]=acc[i]+din[i];  popcnt=acc[W]   （O(W) 加法器链）
```

### tree
```
lv[0][j]=din[j]；lv[s][j]=lv[s-1][2j]+lv[s-1][2j+1]（奇数直通）
popcnt=lv[NLEV-1][0]                                 （O(log W) 折半）
```

### wallace / comp4_2（生成器，见 detail-design）
- 归约模型：初始仅权重 0 列含全部输入位；逐级把每列 3→FA / 2→HA（或 4→4:2），
  carry 抬入高权重列；权重列守恒（每列 bit 数 × 2^权重 之和 = 输入 1 个数）。
- 归约至每列 ≤2 构成两行 → NBITS 位 ripple-carry 收尾。
- 4:2 链：列间 cin（低列 cout）→ cout，链末 cout 作为普通进位进高列。

### lut
```
blk[b]=lut4(din[4b+:4])；lv0=3bit；折半加法树合并 → popcnt
```

## 3. 时钟/复位

无（纯组合）。无时序状态。

## 4. 生成器纪律（SSOT 与派生物）

- `tools/gen_popcount.py` 为 **SSOT**：位宽集、归约策略、模块名均由其决定。
- `rtl/gen/*.sv` 为 **派生物**：`python3 tools/gen_popcount.py` 重新生成，不手改。
- 生成物头部含"重新生成"命令，供审计。
- 新增位宽：改生成器 `--widths` 运行 → 更新 `cbb.yaml` PC-004 合法域 → 更新
  `verification/configs/mandatory.yaml`。

## 5. Profile（见 profiles.yaml）

| Profile | PC_IMPL | 场景 |
|---|---|---|
| prof_small_area | lut | 面积优先（小位宽） |
| prof_min_latency | comp4_2 | 时序优先 |
| prof_balanced | tree | 默认通用 |
| prof_reference | direct | 基线参照 |
| prof_wallace | wallace | 经典压缩/门数 |

## 6. 验证策略

- G3 静态：compile/elab 矩阵（五实现 × {8,16,32,64}）+ 负向参数拦截 + SpyGlass lint。
- G4 功能：穷举 W4 × 五实现 + 边界 + 4000 随机 × W{8,16,32,64} × 五实现（黄金 + 等价）。
- G6 PPA：五实现 × {8,16,32,64} 综合 sweep（sc9_cmos28lp_base_hvt）。
