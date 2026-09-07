# Changelog — sync_fifo

## [0.1.1] - 2026-09-03（G6 PPA 表征追加）

### Added（run-20260903-01）
- `pdk-scan` 判定 `PDK_READY`（sc9_cmos28lp_base_hvt tt 1.00V 25C）固化 `characterization/pdk.yaml`；
- DC V-2023.12-SP3 综合 8 点（IMPL{0,1} × OUTPUT_REG{0,1} × DEPTH{8,32}，DATA_W=32，
  400MHz 绑定 clk 端口）全 reg→reg slack MET（E2）；
- 实测结论：`register×comb`（默认）d8=957.6µm² / d32=3747.4µm² 面积最小且 slack 最优
  （0.55/0.00ns），为 Pareto 支配点；shift 每槽"保持/左移/尾写"mux 组合开销 > 省读 mux，
  实测面积/功耗反超 register（d32 shift×comb +9.5% 面积、+12~14% 动态功耗）→ shift
  profiles 降 `experimental`（`shift_shallow`/`shift_registered_out`）；
- 产物：`reports/ppa-report.md`（报告）+ `reports/ppa_run-20260903-01.png`（对比图）
  + `characterization/{synth_sweep.tcl,extract_ppa.py,plot_ppa_comparison.py,plan.yaml}`
  （可复现）；`cbb.yaml` characterization 更新 `pdk_context` + measured_region。

## [0.1.0] - 2026-09-03

### Added
- Synchronous FIFO（QUE-001，A2/P0）：单时钟域深度存储队列，push/pop 原生接口 +
  full/empty/count 输出；FIFO 保序无丢无重、满/空/计数守恒；
- 参数：`DATA_W[1,1024]` / `DEPTH[2,256]` / `OUTPUT_REG{0,1}` / `IMPL{0,1}`；
- 多实现（同契约不同存储微架构）：`IMPL=0` register（读写指针+寄存器堆，任意深度）、
  `IMPL=1` shift（移位存储，push 尾写 + pop/refill 左移、头固定 index0，无读 mux）；
- 输出级：`OUTPUT_REG=0` comb（rd_valid=~empty 同拍组合头，0 读延迟）、
  `OUTPUT_REG=1` reg（存储+输出级两级：refill 预取/consume 消费，弹空缓存语义）；
- RTL：单文件极简单 `rtl/sync_fifo.sv`（无 package/interface，四 generate 分支 +
  就近 SVA PROP-SYNC_CNT/FULL/EMPTY/COMB/OUTREG-*）；参数检查 generate `$error`（PC-001..006）；
- G3 静态基线：VCS 正向编译矩阵（4 模式 + DATA_W/DEPTH 边界 1/64/128/1024、3/32/129/256）
  + 负向 DATA_W/DEPTH/OUTPUT_REG/IMPL 越界 `$error` 拦截；
- G4 功能仿真：参考模型队列整体比对 9 配置 × 场景
  （tc_reset/tc_random/tc_backpressure/tc_edge/tc_out_comb/tc_outreg，固定 seed 32'hCBB_2026_0903）；
- 契约 SSOT：`cbb.yaml`（REQ-001..009）/ `behavior.yaml`（INV-001..005、ASM-001..005）/
  `profiles.yaml`（4 Profile：default_register/register_registered_out/shift_shallow/
  shift_registered_out）/ RTM（19 条）；
- 配置集由 `config-gen` 确定性生成（verification/configs/：1 mandatory/19 boundary/
  13 pairwise/4 negative）。

### Non-goals（登记，后续扩展需经用户同意）
- IMPL=sram 宏存储（依赖未实现 A0 wrapper TEC-015 sram_macro_wrapper）
- CDC/异步（QUE-002 async_fifo）、FWFT 直读（QUE-003）、flush/override/peek、almost 水位
