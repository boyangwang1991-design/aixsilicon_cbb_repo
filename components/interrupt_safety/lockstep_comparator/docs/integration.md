# 集成说明

## 采样与复位

所有数据、掩码、注入和控制信号必须与 `clk_i` 同步。上层负责 `rst_ni` 的同步释放；
本模块不执行 CDC 或复位同步。默认比较当前 Shadow 与延迟两个采样周期的 Main。
掩码属于当前比较时刻的有效语义，上层需要时应自行对齐 valid/mask。

`error_clear_i` 只清除历史状态，当前故障具有置位优先级，不影响延迟流水或 alignment。
本地复位会清除 sticky；需要暖复位保留的系统应在独立安全域锁存故障。
P=1 输出报告在下一个采样边界更新；关闭比较不会异步撤销已捕获的流水结果，复位会立即撤销。

## 安全机制自测

清除历史状态并等待 alignment 后，以有效掩码选择注入位，依次对 target 0/1（比较 A/B）注入。
正常匹配数据时，单路比较注入应同时产生 divergence 和 internal fault。
Level 2 再测试 target 2/3（Delay A/B）；故障在 D 个采样沿后传播，撤销后还需等待流水排空。
每次自测后撤销注入，再清除历史。全 mask 配置没有检测覆盖，不能用于实际保护。

## 综合与物理边界

两个私有通道位于同一 RTL 文件，集成时只编译该文件一次。
DC 在 elaborate/link 后执行 `constraints/preserve_redundancy.tcl`，禁止跨通道展平、跨边界优化及寄存器合并。
若集成流程重新 flatten/retime 或合并等价寄存器，必须重新检查独立性，现有证据不再直接适用。
最终布局仍需 A/B 分离、共因故障分析、时钟/复位控制一致性检查及故障反应时间分析。

`main_shadow_mismatch_o` 与 `lcl_internal_fault_o` 是不同故障类别；`safety_fault_o` 为它们的 OR。
本模块不执行 voting、功能输出 gating、安全状态决策或控制一致性检测。
