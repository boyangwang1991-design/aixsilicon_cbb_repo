# 详细设计（Detail Design）— skid_buffer / impl_output_registered

> implement-cbb-rtl step 1/8 产物：微架构、逻辑深度、守恒论证、**PPA 优化点**、生成方式决策。

## 1. 微架构描述

两级 bubble-free 拓扑（同 `docs/design.md` §2）：

| 信号 | 类型 | 说明 |
|---|---|---|
| `out_valid_r` / `out_data_r` | FF | OUT 寄存级（输出端口直接取此） |
| `buf_valid_r` / `buf_data_r` | FF | SKID 槽（背压吸收） |
| `in_ready` | 组合 | `~out_valid_r | out_ready | ~buf_valid_r` |
| OUT 装载 | 组合/FF | 腾出（`out_ready \| ~out_valid_r`）时**槽优先**（FIFO 保序），槽空才直达输入 |
| 输入捕获 | 组合/FF | 接受（`in_valid & in_ready`）时直达输出级或替换/写入槽（槽必空） |

## 2. 逻辑深度推导

| 路径 | 起点→终点 | 逻辑深度 |
|---|---|---|
| 数据快路径 | `in_data → out_data_r(FF)` | 0 级组合（输入直达 OUT 寄存） |
| 数据背压路径 | `buf_data_r → mux → out_data_r` | 1 级（2:1 mux）+ 2 级 FF |
| ready 路径 | `out_valid_r/out_ready/buf_valid_r → in_ready` | 0~1 级（OR/AND，可被 DC 合并） |
| 控制路径 | `out_ready → OUT/槽装载选择 → FF` | 1 级 |

数据关键路径 = 1 级组合（DATA_W 宽 2:1 mux），时序风险极低；
ready 关键路径 ≤1 级，满足"切断 ready 组合链"目标。

## 3. 守恒论证

见 `docs/design.md` §3（满吞吐/不丢/无重/槽容量守恒四要素）。

## 4. PPA 优化点（implement-cbb-rtl step 8 强制）

### 4.1 面积
- **构成**：数据寄存器 2×DATA_W FF（OUT + SKID）+ 1 个 DATA_W 宽 2:1 mux（OUT 装载选择）+ 控制逻辑（2 有效位 + 2 select）。
- **下界**：保序打拍至少需要"输出级 + 1 槽缓存"，即 ≥2×DATA_W FF——本实现已处于面积下界。
- **杠杆**：DATA_W 是唯一面积杠杆（线性）。DATA_W=1024 时面积 ~2K FF + 2K 宽 mux，
  大宽度场景（>512）建议评估拆分为流水分片（属 QUE-008 多级打拍范畴，非本 CBB）。

### 4.2 时序（2026-08-29 修正：主判据 = reg→reg 最差 setup slack）
- 数据/ready 关键路径均 ≤1 级组合，综合收敛风险极低；
- **主判据**：skid buffer 为时序模块（含寄存器），PPA 时序用 **reg→reg 最差 setup slack**
  判定（`create_clock` 须绑定 `clk` 端口，否则 FF 无 setup 约束、报告只有组合 arrival）；
  实测（run-20260828-07，400MHz）：W8/W32/W128 worst_slack = 1.35 / 0.81 / 0.39ns，全部
  MET——主频上界由 `buf_data_r → mux → out_data_r`（1 级 + Tcq + Tsetup）决定，400MHz
  收敛，W128 为最紧（扇出增大）；600MHz 上限需进一步 slack 验证；
- **优化杠杆**：若需更高频率，可把 OUT 装载 mux 用门控时钟替代（引入 ICG 属低功耗
  白名单结构，本版本不引入——面积/DFT 权衡留给 Profile 层）。

### 4.3 功耗
- **空闲**：`in_valid=0` 时 OUT/SKID 数据寄存器不更新（无输入直达/槽替换），
  无输入翻转 → 空闲功耗低；
- **数据翻转**：满吞吐时 `out_data_r` 每拍翻转（输入直达），翻转功耗与 DATA_W 线性相关；
- **优化杠杆**：数据路径 ICG（时钟门控）可显著降翻转功耗，但引入 ICG/DFT/低功耗
  约束（domain-rules §3.3）——本 A3 版本不默认引入，留作 Profile 扩展点。

### 4.4 Pareto 定位
- vs `forward_register_slice`（STR-004）：skid 多 1 槽（+DATA_W FF）换**满吞吐无气泡**
  与**短 ready 路径**；forward 面积更小但背压有气泡、ready 组合链更长；
- vs `full_register_slice`（STR-006）：skid 是 full 的 skid 变体，面积/时序等价；
- **结论**：本构件在"满吞吐 + 最短 ready 路径"目标上为 Pareto 最优（同面积等级下）。

## 5. 生成方式决策

- 单实现、单文件 RTL，**无需 Python 生成器**（无展开/无多实现同构）；
- 位宽参数化用 `localparam + generate $error`，极简单文件（对齐 sync_fifo 默认规范）。

## 6. 综合收敛风险

- 无 X 优化、无 latch、无组合环（检查：always_ff 全同步 + 组合 assign 无反馈）；
- `in_ready` 组合输出为协议语义（waiver 记录见 `../verification/lint_waivers.md`）。
