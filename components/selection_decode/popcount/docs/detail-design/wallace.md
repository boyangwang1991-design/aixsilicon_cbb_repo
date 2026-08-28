# popcount — impl_wallace 详细设计说明书

## 1. 实现标识

| 项 | 值 |
|---|---|
| implementation id | `impl_wallace` |
| module / 文件 | `popcount_impl_wallace` @ `rtl/popcount_compressed.sv` |
| PC 选择值 | `PC_IMPL=1`（需 `+define+POPCNT_WALLACE_ON`） |
| Profile 挂接 | `wallace_exp`（experimental） |
| 生成方式 | **gen_schedule.py 生成**（显式 FA 网表，W=64 物化档；再生成：`uv run python gen_schedule.py`） |

## 2. 微架构说明

Wallace 贪婪 3:2 压缩：每轮对每列取 floor(n/3) 个 FA，
SUM 留本列（列内 −2 净变化）、CARRY 进右列（+1 dot 权 2^(c+1)）。
发射形态为**打平 assign 网表**：`assign {cout,s} = a+b+c;` 每行一个真 FA，
无 generate/循环/%//（403 行 W=64 物化）。

- **逻辑深度**：压缩段 ⌈log₁.₅(W/2)⌉ 级 FA 链 + 1 级收尾加法；W=64 → 约 3 级 FA + CPAdder；
- 面积要素：W=64 物化 **57 个 FA**（每 FA ≈ 4.8μm² @SC9 HVT 实测折算）。

## 3. 权值/功能守恒论证

- FA 权值恒等式：a+b+c = 2·CARRY + SUM（三输入权 3·2^c = 输出 2^{c+1}+2^c）✓；
- 列界：任一列有效 dot ≤ W（[W-1:0] 容器充分）；
- 收敛：高度序列 max ≤ 2 时两行提取，row_a+row_b 权重已在列位编码；
- 验证锚点：all0=0 / all1=64 / 500 随机零失配（SV 网表 TB）+
  **Python bit-exact verify_netlist.py**（W≤14 全空间穷举 + 大 W 定 seed 随机 20/20 PASS）。

## 4. 参数化行为

| 参数 | 域 | 敏感度 |
|---|---|---|
| INPUT_WIDTH | 当前仅 64 档物化 | 其它档触发 g_fixed_w `$error`；扩展=生成器重跑 |

## 5. 验证映射

| 需求/不变量 | 手段 | 证据 |
|---|---|---|
| REQ-001/INV-001 | 网表 TB + verify_netlist.py | /tmp 证据脚本可重放；Python PASS 20/20 |
| REQ-003/INV-003 | fm_shell LEC vs impl_tree | evidence/g4_functional/equiv_lec.txt |

## 6. PPA 摘录（run-20260827-03）

| W | area μm² | slack ns |
|---|---|---|
| 64 | 271.21 | 0.00（MET） |

**定位**：被 tree 面积支配（2.2×），experimental 探索资产；
但对比列计数递推（1258μm²/−1.11）**−78% 面积**——显式 FA 结构化路线的实证成功。

## 7. 已知限制

固定 W=64 单档；X 输入不承诺；探索用途不进量产推荐。

## 8. 变更记录

| Change | 日期 | 摘要 |
|---|---|---|
| C2 | 2026-08-27 | 引入（Python 生成网表替代手写调度） |
| C3 | 2026-08-28 | dadda 移除后为唯一压缩核实现 |
