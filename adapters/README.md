# adapters — A0 技术适配构件

本目录存放 **A0 技术适配** 类 CBB 的交付件（隔离工艺、Macro、标准单元或目标平台差异）：

- ICG / Glitch-free Clock Mux / Clock Divider Wrapper
- Level Shifter / Isolation / Retention / Power Switch Wrapper
- SRAM / Register File / ROM / CAM / eFuse/OTP / PLL-DLL-OSC Wrapper
- FPGA Memory / DSP Wrapper

完整候选见 [`registry.yaml`](../registry.yaml:1)（`group: adapters`，22 条）；当前均为 `planned`，实现后以完整工程包形式在此落位并更新 registry `status=implemented`。

开发方法见 cbb-development-suite（本仓仅承载交付件）。