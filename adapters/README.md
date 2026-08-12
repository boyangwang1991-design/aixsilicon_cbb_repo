# adapters — 工艺与物理实现适配

对应 cbb_repo_list.md 第 2 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| TEC-001 | 通用组合标准单元 Wrapper | A0 | P2 | 保持可移植 RTL 与定向映射双路径 |
| TEC-002 | DFF Wrapper | A0 | P1 | 面积、时钟功耗、DFT约束 |
| TEC-003 | Multi-bit FF Wrapper | A0 | P2 | 时钟功耗与布局可实现性 |
| TEC-004 | Latch Wrapper | A0 | P3 | 时序借用与验证边界 |
| TEC-005 | ICG Wrapper | A0 | P0 | 时钟功耗、门控检查、DFT |
| TEC-006 | Glitch-free Clock Mux Wrapper | A0 | P0 | 无毛刺、切换延迟、CTS |
| TEC-007 | Clock Divider Cell Wrapper | A0 | P1 | 占空比、generated clock |
| TEC-008 | Clock Buffer/Delay Wrapper | A0 | P3 | 仅供受控物理实现使用 |
| TEC-009 | Level Shifter Wrapper | A0 | P1 | 电压域、方向、隔离组合 |
| TEC-010 | Isolation Cell Wrapper | A0 | P1 | 控制极性、位置、UPF一致性 |
| TEC-011 | Retention FF/Bank Wrapper | A0 | P2 | 状态范围、唤醒延迟、面积 |
| TEC-012 | Power Switch Control Wrapper | A0 | P3 | 物理专用，不承载电源网实现 |
| TEC-013 | Tie/Constant Cell Wrapper | A0 | P2 | 避免逻辑常量不规范直连 |
| TEC-014 | Scan/Lockup Wrapper | A0 | P3 | DFT链与跨时钟域 |
| TEC-015 | SRAM Macro Wrapper | A0 | P0 | 统一读延迟、mask、sleep、BIST |
| TEC-016 | Register File Macro Wrapper | A0 | P1 | 端口语义与 bypass |
| TEC-017 | ROM Macro Wrapper | A0 | P2 | 初始化、时序和测试接口 |
| TEC-018 | CAM/TCAM Macro Wrapper | A0 | P3 | 高功耗宏，严格适用范围 |
| TEC-019 | eFuse/OTP Macro Wrapper | A0 | P3 | 安全、一次性编程、厂商差异 |
| TEC-020 | PLL/DLL/OSC Digital Wrapper | A0 | P3 | 仅数字接口适配，不替代模拟IP |
| TEC-021 | FPGA Memory Wrapper | A0 | P1 | ASIC/FPGA双实现映射 |
| TEC-022 | FPGA DSP Wrapper | A0 | P2 | 推断稳定性与流水位置 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
