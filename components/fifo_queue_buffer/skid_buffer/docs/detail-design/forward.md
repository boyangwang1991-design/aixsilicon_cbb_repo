# 详细设计（Detail Design）— skid_buffer / impl_forward（IMPL=0）

> implement-cbb-rtl step 1/8 产物：微架构、逻辑深度、守恒论证、**PPA 优化点**、生成方式决策。

## 1. 微架构

**forward register slice**（简单打拍，面积最小）：

| 信号 | 类型 | 说明 |
|---|---|---|
| `out_valid_r` | FF | valid 打拍（`<= in_valid`，每拍无条件） |
| `out_data_r[DW-1:0]` | FF | data 打拍（`<= in_data`，每拍无条件） |
| `in_ready` | 组合 | `= out_ready`（ready 组合透传，背压直接传导上游） |

```
  in_valid ─▶ (D) [out_valid_r] ─▶ out_valid      in_ready = out_ready
  in_data  ─▶ (D) [out_data_r ] ─▶ out_data
```

无 SKID 槽；valid/data 各 1 级打拍，延迟 1 拍；ready 方向不寄存（透传）。

### 1.1 波形图（Wavedrom）

打拍时序（5 拍）：`in_valid/in_data` 在拍 t 打拍，**拍 t+1** 在 `out_valid/out_data` 显示
（1 拍延迟）；`in_ready == out_ready`（组合透传，背压直接传导上游）。

```wavedrom
{ "signal": [
  { "name": "clk",        "wave": "p....." },
  { "name": "in_valid",   "wave": "1.010" },
  { "name": "in_ready",   "wave": "1...." },
  { "name": "in_data",    "wave": "22.2.", "data": ["A", "B", "C"] },
  { "name": "out_valid",  "wave": "01.01" },
  { "name": "out_data",   "wave": ".22.2", "data": ["A", "B", "C"] }
], "head": { "tick": 0, "every": 1 } }
```

### 1.2 电路图（Wavedrom Circuit）

`out_valid_r/out_data_r` 打拍 FF（`D=in_valid/in_data`，无条件）；`in_ready` 与 `out_ready` 直连（透传）。

```wavedrom
{ "circuit": {
  "input": ["out_ready", "in_valid", "in_data[7:0]"],
  "output": ["in_ready", "out_valid", "out_data[7:0]"],
  "reg": [
    { "name": "out_valid_r", "in": "in_valid", "out": "out_valid" },
    { "name": "out_data_r",  "in": "in_data",  "out": "out_data" }
  ],
  "assign": [ ["in_ready", "out_ready"] ]
}}
```

## 2. 逻辑深度

| 路径 | 起点→终点 | 逻辑深度 |
|---|---|---|
| 数据 | `in_data → out_data_r(FF)` | 0 级组合（打拍） |
| ready | `out_ready → in_ready` | 0 级（直连透传） |
| 输出 | `out_valid_r → out_valid` | 0 级（FF 直连） |

## 3. 守恒论证

- **1 拍延迟**：沿 t `in_valid` 打拍，沿 t+1 `out_valid` 显示（`in_valid && in_ready |-> ##1 out_valid`）；
- **无丢**：`in_ready == out_ready`——下游不 ready 时输入被反压、不被采样，无数据丢失；
- **保序**：单级 FIFO 打拍，顺序不变；
- **吞吐**：打拍直通，`in_ready` 与 `out_ready` 同步，无内部气泡（背压完全由下游 ready 决定）。

## 4. PPA 优化点（implement-cbb-rtl step 8 强制）

### 4.1 面积
- 构成：`DATA_W` 数据 FF + 1 valid FF，**无 mux、无 SKID 槽**——同功能下面积最小
  （vs full 少 1×DATA_W+1 FF 与 DATA_W 宽 mux）；
- 下界：≥DATA_W+1 FF（单级打拍），本实现达下界。

### 4.2 时序（实测 run-20260829-01）
- 数据/ready 均 0 级组合（打拍/透传），综合收敛风险极低；
- **ready 链特征**：`in_ready = out_ready` 为**组合透传**——单级延迟极小，但**深流水串联时
  反压路径为组合链叠加**（消费端 ready 组合深度沿链传播）；相比 full 用寄存状态切断，
  forward 的反压路径在深链中更长（ready 到最上游的 combinational path）；
- **实测**（400MHz）：W8/W32/W128 worst_slack 恒 2.02ns（MET，无 mux、打拍路径极短，
  与位宽无关）；IO arrival 0.02ns；面积 23.5/85.8/333.7 µm²。

### 4.3 功耗
- 打拍 FF 每拍无条件更新（含 in_valid=0 时写入 0），数据 FF 翻转取决于输入；
- 无使能/门控——空闲功耗略高于带槽的 full（full 在无输入时寄存器保持）；
- 优化杠杆：ICG/使能（白名单结构，Profile 层）。

### 4.4 Pareto 定位
- vs `impl_full`：面积最小（少 1 槽）、ready 单级延迟小，但**反压路径为组合透传**
  （深流水反压链长）、无满吞吐提前缓冲能力；
- **适用**：面积/延迟敏感、反压链短（浅流水）或下游 ready 相对稳定场景。

## 5. 生成方式决策

单实现单文件（`rtl/impl/forward/skid_buffer.sv`），无 Python 生成器；参数 `DATA_W`。

## 6. 综合收敛风险

- 无 latch/组合环；`in_ready` 组合透传为协议语义（waiver）；
- 无条件打拍 FF 无时钟使能，无多驱动。
