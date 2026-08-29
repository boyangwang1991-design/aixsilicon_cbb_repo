# 详细设计（Detail Design）— skid_buffer / impl_backward（IMPL=2）

> implement-cbb-rtl step 1/8 产物：微架构、逻辑深度、守恒论证、**PPA 优化点**、生成方式决策。
> 对应 registry `STR-005 backward_register_slice`（A3/P0，ready registered，反压关键路径）。

## 1. 微架构

**backward registered slice**（反向打拍：**ready 路径寄存**，valid/data 组合透传）：

| 信号 | 类型 | 说明 |
|---|---|---|
| `in_ready_r` | FF | 寄存的 `in_ready`（输出给上游，**切断反压组合链**） |
| `out_valid` / `out_data` | 组合 | `= in_valid` / `= in_data`（**透传，0 数据延迟**） |

```
  in_valid ─▶ out_valid（透传）          in_ready_r <= out_ready | ~in_valid
  in_data  ─▶ out_data （透传）
  out_ready ─▶ [in_ready_r] ─▶ in_ready（FF 输出，切断反压组合链）
```

状态更新（单 FF）：
```
in_ready_r <= out_ready | ~in_valid;    // 下游可接受 或 输入无效 → 下一拍 ready
```

- **核心目标**：`in_ready` 为 **FF 输出**，切断"下游 ready → 上游 in_ready"的长组合反压链
  （深流水反压路径关键路径改善）；
- **代价**：反压 1 拍延迟传导（`out_ready` 拉低后下一拍 `in_ready` 才拉低），数据透传无打拍。

## 2. 逻辑深度

| 路径 | 起点→终点 | 逻辑深度 |
|---|---|---|
| 数据 | `in_data → out_data` | 0 级（组合透传） |
| valid | `in_valid → out_valid` | 0 级（组合透传） |
| ready（关键） | `out_ready / in_valid → in_ready_r(D)` → `in_ready` | 0 级到 FF + FF 输出（**切断组合链**） |

## 3. 守恒论证

- **无丢**：`in_ready` 为寄存值；`in_ready=0` 时输入不被采样（上游反压），数据在输出保持
  （透传 + in_valid 稳定），无丢失；
- **保序**：组合透传，顺序不变；
- **0 数据延迟**：`out_valid/out_data` 透传（无打拍），`##1` 无额外延迟；
- **反压 1 拍延迟**：`~out_ready && in_valid |-> ##1 ~in_ready`——下游背压下一拍传导到上游。

## 4. PPA 优化点（implement-cbb-rtl step 8 强制）

### 4.1 面积
- 构成：**1 个 FF（in_ready_r）**，无数据寄存器、无 mux、无槽——**面积最小**（
  vs forward 的 DATA_W+1 FF、full 的 2×(DATA_W+1)+mux）；
- 下界：切反压链最少 1 FF，本实现达下界。

### 4.2 时序
- **ready 关键路径**：`out_ready → in_ready_r(D)`（0 级组合到 FF）+ `in_ready_r → in_ready`
  （FF 输出）——**反压路径被寄存打断**，深流水串联时反压链不叠加（vs forward 的组合透传
  反压链沿链叠加）；
- **数据路径**：透传（0 级），无寄存器 → 数据时序最优；
- 主频上界：`out_ready/in_valid → in_ready_r`（1 级 Tsetup），400MHz 余量极大（预期 slack
  ≈ 周期 - 极小组合，> 1.8ns @400MHz）。

### 4.3 功耗
- 仅 1 FF 翻转（in_ready_r），数据路径无寄存器 → **功耗最低**；
- 透传数据无寄存（不增加翻转负担）。

### 4.4 Pareto 定位
- vs `forward`（数据打拍 / ready 透传）：backward 反过来——**ready 寄存 / 数据透传**；
  面积均小，backward 面积更小（1 FF）；
- vs `full`：backward 无缓冲能力（不提供槽/提前接受），吞吐在背压恢复时有 1 拍气泡，
  但反压链更短、面积/功耗最低；
- **适用**：**反压路径（ready 链）时序瓶颈**、数据路径无需打拍、面积/功耗极敏感场景；
- vs `STR-005 backward_register_slice`：本实现即其标准形式。

## 5. 生成方式决策

单实现单文件（`rtl/impl/backward/skid_buffer.sv`），无 Python 生成器；参数 `DATA_W`（透传
位宽，仅影响 wire 宽）。

## 6. 综合收敛风险

- 无 latch/组合环；`in_ready` 为 FF 输出（非组合），无协议 waiver 争议；
- 透传输出（out_valid/out_data 组合）为协议语义（waiver 见 `../verification/lint_waivers.md`）。
