# skid_buffer

**Valid-Ready Skid Buffer（QUE-007，A3/P0）** —— 1 槽缓冲切断 ready 组合链的 vld rdy 打拍模块。

## 需求说明

在 valid-ready（ready-valid）数据通路上插入一级打拍寄存器，用于改善时序：

- **切断 ready 组合链**：`out_valid`/`out_data` 完全寄存（FF 驱动），`in_ready` 只组合依赖
  寄存状态（`out_valid_r`、`buf_valid_r`）与下游 `out_ready`，组合深度 ≤1 级；
- **满吞吐无气泡**：SKID 槽在背压时吸收输入，`in_valid && in_ready |-> ##1 out_valid`，
  不产生气泡丢拍；背压恢复后无额外空泡；
- **保序**：输入到输出 FIFO 顺序不变，无丢无重。

## 接口

| 端口 | 方向 | 说明 |
|---|---|---|
| `clk` / `rst_n` | in | 时钟 / 低有效异步复位 |
| `in_valid` / `in_data[DATA_W-1:0]` / `in_ready` | 握手 | 输入 valid-ready |
| `out_valid` / `out_data[DATA_W-1:0]` / `out_ready` | 握手 | 输出 valid-ready（寄存） |

参数：`DATA_W`（位宽，1~1024，默认 32）。

## 验证状态

- G3 静态基线：VCS 正向编译矩阵（DATA_W∈{1,8,32,64,128}）+ 负向 $error 拦截
- G4 功能：随机/背压/边界场景 + 参考模型队列比对 + SVA 属性仿真
- 配置集由 `cbb_tool.py config-gen` 确定性生成（`verification/configs/`）

详见 [`docs/cbb_spec.md`](docs/cbb_spec.md) 与 [`docs/intake.md`](docs/intake.md)。
