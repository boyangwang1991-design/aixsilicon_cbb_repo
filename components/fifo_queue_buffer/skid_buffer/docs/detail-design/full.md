# 详细设计（Detail Design）— skid_buffer / impl_full（IMPL=1）

> implement-cbb-rtl step 1/8 产物：微架构、逻辑深度、守恒论证、**PPA 优化点**、生成方式决策。

## 1. 微架构

**full register slice（OUT 寄存 + SKID 槽，bubble-free 满吞吐）**：

| 信号 | 类型 | 说明 |
|---|---|---|
| `out_valid_r` / `out_data_r` | FF | OUT 寄存级（输出端口直接取此） |
| `buf_valid_r` / `buf_data_r` | FF | SKID 槽（背压吸收） |
| `in_ready` | 组合 | `~out_valid_r | out_ready | ~buf_valid_r`（全满才反压） |
| OUT 装载 | 组合/FF | 腾出（`out_ready \| ~out_valid_r`）时**槽优先**（FIFO 保序），槽空才直达输入 |

```
  in_valid ─▶ OUT 级(out_valid_r) + SKID 槽(buf_valid_r) ─▶ out_valid
  in_data  ─▶   装载选择（槽优先 / 输入直达）             ─▶ out_data
  out_ready ─▶ in_ready（组合，深度≤1，由寄存状态决定）
```

## 2. 逻辑深度

| 路径 | 起点→终点 | 逻辑深度 |
|---|---|---|
| 数据快路径 | `in_data → out_data_r(FF)` | 0 级组合（直达） |
| 数据背压路径 | `buf_data_r → mux → out_data_r` | 1 级（2:1 mux）+ 2 级 FF |
| ready 路径 | `out_valid_r/out_ready/buf_valid_r → in_ready` | 0~1 级（OR/AND） |
| 控制路径 | `out_ready → 装载选择 → FF` | 1 级 |

## 3. 守恒论证

- **满吞吐**：`in_valid && in_ready |-> ##1 out_valid`——接受后下一拍输出级必有效；
- **不丢**：全满（`out_valid && ~out_ready && buf_valid`）才反压，输入仅在 `in_ready` 时被采样；
- **保序**：输出级腾出时**槽数据优先**（FIFO 顺序），新输入仅在槽空时直达；
- **槽容量守恒**：槽写入仅在 `in_valid && in_ready` 且输出级满未腾出（槽必空）或槽补输出级
  时被新输入替换；清空仅在槽补输出级且无输入替换时，无溢出/下溢。

## 4. PPA 优化点（implement-cbb-rtl step 8 强制）

### 4.1 面积
- 构成：2×DATA_W 数据 FF + 2 valid FF + DATA_W 宽 2:1 mux（OUT 装载选择）+ 控制逻辑；
- 下界：保序满吞吐打拍至少需要"输出级 + 1 槽"，即 ≥2×DATA_W FF——本实现达下界；
- vs forward：多 1×DATA_W+1 FF + mux，换**满吞吐无气泡 + 切断 ready 组合链**。

### 4.2 时序
- 数据/ready 关键路径均 ≤1 级组合；`in_ready` 由**寄存状态**（`out_valid_r`/`buf_valid_r`）+ `out_ready`
  决定——**切断反压组合链**（vs forward 的 `in_ready=out_ready` 深链透传）；
- 主频上界：`buf_data_r → mux → out_data_r`（1 级 + Tcq + Tsetup），400MHz 收敛；
  实测（run-20260829-01）：W8/W32/W128 worst_slack = 1.35 / 0.81 / 0.39ns，全 MET
  （随位宽下降，mux 扇出增大）；
- 优化杠杆：更高主频可用 ICG 替代装载 mux（白名单结构，Profile 层）。

### 4.3 功耗
- 空闲（`in_valid=0`）：OUT/SKID 数据寄存器不更新（无输入直达/槽替换），翻转功耗低；
- 满吞吐：`out_data_r` 每拍翻转，与 DATA_W 线性；
- 优化杠杆：数据路径 ICG（白名单结构，未引入）。

### 4.4 Pareto 定位
- vs `impl_forward`：多 1 槽面积换**满吞吐无气泡 + 短 ready 反压路径**（反压由寄存状态
  决定，深流水链短）；
- **适用**：背压频繁、反压链长（深流水）、需满吞吐无气泡场景；
- vs `STR-006 full_register_slice`：同拓扑等价（本实现即 full 的 skid 变体）。

## 5. 生成方式决策

单实现单文件（`rtl/impl/full/skid_buffer.sv`），无 Python 生成器；参数 `DATA_W`。

## 6. 综合收敛风险

- 无 latch/组合环（always_ff 全同步 + 组合 assign 无反馈）；
- `in_ready` 组合输出为协议语义（waiver 见 `../verification/lint_waivers.md`）。
