# arithmetic_datapath — 算术与数值数据通路

对应 cbb_repo_list.md 第 4 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| ARI-001 | Incrementer/Decrementer | A1 | P0 | Counter专用优化 |
| ARI-002 | Adder/Subtractor | A1 | P0 | 位宽、进位结构、流水 |
| ARI-003 | Carry-save Adder | A1 | P1 | 多操作数压缩 |
| ARI-004 | Multi-operand Adder | A2 | P1 | 操作数数量与树平衡 |
| ARI-005 | Adder Tree | A2 | P1 | 流水级与吞吐 |
| ARI-006 | Accumulator | A2 | P0 | 反馈路径与门控 |
| ARI-007 | Absolute Value/Negate | A1 | P1 | 最小负数语义 |
| ARI-008 | Comparator | A1 | P0 | Early-out与关键路径 |
| ARI-009 | Multi-way Min/Max | A2 | P1 | 路数、索引回传 |
| ARI-010 | Clamp/Clip | A1 | P1 | 比较共享与常量特化 |
| ARI-011 | Saturating Add/Sub | A1 | P1 | 溢出判定与延迟 |
| ARI-012 | Fixed-point Round | A1 | P1 | 精度、偏差、随机源 |
| ARI-013 | Fixed-point Resize | A1 | P0 | 位宽最小化 |
| ARI-014 | Scale/Shift | A1 | P1 | 常量传播与复用 |
| ARI-015 | Logical/Arithmetic Shifter | A1/A2 | P1 | 面积、周期数、路由 |
| ARI-016 | Rotator/Funnel Shifter | A2 | P2 | 双输入拼接与布线 |
| ARI-017 | Integer Multiplier | A2 | P1 | 位宽、符号、流水 |
| ARI-018 | Constant Multiplier | A2 | P1 | 常量特化与共享 |
| ARI-019 | Multiply-Accumulate | A2 | P1 | 融合、截断、吞吐 |
| ARI-020 | Dot-product Engine | A2 | P2 | 并行度、累加宽度 |
| ARI-021 | Integer Divider | A2 | P2 | 面积/延迟/吞吐 |
| ARI-022 | Constant Divider | A2 | P2 | 误差与常量特化 |
| ARI-023 | Modulo/Reducer | A2 | P3 | 除法消除与延迟 |
| ARI-024 | Square/Sum-of-squares | A2 | P3 | DSP场景资源共享 |
| ARI-025 | Average/Weighted Sum | A2 | P2 | 系数与位宽增长 |
| ARI-026 | Reciprocal/RSqrt Approximation | A2 | P3 | 精度/延迟/面积 |
| ARI-027 | CORDIC | A2 | P3 | 迭代次数、精度 |
| ARI-028 | Polynomial Evaluator | A2 | P3 | 系数常量化与MAC复用 |
| ARI-029 | BCD/Binary Converter | A2 | P3 | 周期与面积 |
| ARI-030 | Decimal/BCD Arithmetic | A2 | P3 | 专用业务驱动 |
| ARI-031 | FP Classify/Compare | A1/A2 | P3 | NaN/Inf/zero语义 |
| ARI-032 | FP Add/Multiply/FMA Shell | A2 | P3 | 不重复造完整FPU，重在适配 |
| ARI-033 | Block Floating-point Scale | A2 | P3 | 精度与存储带宽 |
| ARI-034 | Quantize/Dequantize | A2 | P2 | AI数据通路位宽与功耗 |
| ARI-035 | Packed SIMD Lane Operator | A2 | P3 | Lane复用与门控 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
