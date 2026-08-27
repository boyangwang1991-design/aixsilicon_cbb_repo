# popcount 架构设计（G2，方案冻结稿 · 待线下评审）

> 生命周期 C2 产物。前置：契约（[`cbb.yaml`](../cbb.yaml)/[`behavior.yaml`](../behavior.yaml)）已通过 G1。
> **状态**：本文件为讨论用**方案冻结稿**——RTL 未实施；评审通过后据此进入 C3。
> 审查依据：cbb-development-suite design-cbb / domain-rules §2-§4。

## 0. 方案要点与决策记录

| 项 | 决策 | 理由 |
|---|---|---|
| 接口形态 | 纯组合、无时钟端口 | A1 原子机制定位：功能单一、消费侧自行打拍；保持最短关键路径与最大集成弹性 |
| 实现集合 | `impl_tree` + `impl_column_compress` + `impl_lookup` 三实现 | 兑现 registry SEL-014 implementation 字段三条路径（adder tree/compressor/lookup），支撑"面积/时序 Pareto"目标 |
| 输出位宽 | `$clog2(INPUT_WIDTH+1)` 全精度 | 计数值域 [0, W]，无截断假设，防隐式截断（domain-rules §3.1） |
| 等价性策略 | fm_shell LEC 两两互等 + 仿真对黄金模型 | 本机 FM 可用；多实现共享契约的最强证据 |
| 默认推荐 | `impl_tree` | 逻辑深度 O(log W)、面积中庸、综合工具对其折叠优化成熟 |

## 1. 模块划分

三个实现**共享同一可观察契约**（端口/参数/时序语义一致），差异仅微架构。单实现布局：

```
popcount
├── data_i   : INPUT_WIDTH bit 向量输入
├── cnt_o    : $clog2(INPUT_WIDTH+1) bit Hamming 权重输出
├── impl_tree            : 平衡二分加法树（generate 递归宽度数组折叠）
├── impl_column_compress : 位矩阵逐列 (3,2)/(4,2) 压缩 → ≤2 行 → 进位传播加法器收尾
└── impl_lookup          : 按 CHUNK_W 分段 case 表 + 小型合并树
```

- RTL 布局：`rtl/popcount.sv` 为契约/公共入口（含 SVA 与参数检查）；
  多实现目录 `rtl/impl/<impl>/popcount.sv`（每文件保持极简单风格，不拆 package/interface）；
- 顶层（待 RTL 阶段定稿）：按 profile 选择实现——编译期 `PC_IMPL` generate-choice 或独立 wrapper，
  取"单文件检查豁免最小区"原则在 C3 细化。

### 1.1 impl_tree（平衡加法树，默认）

```systemverilog
// 折叠示意：一层归并 odd/even
always_comb begin
  automatic logic [CNT_W-1:0] acc;
  lvl[0] = '0; for (int b=0;b<W;b++) lvl[0][b][0] = data_i[b]; // 逐 bit 起始宽度 1
end
// 层 k 将 2 个 k-bit 部分和相加 → (k+1)-bit；非 2 幂时高位补零参与
```

- 起始层：W 个 1-bit 操作数 → 加法树各层宽度 `ceil(lvl_n/2)`，最深 `ceil(log2(W))+1` 层；
- 非 2 次幂 W：每层奇数个操作数时末项直通（补零参与求和，不改变结果）；
- 面积 ~O(W·logW) 等效门、深度 O(log W)。

### 1.2 impl_column_compress（列压缩，fmax 候选）

- 视角转换：Hamming 权重 = 对 W×cnt_max 位矩阵做**按位权列求和**；
- Stage-1：同列每 3 bit 用全加器 FA、每 4 bit 配合保留行压缩（(3,2)/(4,2) cell 由 generate 按列生成）；
- 迭代直至剩余行数 ≤ 2；
- Stage-2：剩 2 行做 `(A+B)` 窄进位传播加法器（宽度 = 按列权展开后的 CNT_W 列）。
- 关键路径最短处：压缩级联为恒定深度 d ≈ ceil(log_{1.5}(W/2))，末级只有一个窄 CPAdder；
- 复杂度高于 tree，但 DC 映射 DesignWare DMA/CFA 单元后大 W 时序优势明显（G6 待实证）。

### 1.3 impl_lookup（分段查找表）

```systemverilog
function automatic logic [CHUNK_W_CNT-1:0] lut8(input logic [7:0] w);
  case (w) ... endcase   // 综合推断小型 ROM/LUT 网络
endfunction
```

- 分段常量 `NSEG = ceil(W/CHUNK_W)`，CHUNK_W∈{4,8}；
- 各段查表结果经 NSEG 输入小加法树合并；
- 小 W（≤32）与 FPGA 目标下最优；ASIC 大 W 时表面积线性增长，作为 Pareto 左端点保留。

## 2. 多实现与 Profile

**共享同一可观察契约**（参数/行为一致），差异仅在 PPA trade-off（domain-rules §4）。

| Profile | implementation | 优化目标 | Use Case | 支持状态（目标） |
|---|---|---|---|---|
| `tree_default` | `impl_tree` | balanced | ECC 编码器/Hamming 校验等通用场景 | supported（G7 后） |
| `fmax_opt` | `impl_column_compress` | fmax | 高频性能计数器/带宽调度权重计算 | supported（G7 后，G6 数据支撑） |
| `lut_compact` | `impl_lookup` | area(小W)/FPGA | 小宽度计数、FPGA 移植视图 | experimental→supported（视 G6） |

Profile ≠ 参数污染：微架构选择挂接 profile/implementation，不进公共功能参数（domain-rules §2.3）。

## 3. 时钟复位 / 错误模型

| 项 | 定义 |
|---|---|
| 时钟域 | 无时钟端口（纯组合）；如需打拍由消费侧寄存 |
| 复位 | 不适用（无状态） |
| X 语义 | 输入含 X 时输出不作任何承诺（组合传播）；SVA 仅对 2-state 采样有效 |
| 异常行为 | 无握手/背压概念；非法参数由 elaboration `$error` 拦截 |

## 4. 关键数据路径（契约细化）

- 函数式定义：`cnt_o = Σ_{b=0}^{INPUT_WIDTH-1} data_i[b]`；
- 数值域验证锚点：
  - `data_i = '0` → `cnt_o == 0`；
  - `data_i = '1` → `cnt_o == INPUT_WIDTH`（上界，常被实现的位宽 off-by-one 打穿）；
  - one-hot 第 b 位 → `cnt_o == 1`（b∈全范围扫描）；
- 输出延迟：纯组合一级逻辑深度 `LOGIC_DEPTH(impl, W)`，作为 G6 的 timing 度量对象而非 latency 契约项。

## 5. 可验证性论证

| 验证形态 | 对象 | 说明 |
|---|---|---|
| Simulation 定向 | `tc_exhaust_w8` / `tc_edge` / `tc_random` | 黄金参考模型 for-loop 数位；W=8 全空间穷举 |
| Simulation 随机 | `tc_random`（seed 固定） | W∈{16,64} ≥1000 向量/impl |
| Formal LEC | impl 两两等价 | fm_shell reference vs implementation，W∈{8,33,64,127} 含非 2 幂 |
| 变异测试 | checker 有效性 | 截断部分和位宽/错位压缩注入 → 必须检出 |
| SVA 就近放置 | `PROP-PC_*-001..003` | 见 behavior.yaml INV 映射；模块内 assert property |

每个 Profile 有明确验证路径与 PROP 映射（详见 [`../verification/plan.yaml`](../verification/plan.yaml)，G4 期填充）。

## 6. PPA 预筛（E0/E1 定性趋势，G6 实证）

| 维度 | 定性预期（E0 exploratory） |
|---|---|
| area | lookup < tree < column_compress（小 W）；column_compress 收敛压力随 W 显著增长 |
| fmax | column_compress ≥ tree > lookup（大 W，W≥64 后差距拉大） |
| power | tree/column 数据翻转率相近；lookup 表项选择性翻转在小 W 占优 |

约束上下文（计划）：GF CMOS28LP + ARM SC9（`pdk-scan` 固化至 [`../characterization/pdk.yaml`](../characterization/pdk.yaml)），
典型主频 300–600 MHz、虚拟时钟从 400 MHz（2.5 ns）起步纯组合约束 Sweep；
矩阵 `{impl} × {8,16,32,64,128}` 输出 `(area, slack, dynamic_power, leakage)` → Pareto。

## 7. 子依赖

无嵌套子 CBB（原子机制）。`implementations[].dependencies: []`。
