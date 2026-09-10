# SAF-005 实现规格

原始需求见 [SAF-005 合约](../../SAF-005-CONTRACT.MD)，机器事实源为 [cbb.yaml](../cbb.yaml) 与 [behavior.yaml](../behavior.yaml)。
资产名为 `lockstep_comparator`，RTL 顶层名为 `lockstep_comparator_logic`。
合约第 5 节的九个参数和全部端口保持一致。WIDTH 不人为增加架构上限，延迟与保护周期采用 unsigned 32-bit 参数。
已测参数范围在验证报告单独列出；未经测试的范围保持 experimental。
YAML 中静态掩码 `-1` 表示 RTL 的全 1 掩码，按 WIDTH 截取。

## 时序与复位

在一个上升沿到来前，延迟输出是前 D 个采样沿输入的 Main 值；流水持续移位，不因比较禁用而暂停。
复位释放后经过 D+G 个上升沿，alignment 有效；D=G=0 时复位外立即有效。
P=0 组合比较；P=1 在上升沿寄存各通道已经资格限定和掩码处理的差异向量，并保持一个周期。
控制信号撤销会禁止新采样，已捕获报告保持到下一沿；复位立即屏蔽所有实时输出。
Sticky 在上升沿捕获沿前实时结果，因此 P=1 的 sticky 捕获比实时报告再晚一个采样沿。
复位异步置位、同步释放的集成责任由上层承担。

## Sticky 与事件

清除与新故障同拍时采用置位优先：`next = (clear ? 0 : old) OR live`。
两个故障类别和向量分别维护；脉冲为 `live_mismatch AND NOT latched_mismatch`。
清除不改变对齐或延迟状态。`rst_ni` 清空本地 sticky；需要暖复位保留时，上层在安全域保存故障记录。

## 故障注入

| 编码 | 目标 | 行为 |
|---|---|---|
| 0 | Comparator A | 比较前对齐操作数与 fi_mask XOR |
| 1 | Comparator B | 同上，仅作用 B |
| 2 | Delay A | 破坏第一级延迟输入，经过 D 个采样传播；D=0 作用于旁路 |
| 3 | Delay B | 同上，仅完整冗余模式有效 |

`fi_enable_i=0` 表示 FI_NONE。Level 0 忽略 B 目标；Level 1 忽略 Delay B，Delay A 故障影响共享输入。
所有注入差异遵守有效掩码，自测必须开启至少一个被注入位。

## 独立性与仿真检查

Level 2 分别保存延迟、启动状态与可选结果寄存器；Level 1 有意共享延迟状态。
综合须防止冗余节点合并并检查映射结构，不能仅凭 RTL 双份逻辑宣称物理独立。
时钟、复位、输入源和最终汇总为系统安全分析边界。
有效、未掩码的 X/Z 数据触发仿真断言，包括 Main 和 Shadow 同时为 X 的情况。
