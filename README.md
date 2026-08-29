# AixSilicon CBB Repository

**CBB（公共基础构件）交付发布仓**：存放经过验证的 CBB 交付件，管理版本，并作为 **FuseSoC Library** 提供消费入口。

CBB 的需求/规格/RTL 实现/验证/PPA 表征的开发方法与工具链在 **cbb-development-suite**（Skill）中定义与执行；本仓库只接收其**交付件**。

## 目录结构

```text
.
├── adapters/            # A0 技术适配交付件（22 条候选；实现后落位）
├── components/          # A1~A4 已交付 CBB 工程包（每构件含 cbb.yaml + rtl + verification + evidence + fusesoc/core）
├── fusesoc.conf         # FuseSoC 库注册
├── registry.yaml        # 交付件索引（唯一 SSOT：id/name/family/group/abstraction/priority/implementation/description/status/version/path）
├── reports/quality/     # 交付证据（run_log.md 等）
├── CHANGELOG.md         # 平台版本
└── LICENSE              # Apache-2.0
```

## FuseSoC 使用

```bash
# 将本仓库注册为 FuseSoC 库
fusesoc library add aixsilicon-cbb /path/to/aixsilicon_cbb_repo

# 列出 / 运行交付构件
fusesoc core list
fusesoc core show aixsilicon:cbb:<cbb_name>:<version>
fusesoc run --target sim aixsilicon:cbb:<cbb_name>:<version>
```

VLNV 命名：`aixsilicon:cbb:<cbb_name>:<version>`。

## registry.yaml

`registry.yaml` 是 CBB 交付件的机器可读索引（唯一 SSOT），每条含：

| 字段 | 说明 |
| --- | --- |
| `id` | 构件 ID（如 `QUE-012`） |
| `name` | 英文功能名（VLNV name，如 `width_conversion_fifo`） |
| `family` | 中文名（构件族） |
| `group` | 类别路径（如 `components/fifo_queue_buffer`） |
| `abstraction` | 抽象粒度 A0~A4 |
| `priority` | P0~P3 |
| `implementation` | 主要实现变体 |
| `description` | PPA/工程关注点 |
| `status` | `planned`（未实现）或 `implemented`（目录存在且通过验证） |
| `version` | 版本（SemVer） |
| `path` | 交付件相对路径 |

`status=implemented` 的条目在 `components/` 下存在完整工程包；`planned` 条目仅为规划候选，无物理目录。

类别说明：`group=adapters`（A0 技术适配，22 条候选）、`group=components/*`（A1~A3 构件）、`group=templates`（A4 子系统模板，24 条候选）。A4 模板为候选索引，实现后以交付件形式进入对应类别。

## 当前已交付构件

> 以下状态总览由 [`scripts/update_registry_readme.py`](scripts/update_registry_readme.py) 依据
> [`registry.yaml`](registry.yaml:1)（SSOT）自动生成；**修改 `registry.yaml` 后必须运行**
> `python3 scripts/update_registry_readme.py` 刷新本节，勿手工编辑。

<!-- REGISTRY-STATUS:BEGIN -->
> 本节由 `scripts/update_registry_readme.py` 依据 `registry.yaml`（SSOT）自动生成。
> 修改 `registry.yaml` 后必须运行 `python3 scripts/update_registry_readme.py` 刷新本节；勿手工编辑。
> 最后更新：`2026-08-29T03:06:00Z`

### 总览

| 指标                         | 数量 |
|------------------------------|------|
| 总条目（cbbs）               | 410  |
| implemented（已实现/已交付） | 7    |
| planned（规划候选）          | 403  |
| 实现率                       | 1.7% |

### 已实现 / 已交付构件（7）

| ID      | 构件                                                                                         | 构件族                   | 抽象 | 优先级 | 版本  | 类别                              |
|---------|----------------------------------------------------------------------------------------------|--------------------------|------|--------|-------|-----------------------------------|
| ARB-001 | [fixed_priority_arbiter](components/arbitration_scheduling/fixed_priority_arbiter/README.md) | Fixed-priority Arbiter   | A2   | P0     | 0.1.0 | components/arbitration_scheduling |
| ARB-002 | [round_robin_arbiter](components/arbitration_scheduling/round_robin_arbiter/README.md)       | Round-robin Arbiter      | A2   | P0     | 0.1.0 | components/arbitration_scheduling |
| ARB-003 | [weighted_rr_arbiter](components/arbitration_scheduling/weighted_rr_arbiter/README.md)       | Weighted RR Arbiter      | A2   | P2     | 0.1.0 | components/arbitration_scheduling |
| ARI-001 | [incrementer_decrementer](components/arithmetic_datapath/incrementer_decrementer/README.md)  | Incrementer/Decrementer  | A1   | P0     | 0.1.0 | components/arithmetic_datapath    |
| COD-001 | [parity_gen_check](components/coding_integrity/parity_gen_check/README.md)                   | Parity Generator/Checker | A1   | P0     | 0.1.0 | components/coding_integrity       |
| QUE-007 | [skid_buffer](components/fifo_queue_buffer/skid_buffer/README.md)                            | Skid Buffer              | A3   | P0     | 0.3.0 | components/fifo_queue_buffer      |
| SEL-014 | [popcount](components/selection_decode/popcount/README.md)                                   | Population Count         | A1   | P1     | 0.1.0 | components/selection_decode       |

### 按类别分布（implemented / planned）

| 类别                              | implemented | planned | 合计 |
|-----------------------------------|-------------|---------|------|
| adapters                          | 0           | 22      | 22   |
| components/apb_ahb_register       | 0           | 16      | 16   |
| components/arbitration_scheduling | 3           | 17      | 20   |
| components/arithmetic_datapath    | 1           | 34      | 35   |
| components/axi_axi_stream         | 0           | 38      | 38   |
| components/cdc_rdc                | 0           | 19      | 19   |
| components/clock_reset_power      | 0           | 22      | 22   |
| components/coding_integrity       | 1           | 11      | 12   |
| components/control_event_status   | 0           | 24      | 24   |
| components/dft_test               | 0           | 10      | 10   |
| components/dsp_ai_datapath        | 0           | 15      | 15   |
| components/fifo_queue_buffer      | 1           | 19      | 20   |
| components/interrupt_safety       | 0           | 30      | 30   |
| components/monitor_debug          | 0           | 16      | 16   |
| components/noc_interconnect       | 0           | 17      | 17   |
| components/register_memory        | 0           | 25      | 25   |
| components/selection_decode       | 1           | 19      | 20   |
| components/streaming_pipeline     | 0           | 25      | 25   |
| templates                         | 0           | 24      | 24   |

### 按抽象粒度分布

| 抽象  | 数量 |
|-------|------|
| A0    | 22   |
| A0/A2 | 2    |
| A1    | 38   |
| A1/A0 | 1    |
| A1/A2 | 20   |
| A2    | 180  |
| A2/A3 | 16   |
| A2/A4 | 4    |
| A3    | 92   |
| A3/A4 | 7    |
| A4    | 28   |

### 按优先级分布（implemented / planned）

| 优先级 | implemented | planned | 合计 |
|--------|-------------|---------|------|
| P0     | 5           | 73      | 78   |
| P1     | 1           | 139     | 140  |
| P2     | 1           | 123     | 124  |
| P3     | 0           | 68      | 68   |

### 全部 CBB 明细（410，按类别拆分）

#### adapters（22，implemented=0）

| ID      | 名称                                                                          | 构件族                        | 状态    | 抽象 | 优先级 | 版本  | 功能/描述                       |
|---------|-------------------------------------------------------------------------------|-------------------------------|---------|------|--------|-------|---------------------------------|
| TEC-001 | [generic_comb_wrapper](adapters/generic_comb_wrapper/README.md)               | 通用组合标准单元 Wrapper      | planned | A0   | P2     | 0.1.0 | 保持可移植 RTL 与定向映射双路径 |
| TEC-002 | [dff_wrapper](adapters/dff_wrapper/README.md)                                 | DFF Wrapper                   | planned | A0   | P1     | 0.1.0 | 面积、时钟功耗、DFT约束         |
| TEC-003 | [mbff_wrapper](adapters/mbff_wrapper/README.md)                               | Multi-bit FF Wrapper          | planned | A0   | P2     | 0.1.0 | 时钟功耗与布局可实现性          |
| TEC-004 | [latch_wrapper](adapters/latch_wrapper/README.md)                             | Latch Wrapper                 | planned | A0   | P3     | 0.1.0 | 时序借用与验证边界              |
| TEC-005 | [icg_wrapper](adapters/icg_wrapper/README.md)                                 | ICG Wrapper                   | planned | A0   | P0     | 0.1.0 | 时钟功耗、门控检查、DFT         |
| TEC-006 | [glitch_free_clock_mux](adapters/glitch_free_clock_mux/README.md)             | Glitch-free Clock Mux Wrapper | planned | A0   | P0     | 0.1.0 | 无毛刺、切换延迟、CTS           |
| TEC-007 | [clock_divider_cell_wrapper](adapters/clock_divider_cell_wrapper/README.md)   | Clock Divider Cell Wrapper    | planned | A0   | P1     | 0.1.0 | 占空比、generated clock         |
| TEC-008 | [clock_buffer_wrapper](adapters/clock_buffer_wrapper/README.md)               | Clock Buffer/Delay Wrapper    | planned | A0   | P3     | 0.1.0 | 仅供受控物理实现使用            |
| TEC-009 | [level_shifter_wrapper](adapters/level_shifter_wrapper/README.md)             | Level Shifter Wrapper         | planned | A0   | P1     | 0.1.0 | 电压域、方向、隔离组合          |
| TEC-010 | [isolation_cell_wrapper](adapters/isolation_cell_wrapper/README.md)           | Isolation Cell Wrapper        | planned | A0   | P1     | 0.1.0 | 控制极性、位置、UPF一致性       |
| TEC-011 | [retention_ff_wrapper](adapters/retention_ff_wrapper/README.md)               | Retention FF/Bank Wrapper     | planned | A0   | P2     | 0.1.0 | 状态范围、唤醒延迟、面积        |
| TEC-012 | [power_switch_ctrl_wrapper](adapters/power_switch_ctrl_wrapper/README.md)     | Power Switch Control Wrapper  | planned | A0   | P3     | 0.1.0 | 物理专用，不承载电源网实现      |
| TEC-013 | [tie_cell_wrapper](adapters/tie_cell_wrapper/README.md)                       | Tie/Constant Cell Wrapper     | planned | A0   | P2     | 0.1.0 | 避免逻辑常量不规范直连          |
| TEC-014 | [scan_lockup_wrapper](adapters/scan_lockup_wrapper/README.md)                 | Scan/Lockup Wrapper           | planned | A0   | P3     | 0.1.0 | DFT链与跨时钟域                 |
| TEC-015 | [sram_macro_wrapper](adapters/sram_macro_wrapper/README.md)                   | SRAM Macro Wrapper            | planned | A0   | P0     | 0.1.0 | 统一读延迟、mask、sleep、BIST   |
| TEC-016 | [register_file_macro_wrapper](adapters/register_file_macro_wrapper/README.md) | Register File Macro Wrapper   | planned | A0   | P1     | 0.1.0 | 端口语义与 bypass               |
| TEC-017 | [rom_macro_wrapper](adapters/rom_macro_wrapper/README.md)                     | ROM Macro Wrapper             | planned | A0   | P2     | 0.1.0 | 初始化、时序和测试接口          |
| TEC-018 | [cam_macro_wrapper](adapters/cam_macro_wrapper/README.md)                     | CAM/TCAM Macro Wrapper        | planned | A0   | P3     | 0.1.0 | 高功耗宏，严格适用范围          |
| TEC-019 | [efuse_otp_wrapper](adapters/efuse_otp_wrapper/README.md)                     | eFuse/OTP Macro Wrapper       | planned | A0   | P3     | 0.1.0 | 安全、一次性编程、厂商差异      |
| TEC-020 | [pll_dll_osc_wrapper](adapters/pll_dll_osc_wrapper/README.md)                 | PLL/DLL/OSC Digital Wrapper   | planned | A0   | P3     | 0.1.0 | 仅数字接口适配，不替代模拟IP    |
| TEC-021 | [fpga_memory_wrapper](adapters/fpga_memory_wrapper/README.md)                 | FPGA Memory Wrapper           | planned | A0   | P1     | 0.1.0 | ASIC/FPGA双实现映射             |
| TEC-022 | [fpga_dsp_wrapper](adapters/fpga_dsp_wrapper/README.md)                       | FPGA DSP Wrapper              | planned | A0   | P2     | 0.1.0 | 推断稳定性与流水位置            |

#### components/apb_ahb_register（16，implemented=0）

| ID      | 名称                                                                                           | 构件族                     | 状态    | 抽象  | 优先级 | 版本  | 功能/描述            |
|---------|------------------------------------------------------------------------------------------------|----------------------------|---------|-------|--------|-------|----------------------|
| BUS-001 | [generic_csr_adapter](components/apb_ahb_register/generic_csr_adapter/README.md)               | Generic CSR Bus Adapter    | planned | A3    | P0     | 0.1.0 | 内部统一接口         |
| BUS-002 | [apb_slave_adapter](components/apb_ahb_register/apb_slave_adapter/README.md)                   | APB Slave Adapter          | planned | A3    | P0     | 0.1.0 | 低面积与时序         |
| BUS-003 | [apb_register_slice](components/apb_ahb_register/apb_register_slice/README.md)                 | APB Register Slice         | planned | A3    | P1     | 0.1.0 | PREADY返回路径       |
| BUS-004 | [apb_decoder](components/apb_ahb_register/apb_decoder/README.md)                               | APB Decoder                | planned | A3    | P0     | 0.1.0 | 地址译码与PREADY Mux |
| BUS-005 | [apb_mux_interconnect](components/apb_ahb_register/apb_mux_interconnect/README.md)             | APB Mux/Interconnect       | planned | A3/A4 | P1     | 0.1.0 | 规模与共享路径       |
| BUS-006 | [apb_cdc_bridge](components/apb_ahb_register/apb_cdc_bridge/README.md)                         | APB CDC Bridge             | planned | A3    | P1     | 0.1.0 | 低吞吐CDC优化        |
| BUS-007 | [apb_width_adapter](components/apb_ahb_register/apb_width_adapter/README.md)                   | APB Width Adapter          | planned | A3    | P2     | 0.1.0 | Byte strobe与跨拍    |
| BUS-008 | [apb_timeout_default_slave](components/apb_ahb_register/apb_timeout_default_slave/README.md)   | APB Timeout/Default Slave  | planned | A3    | P0     | 0.1.0 | 防挂死与低开销       |
| BUS-009 | [ahb_lite_slave_adapter](components/apb_ahb_register/ahb_lite_slave_adapter/README.md)         | AHB-Lite Slave Adapter     | planned | A3    | P1     | 0.1.0 | 地址/数据相位        |
| BUS-010 | [ahb_lite_register_slice](components/apb_ahb_register/ahb_lite_register_slice/README.md)       | AHB-Lite Register Slice    | planned | A3    | P1     | 0.1.0 | HREADY路径           |
| BUS-011 | [ahb_lite_decoder_mux](components/apb_ahb_register/ahb_lite_decoder_mux/README.md)             | AHB-Lite Decoder/Mux       | planned | A3    | P2     | 0.1.0 | 响应Mux时序          |
| BUS-012 | [ahb_lite_cdc_bridge](components/apb_ahb_register/ahb_lite_cdc_bridge/README.md)               | AHB-Lite CDC Bridge        | planned | A3    | P2     | 0.1.0 | 相位与响应           |
| BUS-013 | [ahb_apb_bridge](components/apb_ahb_register/ahb_apb_bridge/README.md)                         | AHB↔APB Bridge             | planned | A3/A4 | P1     | 0.1.0 | Buffer与时钟比       |
| BUS-014 | [csr_shadow_commit_adapter](components/apb_ahb_register/csr_shadow_commit_adapter/README.md)   | CSR Shadow/Commit Adapter  | planned | A3    | P1     | 0.1.0 | 配置一致性           |
| BUS-015 | [csr_access_policy_filter](components/apb_ahb_register/csr_access_policy_filter/README.md)     | CSR Access Policy Filter   | planned | A3    | P1     | 0.1.0 | 译码与安全策略       |
| BUS-016 | [register_broadcast_adapter](components/apb_ahb_register/register_broadcast_adapter/README.md) | Register Broadcast Adapter | planned | A3    | P2     | 0.1.0 | 高扇出优化           |

#### components/arbitration_scheduling（20，implemented=3）

| ID      | 名称                                                                                               | 构件族                    | 状态        | 抽象  | 优先级 | 版本  | 功能/描述                                                                      |
|---------|----------------------------------------------------------------------------------------------------|---------------------------|-------------|-------|--------|-------|--------------------------------------------------------------------------------|
| ARB-001 | [fixed_priority_arbiter](components/arbitration_scheduling/fixed_priority_arbiter/README.md)       | Fixed-priority Arbiter    | implemented | A2    | P0     | 0.1.0 | 优先级链（授权互斥 + LSB/MSB 优先；支持 latched/registered 授权）              |
| ARB-002 | [round_robin_arbiter](components/arbitration_scheduling/round_robin_arbiter/README.md)             | Round-robin Arbiter       | implemented | A2    | P0     | 0.1.0 | 授权互斥 + 等权轮转公平（mask/rotate+priority/pointer 三实现 + G3/G4/G5 证据） |
| ARB-003 | [weighted_rr_arbiter](components/arbitration_scheduling/weighted_rr_arbiter/README.md)             | Weighted RR Arbiter       | implemented | A2    | P2     | 0.1.0 | 权重状态与公平性（quota_counter/deficit_rotate 双实现 + G3/G4/G5 证据）        |
| ARB-004 | [deficit_rr_arbiter](components/arbitration_scheduling/deficit_rr_arbiter/README.md)               | Deficit RR Arbiter        | planned     | A2    | P3     | 0.1.0 | 加法状态与包长                                                                 |
| ARB-005 | [age_based_arbiter](components/arbitration_scheduling/age_based_arbiter/README.md)                 | Age-based Arbiter         | planned     | A2    | P3     | 0.1.0 | 比较网络面积                                                                   |
| ARB-006 | [lottery_arbiter](components/arbitration_scheduling/lottery_arbiter/README.md)                     | Lottery/Random Arbiter    | planned     | A2    | P3     | 0.1.0 | 随机质量与验证                                                                 |
| ARB-007 | [multi_grant_arbiter](components/arbitration_scheduling/multi_grant_arbiter/README.md)             | Multi-grant Arbiter       | planned     | A2    | P2     | 0.1.0 | 多授权组合复杂度                                                               |
| ARB-008 | [hierarchical_arbiter](components/arbitration_scheduling/hierarchical_arbiter/README.md)           | Hierarchical Arbiter      | planned     | A2    | P1     | 0.1.0 | 大规模请求时序                                                                 |
| ARB-009 | [pipelined_arbiter](components/arbitration_scheduling/pipelined_arbiter/README.md)                 | Pipelined Arbiter         | planned     | A2    | P1     | 0.1.0 | 延迟与满吞吐                                                                   |
| ARB-010 | [packet_locking_arbiter](components/arbitration_scheduling/packet_locking_arbiter/README.md)       | Packet-locking Arbiter    | planned     | A2/A3 | P1     | 0.1.0 | 锁定状态与公平性                                                               |
| ARB-011 | [credit_manager](components/arbitration_scheduling/credit_manager/README.md)                       | Credit Manager            | planned     | A2    | P0     | 0.1.0 | 计数一致性和位宽                                                               |
| ARB-012 | [token_allocator](components/arbitration_scheduling/token_allocator/README.md)                     | Token Allocator           | planned     | A2    | P1     | 0.1.0 | 分配/回收时序                                                                  |
| ARB-013 | [resource_pool_manager](components/arbitration_scheduling/resource_pool_manager/README.md)         | Resource Pool Manager     | planned     | A2    | P2     | 0.1.0 | 容量、并行分配                                                                 |
| ARB-014 | [request_coalescer](components/arbitration_scheduling/request_coalescer/README.md)                 | Request Coalescer         | planned     | A2    | P2     | 0.1.0 | 比较网络和Buffer                                                               |
| ARB-015 | [request_distributor](components/arbitration_scheduling/request_distributor/README.md)             | Request Distributor       | planned     | A2    | P2     | 0.1.0 | 均衡度与路由逻辑                                                               |
| ARB-016 | [shared_operator_scheduler](components/arbitration_scheduling/shared_operator_scheduler/README.md) | Shared Operator Scheduler | planned     | A2/A4 | P1     | 0.1.0 | 资源面积与排队延迟                                                             |
| ARB-017 | [bank_conflict_resolver](components/arbitration_scheduling/bank_conflict_resolver/README.md)       | Bank Conflict Resolver    | planned     | A2    | P1     | 0.1.0 | 冲突率和吞吐                                                                   |
| ARB-018 | [outstanding_tracker](components/arbitration_scheduling/outstanding_tracker/README.md)             | Outstanding Tracker       | planned     | A2    | P1     | 0.1.0 | 容量与匹配逻辑                                                                 |
| ARB-019 | [reservation_lock_manager](components/arbitration_scheduling/reservation_lock_manager/README.md)   | Reservation/Lock Manager  | planned     | A2    | P3     | 0.1.0 | 死锁与状态开销                                                                 |
| ARB-020 | [barrier_join_controller](components/arbitration_scheduling/barrier_join_controller/README.md)     | Barrier/Join Controller   | planned     | A2    | P2     | 0.1.0 | 参与者数量与扇入                                                               |

#### components/arithmetic_datapath（35，implemented=1）

| ID      | 名称                                                                                        | 构件族                         | 状态        | 抽象  | 优先级 | 版本  | 功能/描述                                          |
|---------|---------------------------------------------------------------------------------------------|--------------------------------|-------------|-------|--------|-------|----------------------------------------------------|
| ARI-001 | [incrementer_decrementer](components/arithmetic_datapath/incrementer_decrementer/README.md) | Incrementer/Decrementer        | implemented | A1    | P0     | 0.1.0 | Counter专用优化（±1 模回绕 + carry_out 溢出/借位） |
| ARI-002 | [adder_subtractor](components/arithmetic_datapath/adder_subtractor/README.md)               | Adder/Subtractor               | planned     | A1    | P0     | 0.1.0 | 位宽、进位结构、流水                               |
| ARI-003 | [carry_save_adder](components/arithmetic_datapath/carry_save_adder/README.md)               | Carry-save Adder               | planned     | A1    | P1     | 0.1.0 | 多操作数压缩                                       |
| ARI-004 | [multi_operand_adder](components/arithmetic_datapath/multi_operand_adder/README.md)         | Multi-operand Adder            | planned     | A2    | P1     | 0.1.0 | 操作数数量与树平衡                                 |
| ARI-005 | [adder_tree](components/arithmetic_datapath/adder_tree/README.md)                           | Adder Tree                     | planned     | A2    | P1     | 0.1.0 | 流水级与吞吐                                       |
| ARI-006 | [accumulator](components/arithmetic_datapath/accumulator/README.md)                         | Accumulator                    | planned     | A2    | P0     | 0.1.0 | 反馈路径与门控                                     |
| ARI-007 | [absolute_value_negate](components/arithmetic_datapath/absolute_value_negate/README.md)     | Absolute Value/Negate          | planned     | A1    | P1     | 0.1.0 | 最小负数语义                                       |
| ARI-008 | [comparator](components/arithmetic_datapath/comparator/README.md)                           | Comparator                     | planned     | A1    | P0     | 0.1.0 | Early-out与关键路径                                |
| ARI-009 | [multiway_min_max](components/arithmetic_datapath/multiway_min_max/README.md)               | Multi-way Min/Max              | planned     | A2    | P1     | 0.1.0 | 路数、索引回传                                     |
| ARI-010 | [clamp_clip](components/arithmetic_datapath/clamp_clip/README.md)                           | Clamp/Clip                     | planned     | A1    | P1     | 0.1.0 | 比较共享与常量特化                                 |
| ARI-011 | [saturating_add_sub](components/arithmetic_datapath/saturating_add_sub/README.md)           | Saturating Add/Sub             | planned     | A1    | P1     | 0.1.0 | 溢出判定与延迟                                     |
| ARI-012 | [fixed_point_round](components/arithmetic_datapath/fixed_point_round/README.md)             | Fixed-point Round              | planned     | A1    | P1     | 0.1.0 | 精度、偏差、随机源                                 |
| ARI-013 | [fixed_point_resize](components/arithmetic_datapath/fixed_point_resize/README.md)           | Fixed-point Resize             | planned     | A1    | P0     | 0.1.0 | 位宽最小化                                         |
| ARI-014 | [scale_shift](components/arithmetic_datapath/scale_shift/README.md)                         | Scale/Shift                    | planned     | A1    | P1     | 0.1.0 | 常量传播与复用                                     |
| ARI-015 | [logical_arith_shifter](components/arithmetic_datapath/logical_arith_shifter/README.md)     | Logical/Arithmetic Shifter     | planned     | A1/A2 | P1     | 0.1.0 | 面积、周期数、路由                                 |
| ARI-016 | [rotator_funnel_shifter](components/arithmetic_datapath/rotator_funnel_shifter/README.md)   | Rotator/Funnel Shifter         | planned     | A2    | P2     | 0.1.0 | 双输入拼接与布线                                   |
| ARI-017 | [integer_multiplier](components/arithmetic_datapath/integer_multiplier/README.md)           | Integer Multiplier             | planned     | A2    | P1     | 0.1.0 | 位宽、符号、流水                                   |
| ARI-018 | [constant_multiplier](components/arithmetic_datapath/constant_multiplier/README.md)         | Constant Multiplier            | planned     | A2    | P1     | 0.1.0 | 常量特化与共享                                     |
| ARI-019 | [mac](components/arithmetic_datapath/mac/README.md)                                         | Multiply-Accumulate            | planned     | A2    | P1     | 0.1.0 | 融合、截断、吞吐                                   |
| ARI-020 | [dot_product_engine](components/arithmetic_datapath/dot_product_engine/README.md)           | Dot-product Engine             | planned     | A2    | P2     | 0.1.0 | 并行度、累加宽度                                   |
| ARI-021 | [integer_divider](components/arithmetic_datapath/integer_divider/README.md)                 | Integer Divider                | planned     | A2    | P2     | 0.1.0 | 面积/延迟/吞吐                                     |
| ARI-022 | [constant_divider](components/arithmetic_datapath/constant_divider/README.md)               | Constant Divider               | planned     | A2    | P2     | 0.1.0 | 误差与常量特化                                     |
| ARI-023 | [modulo_reducer](components/arithmetic_datapath/modulo_reducer/README.md)                   | Modulo/Reducer                 | planned     | A2    | P3     | 0.1.0 | 除法消除与延迟                                     |
| ARI-024 | [square_sum_squares](components/arithmetic_datapath/square_sum_squares/README.md)           | Square/Sum-of-squares          | planned     | A2    | P3     | 0.1.0 | DSP场景资源共享                                    |
| ARI-025 | [average_weighted_sum](components/arithmetic_datapath/average_weighted_sum/README.md)       | Average/Weighted Sum           | planned     | A2    | P2     | 0.1.0 | 系数与位宽增长                                     |
| ARI-026 | [reciprocal_rsqrt_approx](components/arithmetic_datapath/reciprocal_rsqrt_approx/README.md) | Reciprocal/RSqrt Approximation | planned     | A2    | P3     | 0.1.0 | 精度/延迟/面积                                     |
| ARI-027 | [cordic](components/arithmetic_datapath/cordic/README.md)                                   | CORDIC                         | planned     | A2    | P3     | 0.1.0 | 迭代次数、精度                                     |
| ARI-028 | [polynomial_evaluator](components/arithmetic_datapath/polynomial_evaluator/README.md)       | Polynomial Evaluator           | planned     | A2    | P3     | 0.1.0 | 系数常量化与MAC复用                                |
| ARI-029 | [bcd_binary_converter](components/arithmetic_datapath/bcd_binary_converter/README.md)       | BCD/Binary Converter           | planned     | A2    | P3     | 0.1.0 | 周期与面积                                         |
| ARI-030 | [decimal_bcd_arith](components/arithmetic_datapath/decimal_bcd_arith/README.md)             | Decimal/BCD Arithmetic         | planned     | A2    | P3     | 0.1.0 | 专用业务驱动                                       |
| ARI-031 | [fp_classify_compare](components/arithmetic_datapath/fp_classify_compare/README.md)         | FP Classify/Compare            | planned     | A1/A2 | P3     | 0.1.0 | NaN/Inf/zero语义                                   |
| ARI-032 | [fp_math_shell](components/arithmetic_datapath/fp_math_shell/README.md)                     | FP Add/Multiply/FMA Shell      | planned     | A2    | P3     | 0.1.0 | 不重复造完整FPU，重在适配                          |
| ARI-033 | [block_fp_scale](components/arithmetic_datapath/block_fp_scale/README.md)                   | Block Floating-point Scale     | planned     | A2    | P3     | 0.1.0 | 精度与存储带宽                                     |
| ARI-034 | [quantize_dequantize](components/arithmetic_datapath/quantize_dequantize/README.md)         | Quantize/Dequantize            | planned     | A2    | P2     | 0.1.0 | AI数据通路位宽与功耗                               |
| ARI-035 | [packed_simd_lane_op](components/arithmetic_datapath/packed_simd_lane_op/README.md)         | Packed SIMD Lane Operator      | planned     | A2    | P3     | 0.1.0 | Lane复用与门控                                     |

#### components/axi_axi_stream（38，implemented=0）

| ID       | 名称                                                                                             | 构件族                          | 状态    | 抽象  | 优先级 | 版本  | 功能/描述                |
|----------|--------------------------------------------------------------------------------------------------|---------------------------------|---------|-------|--------|-------|--------------------------|
| AXI-001  | [axi_channel_register_slice](components/axi_axi_stream/axi_channel_register_slice/README.md)     | AXI Channel Register Slice      | planned | A3    | P0     | 0.1.0 | 五通道独立切时序         |
| AXI-002  | [axi_lite_register_slice](components/axi_axi_stream/axi_lite_register_slice/README.md)           | AXI-Lite Register Slice         | planned | A3    | P0     | 0.1.0 | 小面积低延迟             |
| AXI-003  | [axi_buffer](components/axi_axi_stream/axi_buffer/README.md)                                     | AXI Buffer                      | planned | A3    | P1     | 0.1.0 | Outstanding与背压        |
| AXI-004  | [axi_width_converter](components/axi_axi_stream/axi_width_converter/README.md)                   | AXI Data Width Converter        | planned | A3    | P1     | 0.1.0 | Burst、strobe、unaligned |
| AXI-005  | [axi_addr_width_adapter](components/axi_axi_stream/axi_addr_width_adapter/README.md)             | AXI Address Width Adapter       | planned | A3    | P1     | 0.1.0 | 地址合法性               |
| AXI-006  | [axi_id_converter](components/axi_axi_stream/axi_id_converter/README.md)                         | AXI ID Width Converter          | planned | A3    | P1     | 0.1.0 | ID表面积和并发           |
| AXI-007  | [axi_user_signal_adapter](components/axi_axi_stream/axi_user_signal_adapter/README.md)           | AXI User Signal Adapter         | planned | A3    | P2     | 0.1.0 | 固定字段裁剪             |
| AXI-008  | [axi_burst_splitter](components/axi_axi_stream/axi_burst_splitter/README.md)                     | AXI Burst Splitter              | planned | A3    | P1     | 0.1.0 | 状态与吞吐               |
| AXI-009  | [axi_burst_merger](components/axi_axi_stream/axi_burst_merger/README.md)                         | AXI Burst Merger/Coalescer      | planned | A3    | P2     | 0.1.0 | 比较、Buffer、顺序       |
| AXI-010  | [axi_burst_length_adapter](components/axi_axi_stream/axi_burst_length_adapter/README.md)         | AXI Burst Length Adapter        | planned | A3    | P2     | 0.1.0 | 地址推进                 |
| AXI-011  | [axi_outstanding_limiter](components/axi_axi_stream/axi_outstanding_limiter/README.md)           | AXI Outstanding Limiter         | planned | A3    | P1     | 0.1.0 | 计数器和阻塞             |
| AXI-012  | [axi_id_remapper](components/axi_axi_stream/axi_id_remapper/README.md)                           | AXI ID Remapper                 | planned | A3    | P2     | 0.1.0 | 表容量与匹配             |
| AXI-013  | [axi_transaction_serializer](components/axi_axi_stream/axi_transaction_serializer/README.md)     | AXI Transaction Serializer      | planned | A3    | P1     | 0.1.0 | 面积换并发               |
| AXI-014  | [axi_rw_interleaver](components/axi_axi_stream/axi_rw_interleaver/README.md)                     | AXI Read/Write Interleaver      | planned | A3    | P3     | 0.1.0 | 顺序规则复杂度           |
| AXI-015  | [axi_clock_converter](components/axi_axi_stream/axi_clock_converter/README.md)                   | AXI Clock Converter             | planned | A3    | P0     | 0.1.0 | 全通道CDC正确性          |
| AXI-016  | [axi_protocol_converter](components/axi_axi_stream/axi_protocol_converter/README.md)             | AXI Protocol Converter          | planned | A3    | P1     | 0.1.0 | Burst拆分与错误          |
| AXI-017  | [axi_apb_bridge](components/axi_axi_stream/axi_apb_bridge/README.md)                             | AXI-to-APB Bridge               | planned | A3/A4 | P1     | 0.1.0 | 队列、译码、时钟         |
| AXI-018  | [axi_ahb_bridge](components/axi_axi_stream/axi_ahb_bridge/README.md)                             | AXI-to-AHB Bridge               | planned | A3/A4 | P2     | 0.1.0 | 顺序和响应映射           |
| AXI-019  | [axi_address_decoder](components/axi_axi_stream/axi_address_decoder/README.md)                   | AXI Address Decoder             | planned | A3    | P0     | 0.1.0 | 比较和路由关键路径       |
| AXI-020  | [axi_demux](components/axi_axi_stream/axi_demux/README.md)                                       | AXI Demux                       | planned | A3    | P1     | 0.1.0 | 响应路由状态             |
| AXI-021  | [axi_mux](components/axi_axi_stream/axi_mux/README.md)                                           | AXI Mux                         | planned | A3    | P1     | 0.1.0 | 五通道仲裁与锁定         |
| AXI-022  | [axi_crossbar](components/axi_axi_stream/axi_crossbar/README.md)                                 | AXI Crossbar                    | planned | A4    | P2     | 0.1.0 | 面积、布线、并发         |
| AXI-023  | [axi_default_slave](components/axi_axi_stream/axi_default_slave/README.md)                       | AXI Default Slave               | planned | A3    | P0     | 0.1.0 | 无目标响应               |
| AXI-024  | [axi_timeout_monitor](components/axi_axi_stream/axi_timeout_monitor/README.md)                   | AXI Timeout Monitor             | planned | A3    | P1     | 0.1.0 | 表项和恢复策略           |
| AXI-025  | [axi_firewall_region_filter](components/axi_axi_stream/axi_firewall_region_filter/README.md)     | AXI Firewall/Region Filter      | planned | A3    | P2     | 0.1.0 | 安全策略与关键路径       |
| AXI-026  | [axi_exclusive_access_monitor](components/axi_axi_stream/axi_exclusive_access_monitor/README.md) | AXI Exclusive Access Monitor    | planned | A3    | P3     | 0.1.0 | 表项与一致性范围         |
| AXI-027  | [axi_atomic_adapter](components/axi_axi_stream/axi_atomic_adapter/README.md)                     | AXI Atomic Adapter              | planned | A3    | P3     | 0.1.0 | 原子性和锁定             |
| AXI-028  | [axi_qos_mapper](components/axi_axi_stream/axi_qos_mapper/README.md)                             | AXI QoS Mapper                  | planned | A3    | P2     | 0.1.0 | 配置和仲裁衔接           |
| AXI-029  | [axi_perf_monitor](components/axi_axi_stream/axi_perf_monitor/README.md)                         | AXI Performance Monitor         | planned | A3    | P1     | 0.1.0 | 被动观测开销             |
| AXI-030  | [axi_error_injector](components/axi_axi_stream/axi_error_injector/README.md)                     | AXI Error Injector              | planned | A3    | P2     | 0.1.0 | 验证模式隔离             |
| AXIS-001 | [axis_register_slice](components/axi_axi_stream/axis_register_slice/README.md)                   | AXI-Stream Register Slice       | planned | A3    | P0     | 0.1.0 | Ready路径                |
| AXIS-002 | [axis_width_converter](components/axi_axi_stream/axis_width_converter/README.md)                 | AXI-Stream Width Converter      | planned | A3    | P1     | 0.1.0 | TKEEP/TLAST对齐          |
| AXIS-003 | [axis_switch](components/axi_axi_stream/axis_switch/README.md)                                   | AXI-Stream Switch               | planned | A3/A4 | P2     | 0.1.0 | 包锁定与路由             |
| AXIS-004 | [axis_packet_fifo](components/axi_axi_stream/axis_packet_fifo/README.md)                         | AXI-Stream Packet FIFO          | planned | A3    | P1     | 0.1.0 | 包边界与容量             |
| AXIS-005 | [axis_broadcaster](components/axi_axi_stream/axis_broadcaster/README.md)                         | AXI-Stream Broadcaster          | planned | A3    | P2     | 0.1.0 | Ready汇聚                |
| AXIS-006 | [axis_combiner_subset](components/axi_axi_stream/axis_combiner_subset/README.md)                 | AXI-Stream Combiner/Subset      | planned | A3    | P2     | 0.1.0 | Lane映射                 |
| AXIS-007 | [axis_frame_length_monitor](components/axi_axi_stream/axis_frame_length_monitor/README.md)       | AXI-Stream Frame Length Monitor | planned | A3    | P2     | 0.1.0 | 低开销检查               |
| AXIS-008 | [axis_rate_limiter](components/axi_axi_stream/axis_rate_limiter/README.md)                       | AXI-Stream Rate Limiter         | planned | A3    | P2     | 0.1.0 | 吞吐整形                 |

#### components/cdc_rdc（19，implemented=0）

| ID      | 名称                                                                                            | 构件族                          | 状态    | 抽象  | 优先级 | 版本  | 功能/描述            |
|---------|-------------------------------------------------------------------------------------------------|---------------------------------|---------|-------|--------|-------|----------------------|
| CDC-001 | [single_bit_synchronizer](components/cdc_rdc/single_bit_synchronizer/README.md)                 | Single-bit Synchronizer         | planned | A1    | P0     | 0.1.0 | MTBF、属性、布局     |
| CDC-002 | [multibit_static_synchronizer](components/cdc_rdc/multibit_static_synchronizer/README.md)       | Multi-bit Static Synchronizer   | planned | A1/A2 | P0     | 0.1.0 | 仅适用于静态配置总线 |
| CDC-003 | [pulse_synchronizer](components/cdc_rdc/pulse_synchronizer/README.md)                           | Pulse Synchronizer              | planned | A2    | P0     | 0.1.0 | 脉宽与连续脉冲间隔   |
| CDC-004 | [toggle_synchronizer](components/cdc_rdc/toggle_synchronizer/README.md)                         | Toggle Synchronizer             | planned | A2    | P0     | 0.1.0 | 事件丢失边界         |
| CDC-005 | [handshake_synchronizer](components/cdc_rdc/handshake_synchronizer/README.md)                   | Handshake Synchronizer          | planned | A2    | P0     | 0.1.0 | 延迟、吞吐、复位     |
| CDC-006 | [bundled_data_cdc](components/cdc_rdc/bundled_data_cdc/README.md)                               | Bundled-data CDC                | planned | A2    | P1     | 0.1.0 | 数据稳定窗口和约束   |
| CDC-007 | [bus_snapshot_cdc](components/cdc_rdc/bus_snapshot_cdc/README.md)                               | Bus Snapshot CDC                | planned | A2    | P1     | 0.1.0 | 原子采样             |
| CDC-008 | [gray_counter_cdc](components/cdc_rdc/gray_counter_cdc/README.md)                               | Gray Counter CDC                | planned | A2    | P0     | 0.1.0 | 最大跳变与约束       |
| CDC-009 | [async_fifo_cdc](components/cdc_rdc/async_fifo_cdc/README.md)                                   | Async FIFO                      | planned | A2    | P0     | 0.1.0 | 指针、满空、复位     |
| CDC-010 | [mesochronous_elastic_buffer](components/cdc_rdc/mesochronous_elastic_buffer/README.md)         | Mesochronous Elastic Buffer     | planned | A2    | P3     | 0.1.0 | 同频异相场景         |
| CDC-011 | [plesiochronous_rate_matcher](components/cdc_rdc/plesiochronous_rate_matcher/README.md)         | Plesiochronous Rate Matcher     | planned | A2    | P3     | 0.1.0 | 频偏吸收             |
| CDC-012 | [cdc_event_aggregator](components/cdc_rdc/cdc_event_aggregator/README.md)                       | Clock-domain Event Aggregator   | planned | A2    | P1     | 0.1.0 | 同时事件和扇入       |
| CDC-013 | [cdc_config_bridge](components/cdc_rdc/cdc_config_bridge/README.md)                             | Clock-domain Config Bridge      | planned | A2/A3 | P1     | 0.1.0 | 一致性与低频配置     |
| RDC-001 | [async_assert_sync_release_reset](components/cdc_rdc/async_assert_sync_release_reset/README.md) | Async Assert/Sync Release Reset | planned | A1    | P0     | 0.1.0 | 复位恢复/移除时间    |
| RDC-002 | [sync_reset_bridge](components/cdc_rdc/sync_reset_bridge/README.md)                             | Fully Synchronous Reset Bridge  | planned | A2    | P1     | 0.1.0 | 域间顺序             |
| RDC-003 | [reset_pulse_stretcher](components/cdc_rdc/reset_pulse_stretcher/README.md)                     | Reset Pulse Stretcher           | planned | A1/A2 | P0     | 0.1.0 | 最短复位周期         |
| RDC-004 | [reset_domain_isolation](components/cdc_rdc/reset_domain_isolation/README.md)                   | Reset Domain Isolation          | planned | A2    | P1     | 0.1.0 | 失复位域影响隔离     |
| RDC-005 | [reset_sequencer](components/cdc_rdc/reset_sequencer/README.md)                                 | Reset Sequencer                 | planned | A2/A4 | P1     | 0.1.0 | 扇出、启动延迟       |
| RDC-006 | [warm_cold_reset_ctrl](components/cdc_rdc/warm_cold_reset_ctrl/README.md)                       | Warm/Cold Reset Controller      | planned | A2/A4 | P2     | 0.1.0 | 状态保留边界         |

#### components/clock_reset_power（22，implemented=0）

| ID      | 名称                                                                                            | 构件族                               | 状态    | 抽象  | 优先级 | 版本  | 功能/描述            |
|---------|-------------------------------------------------------------------------------------------------|--------------------------------------|---------|-------|--------|-------|----------------------|
| CRP-001 | [local_clock_enable](components/clock_reset_power/local_clock_enable/README.md)                 | Local Clock Enable                   | planned | A1/A0 | P0     | 0.1.0 | 门控粒度与工具识别   |
| CRP-002 | [hierarchical_clock_gating](components/clock_reset_power/hierarchical_clock_gating/README.md)   | Hierarchical Clock Gating Controller | planned | A2    | P1     | 0.1.0 | ICG共享与扇出        |
| CRP-003 | [auto_clock_gating_detector](components/clock_reset_power/auto_clock_gating_detector/README.md) | Auto Clock Gating Detector           | planned | A2    | P2     | 0.1.0 | 收益阈值与唤醒       |
| CRP-004 | [clock_divider](components/clock_reset_power/clock_divider/README.md)                           | Clock Divider                        | planned | A2    | P1     | 0.1.0 | 占空比与毛刺         |
| CRP-005 | [clock_switch_ctrl](components/clock_reset_power/clock_switch_ctrl/README.md)                   | Clock Switch Controller              | planned | A2    | P1     | 0.1.0 | 切换握手和无时钟场景 |
| CRP-006 | [clock_request_ack](components/clock_reset_power/clock_request_ack/README.md)                   | Clock Request/Acknowledge            | planned | A2    | P1     | 0.1.0 | 启停延迟             |
| CRP-007 | [reset_synchronizer](components/clock_reset_power/reset_synchronizer/README.md)                 | Reset Synchronizer                   | planned | A1    | P0     | 0.1.0 | RDC签核属性          |
| CRP-008 | [reset_filter_deglitch](components/clock_reset_power/reset_filter_deglitch/README.md)           | Reset Filter/Deglitch                | planned | A2    | P2     | 0.1.0 | 外部复位噪声         |
| CRP-009 | [reset_cause_collector](components/clock_reset_power/reset_cause_collector/README.md)           | Reset Cause Collector                | planned | A2    | P1     | 0.1.0 | 软件可观测性         |
| CRP-010 | [reset_distribution_helper](components/clock_reset_power/reset_distribution_helper/README.md)   | Reset Distribution Helper            | planned | A2    | P1     | 0.1.0 | 高扇出和局部化       |
| CRP-011 | [operand_isolation](components/clock_reset_power/operand_isolation/README.md)                   | Operand Isolation                    | planned | A1/A2 | P1     | 0.1.0 | 动态功耗与时序代价   |
| CRP-012 | [data_gating](components/clock_reset_power/data_gating/README.md)                               | Data Gating                          | planned | A1/A2 | P1     | 0.1.0 | 毛刺和翻转抑制       |
| CRP-013 | [pipeline_freeze_ctrl](components/clock_reset_power/pipeline_freeze_ctrl/README.md)             | Pipeline Freeze Controller           | planned | A2    | P1     | 0.1.0 | 状态一致性与唤醒     |
| CRP-014 | [idle_detector](components/clock_reset_power/idle_detector/README.md)                           | Idle Detector                        | planned | A2    | P1     | 0.1.0 | 检测功耗和误判       |
| CRP-015 | [activity_detector](components/clock_reset_power/activity_detector/README.md)                   | Activity Detector                    | planned | A2    | P1     | 0.1.0 | 监控开销             |
| CRP-016 | [power_domain_handshake](components/clock_reset_power/power_domain_handshake/README.md)         | Power-domain Handshake               | planned | A2    | P2     | 0.1.0 | UPF状态序列          |
| CRP-017 | [isolation_ctrl_sequencer](components/clock_reset_power/isolation_ctrl_sequencer/README.md)     | Isolation Control Sequencer          | planned | A2    | P2     | 0.1.0 | 安全时序             |
| CRP-018 | [retention_ctrl_sequencer](components/clock_reset_power/retention_ctrl_sequencer/README.md)     | Retention Control Sequencer          | planned | A2    | P2     | 0.1.0 | 数据完整性           |
| CRP-019 | [mem_sleep_controller](components/clock_reset_power/mem_sleep_controller/README.md)             | Memory Sleep Controller              | planned | A2    | P2     | 0.1.0 | break-even与唤醒     |
| CRP-020 | [high_fanout_replicator](components/clock_reset_power/high_fanout_replicator/README.md)         | High-fanout Replicator               | planned | A2    | P1     | 0.1.0 | 功能等价与物理收益   |
| CRP-021 | [config_mirror_local_decode](components/clock_reset_power/config_mirror_local_decode/README.md) | Config Mirror/Local Decode           | planned | A2    | P1     | 0.1.0 | 布线与寄存器面积     |
| CRP-022 | [enable_tree_helper](components/clock_reset_power/enable_tree_helper/README.md)                 | Enable Tree Helper                   | planned | A2    | P1     | 0.1.0 | 时钟周期与控制对齐   |

#### components/coding_integrity（12，implemented=1）

| ID      | 名称                                                                                           | 构件族                        | 状态        | 抽象  | 优先级 | 版本  | 功能/描述              |
|---------|------------------------------------------------------------------------------------------------|-------------------------------|-------------|-------|--------|-------|------------------------|
| COD-001 | [parity_gen_check](components/coding_integrity/parity_gen_check/README.md)                     | Parity Generator/Checker      | implemented | A1    | P0     | 0.1.0 | XOR树平衡              |
| COD-002 | [crc_gen_check](components/coding_integrity/crc_gen_check/README.md)                           | CRC Generator/Checker         | planned     | A2    | P1     | 0.1.0 | 多项式、数据宽度、吞吐 |
| COD-003 | [secded_ecc](components/coding_integrity/secded_ecc/README.md)                                 | SECDED ECC                    | planned     | A2    | P0     | 0.1.0 | 校验位、纠错延迟       |
| COD-004 | [hamming_ecc](components/coding_integrity/hamming_ecc/README.md)                               | Configurable Hamming ECC      | planned     | A2    | P1     | 0.1.0 | 参数合法域             |
| COD-005 | [bch_rs_codec_wrapper](components/coding_integrity/bch_rs_codec_wrapper/README.md)             | BCH/RS Codec Wrapper          | planned     | A2    | P3     | 0.1.0 | 算法复杂度与授权边界   |
| COD-006 | [gray_binary_converter](components/coding_integrity/gray_binary_converter/README.md)           | Gray/Binary Converter         | planned     | A1    | P0     | 0.1.0 | CDC计数器复用          |
| COD-007 | [scrambler_descrambler](components/coding_integrity/scrambler_descrambler/README.md)           | Scrambler/Descrambler         | planned     | A2    | P2     | 0.1.0 | 并行展开与吞吐         |
| COD-008 | [lfsr_prbs](components/coding_integrity/lfsr_prbs/README.md)                                   | LFSR/PRBS                     | planned     | A1/A2 | P1     | 0.1.0 | 多项式与切换功耗       |
| COD-009 | [run_length_codec](components/coding_integrity/run_length_codec/README.md)                     | Run-length Encoder/Decoder    | planned     | A2    | P3     | 0.1.0 | 数据相关吞吐           |
| COD-010 | [zero_suppress_bitmap_codec](components/coding_integrity/zero_suppress_bitmap_codec/README.md) | Zero Suppression/Bitmap Codec | planned     | A2    | P3     | 0.1.0 | 元数据开销与活动率     |
| COD-011 | [byte_bit_order_converter](components/coding_integrity/byte_bit_order_converter/README.md)     | Byte/Bit Order Converter      | planned     | A1    | P0     | 0.1.0 | 固定连线优先           |
| COD-012 | [data_packer_unpacker](components/coding_integrity/data_packer_unpacker/README.md)             | Data Packer/Unpacker          | planned     | A2    | P1     | 0.1.0 | Mux规模与时序          |

#### components/control_event_status（24，implemented=0）

| ID      | 名称                                                                                               | 构件族                     | 状态    | 抽象  | 优先级 | 版本  | 功能/描述          |
|---------|----------------------------------------------------------------------------------------------------|----------------------------|---------|-------|--------|-------|--------------------|
| CTL-001 | [up_down_counter](components/control_event_status/up_down_counter/README.md)                       | Up/Down Counter            | planned | A1    | P0     | 0.1.0 | 最小位宽、切换功耗 |
| CTL-002 | [modulo_counter](components/control_event_status/modulo_counter/README.md)                         | Modulo Counter             | planned | A1    | P0     | 0.1.0 | 比较与回绕         |
| CTL-003 | [timestamp_counter](components/control_event_status/timestamp_counter/README.md)                   | Timestamp Counter          | planned | A1/A2 | P1     | 0.1.0 | 位宽、跨域采样     |
| CTL-004 | [timer](components/control_event_status/timer/README.md)                                           | Timer                      | planned | A2    | P0     | 0.1.0 | Prescaler共享      |
| CTL-005 | [timeout_monitor](components/control_event_status/timeout_monitor/README.md)                       | Timeout Monitor            | planned | A2    | P0     | 0.1.0 | 监控开销与恢复     |
| CTL-006 | [watchdog](components/control_event_status/watchdog/README.md)                                     | Watchdog                   | planned | A2    | P1     | 0.1.0 | 安全诊断覆盖       |
| CTL-007 | [prescaler_rate_divider](components/control_event_status/prescaler_rate_divider/README.md)         | Prescaler/Rate Divider     | planned | A1/A2 | P1     | 0.1.0 | 精度和切换         |
| CTL-008 | [fsm_shell](components/control_event_status/fsm_shell/README.md)                                   | FSM Shell                  | planned | A1/A2 | P0     | 0.1.0 | 编码按表征选型     |
| CTL-009 | [hierarchical_fsm](components/control_event_status/hierarchical_fsm/README.md)                     | Hierarchical FSM           | planned | A2    | P2     | 0.1.0 | 状态爆炸控制       |
| CTL-010 | [micro_sequencer](components/control_event_status/micro_sequencer/README.md)                       | Micro-sequencer            | planned | A2    | P2     | 0.1.0 | 控制ROM与可配置性  |
| CTL-011 | [command_sequencer](components/control_event_status/command_sequencer/README.md)                   | Command Sequencer          | planned | A2    | P2     | 0.1.0 | 状态与Buffer       |
| CTL-012 | [retry_controller](components/control_event_status/retry_controller/README.md)                     | Retry Controller           | planned | A2    | P2     | 0.1.0 | 活锁与计数器       |
| CTL-013 | [event_edge_detector](components/control_event_status/event_edge_detector/README.md)               | Event Edge Detector        | planned | A1    | P0     | 0.1.0 | CDC前后使用约束    |
| CTL-014 | [pulse_stretcher_compressor](components/control_event_status/pulse_stretcher_compressor/README.md) | Pulse Stretcher/Compressor | planned | A1    | P0     | 0.1.0 | 最小脉宽           |
| CTL-015 | [event_collector](components/control_event_status/event_collector/README.md)                       | Event Collector            | planned | A2    | P0     | 0.1.0 | 事件丢失语义       |
| CTL-016 | [event_router](components/control_event_status/event_router/README.md)                             | Event Router               | planned | A2    | P1     | 0.1.0 | Mux、扇出和配置    |
| CTL-017 | [event_debouncer_filter](components/control_event_status/event_debouncer_filter/README.md)         | Event Debouncer/Filter     | planned | A2    | P2     | 0.1.0 | 延迟和外部输入     |
| CTL-018 | [token_credit_counter](components/control_event_status/token_credit_counter/README.md)             | Token/Credit Counter       | planned | A2    | P0     | 0.1.0 | 上下溢保护         |
| CTL-019 | [sequence_number_manager](components/control_event_status/sequence_number_manager/README.md)       | Sequence Number Manager    | planned | A2    | P2     | 0.1.0 | 回绕比较           |
| CTL-020 | [bitmap_allocator](components/control_event_status/bitmap_allocator/README.md)                     | Bitmap Allocator           | planned | A2    | P1     | 0.1.0 | 查找与更新关键路径 |
| CTL-021 | [free_list_manager](components/control_event_status/free_list_manager/README.md)                   | Free-list Manager          | planned | A2    | P2     | 0.1.0 | 多分配/回收        |
| CTL-022 | [scoreboard](components/control_event_status/scoreboard/README.md)                                 | Scoreboard                 | planned | A2    | P2     | 0.1.0 | CAM/bitmap权衡     |
| CTL-023 | [dependency_tracker](components/control_event_status/dependency_tracker/README.md)                 | Dependency Tracker         | planned | A2    | P3     | 0.1.0 | 状态规模           |
| CTL-024 | [quiesce_drain_ctrl](components/control_event_status/quiesce_drain_ctrl/README.md)                 | Quiesce/Drain Controller   | planned | A2    | P1     | 0.1.0 | 低功耗与复位切换   |

#### components/dft_test（10，implemented=0）

| ID      | 名称                                                                                   | 构件族                          | 状态    | 抽象  | 优先级 | 版本  | 功能/描述          |
|---------|----------------------------------------------------------------------------------------|---------------------------------|---------|-------|--------|-------|--------------------|
| DFT-001 | [test_mode_synchronizer](components/dft_test/test_mode_synchronizer/README.md)         | Test-mode Synchronizer          | planned | A1    | P1     | 0.1.0 | 功能/测试模式隔离  |
| DFT-002 | [scan_enable_distribution](components/dft_test/scan_enable_distribution/README.md)     | Scan-enable Distribution Helper | planned | A2    | P2     | 0.1.0 | 高扇出与CTS        |
| DFT-003 | [clock_ctrl_test_override](components/dft_test/clock_ctrl_test_override/README.md)     | Clock-control Test Override     | planned | A0/A2 | P1     | 0.1.0 | DFT与无毛刺        |
| DFT-004 | [reset_ctrl_test_override](components/dft_test/reset_ctrl_test_override/README.md)     | Reset-control Test Override     | planned | A2    | P1     | 0.1.0 | RDC与测试顺序      |
| DFT-005 | [mbist_port_arbiter](components/dft_test/mbist_port_arbiter/README.md)                 | MBIST Port Arbiter              | planned | A2    | P2     | 0.1.0 | Mux延迟和隔离      |
| DFT-006 | [lbist_misr](components/dft_test/lbist_misr/README.md)                                 | LBIST/MISR                      | planned | A2    | P3     | 0.1.0 | 面积和切换峰值     |
| DFT-007 | [prpg](components/dft_test/prpg/README.md)                                             | PRPG                            | planned | A2    | P3     | 0.1.0 | 随机模式与功耗     |
| DFT-008 | [signature_comparator](components/dft_test/signature_comparator/README.md)             | Signature Comparator            | planned | A1/A2 | P3     | 0.1.0 | 测试数据路径       |
| DFT-009 | [test_access_mux](components/dft_test/test_access_mux/README.md)                       | Test Access Mux                 | planned | A3    | P2     | 0.1.0 | 功能路径零影响目标 |
| DFT-010 | [memory_repair_data_adapter](components/dft_test/memory_repair_data_adapter/README.md) | Memory Repair Data Adapter      | planned | A2    | P3     | 0.1.0 | 工艺相关元数据     |

#### components/dsp_ai_datapath（15，implemented=0）

| ID      | 名称                                                                                            | 构件族                            | 状态    | 抽象  | 优先级 | 版本  | 功能/描述             |
|---------|-------------------------------------------------------------------------------------------------|-----------------------------------|---------|-------|--------|-------|-----------------------|
| DSP-001 | [lane_packer_unpacker](components/dsp_ai_datapath/lane_packer_unpacker/README.md)               | Lane Packer/Unpacker              | planned | A2/A3 | P2     | 0.1.0 | 布线和有效位          |
| DSP-002 | [vector_reduction](components/dsp_ai_datapath/vector_reduction/README.md)                       | Vector Reduction                  | planned | A2    | P2     | 0.1.0 | 树形、流水、精度      |
| DSP-003 | [dot_product_tree](components/dsp_ai_datapath/dot_product_tree/README.md)                       | Dot-product Tree                  | planned | A2    | P2     | 0.1.0 | MAC数量与吞吐         |
| DSP-004 | [sliding_window_generator](components/dsp_ai_datapath/sliding_window_generator/README.md)       | Sliding Window Generator          | planned | A2/A3 | P2     | 0.1.0 | 存储带宽和边界        |
| DSP-005 | [tensor_layout_converter](components/dsp_ai_datapath/tensor_layout_converter/README.md)         | Tensor Layout Converter           | planned | A3    | P3     | 0.1.0 | Buffer和地址生成      |
| DSP-006 | [tile_address_generator](components/dsp_ai_datapath/tile_address_generator/README.md)           | Tile Address Generator            | planned | A2    | P2     | 0.1.0 | 乘法消除、增量地址    |
| DSP-007 | [stride_dilation_addr_gen](components/dsp_ai_datapath/stride_dilation_addr_gen/README.md)       | Stride/Dilation Address Generator | planned | A2    | P2     | 0.1.0 | 控制面积和吞吐        |
| DSP-008 | [scatter_gather_index_gen](components/dsp_ai_datapath/scatter_gather_index_gen/README.md)       | Scatter/Gather Index Generator    | planned | A2    | P3     | 0.1.0 | 随机访存和队列        |
| DSP-009 | [dma_descriptor_walker](components/dsp_ai_datapath/dma_descriptor_walker/README.md)             | DMA Descriptor Walker Core        | planned | A4    | P3     | 0.1.0 | 若含完整DMA则升级为IP |
| DSP-010 | [quantization_pipeline](components/dsp_ai_datapath/quantization_pipeline/README.md)             | Quantization Pipeline             | planned | A2/A3 | P2     | 0.1.0 | 位宽、乘法与流水      |
| DSP-011 | [activation_approx](components/dsp_ai_datapath/activation_approx/README.md)                     | Activation Approximation          | planned | A2    | P3     | 0.1.0 | 精度/面积             |
| DSP-012 | [sparse_bitmap_index_decoder](components/dsp_ai_datapath/sparse_bitmap_index_decoder/README.md) | Sparse Bitmap/Index Decoder       | planned | A2/A3 | P3     | 0.1.0 | 控制分支与吞吐        |
| DSP-013 | [accumulator_bank](components/dsp_ai_datapath/accumulator_bank/README.md)                       | Accumulator Bank                  | planned | A2    | P2     | 0.1.0 | 写冲突和位宽          |
| DSP-014 | [double_buffer_ctrl](components/dsp_ai_datapath/double_buffer_ctrl/README.md)                   | Double-buffer Controller          | planned | A2    | P2     | 0.1.0 | 计算搬运重叠          |
| DSP-015 | [loop_nested_counter_gen](components/dsp_ai_datapath/loop_nested_counter_gen/README.md)         | Loop/Nested-counter Generator     | planned | A2    | P2     | 0.1.0 | 控制复用              |

#### components/fifo_queue_buffer（20，implemented=1）

| ID      | 名称                                                                                                | 构件族                       | 状态        | 抽象  | 优先级 | 版本  | 功能/描述                                                                                      |
|---------|-----------------------------------------------------------------------------------------------------|------------------------------|-------------|-------|--------|-------|------------------------------------------------------------------------------------------------|
| QUE-001 | [sync_fifo](components/fifo_queue_buffer/sync_fifo/README.md)                                       | Synchronous FIFO             | planned     | A2    | P0     | 0.1.0 | 深宽自动映射                                                                                   |
| QUE-002 | [async_fifo](components/fifo_queue_buffer/async_fifo/README.md)                                     | Asynchronous FIFO            | planned     | A2    | P0     | 0.1.0 | CDC正确性、深度限制                                                                            |
| QUE-003 | [fall_through_fifo](components/fifo_queue_buffer/fall_through_fifo/README.md)                       | Fall-through FIFO            | planned     | A2    | P0     | 0.1.0 | 首拍延迟与Ready路径                                                                            |
| QUE-004 | [shift_reg_fifo](components/fifo_queue_buffer/shift_reg_fifo/README.md)                             | Shift-register FIFO          | planned     | A2    | P1     | 0.1.0 | 小深度面积与翻转                                                                               |
| QUE-005 | [sram_fifo](components/fifo_queue_buffer/sram_fifo/README.md)                                       | SRAM FIFO                    | planned     | A2    | P1     | 0.1.0 | 读延迟隐藏                                                                                     |
| QUE-006 | [elastic_buffer](components/fifo_queue_buffer/elastic_buffer/README.md)                             | Elastic Buffer               | planned     | A2    | P0     | 0.1.0 | 满吞吐与反压                                                                                   |
| QUE-007 | [skid_buffer](components/fifo_queue_buffer/skid_buffer/README.md)                                   | Skid Buffer                  | implemented | A3    | P0     | 0.3.0 | 切断Ready组合链，满吞吐无气泡（OUT寄存+SKID槽）；forward/full/backward/BYPASS 多实现可对比选型 |
| QUE-008 | [pipeline_fifo](components/fifo_queue_buffer/pipeline_fifo/README.md)                               | Pipeline FIFO                | planned     | A2/A3 | P1     | 0.1.0 | 物理距离与吞吐                                                                                 |
| QUE-009 | [packet_fifo](components/fifo_queue_buffer/packet_fifo/README.md)                                   | Packet FIFO                  | planned     | A2    | P2     | 0.1.0 | 包边界和回滚                                                                                   |
| QUE-010 | [frame_buffer_queue](components/fifo_queue_buffer/frame_buffer_queue/README.md)                     | Frame Buffer Queue           | planned     | A2    | P3     | 0.1.0 | 容量与元数据                                                                                   |
| QUE-011 | [credit_fifo](components/fifo_queue_buffer/credit_fifo/README.md)                                   | Credit FIFO                  | planned     | A2/A3 | P1     | 0.1.0 | Credit一致性                                                                                   |
| QUE-012 | [width_conversion_fifo](components/fifo_queue_buffer/width_conversion_fifo/README.md)               | Width-conversion FIFO        | planned     | A2/A3 | P1     | 0.1.0 | 存储利用率与Mux                                                                                |
| QUE-013 | [multi_channel_fifo](components/fifo_queue_buffer/multi_channel_fifo/README.md)                     | Multi-channel FIFO           | planned     | A2    | P2     | 0.1.0 | RAM共享与仲裁                                                                                  |
| QUE-014 | [multi_enqueue_fifo](components/fifo_queue_buffer/multi_enqueue_fifo/README.md)                     | Multi-enqueue FIFO           | planned     | A2    | P2     | 0.1.0 | 写合并与指针更新                                                                               |
| QUE-015 | [multi_dequeue_fifo](components/fifo_queue_buffer/multi_dequeue_fifo/README.md)                     | Multi-dequeue FIFO           | planned     | A2    | P2     | 0.1.0 | 读端口与输出Mux                                                                                |
| QUE-016 | [reorder_queue](components/fifo_queue_buffer/reorder_queue/README.md)                               | Reorder Queue                | planned     | A2    | P3     | 0.1.0 | 存储与比较功耗                                                                                 |
| QUE-017 | [priority_queue](components/fifo_queue_buffer/priority_queue/README.md)                             | Priority Queue               | planned     | A2    | P3     | 0.1.0 | 延迟与容量                                                                                     |
| QUE-018 | [descriptor_queue](components/fifo_queue_buffer/descriptor_queue/README.md)                         | Descriptor Queue             | planned     | A2    | P2     | 0.1.0 | 控制开销与访存                                                                                 |
| QUE-019 | [replay_retry_buffer](components/fifo_queue_buffer/replay_retry_buffer/README.md)                   | Replay/Retry Buffer          | planned     | A2    | P3     | 0.1.0 | 状态容量和恢复延迟                                                                             |
| QUE-020 | [broadcast_replication_buffer](components/fifo_queue_buffer/broadcast_replication_buffer/README.md) | Broadcast/Replication Buffer | planned     | A2/A3 | P2     | 0.1.0 | 数据复制与背压                                                                                 |

#### components/interrupt_safety（30，implemented=0）

| ID      | 名称                                                                                               | 构件族                              | 状态    | 抽象  | 优先级 | 版本  | 功能/描述            |
|---------|----------------------------------------------------------------------------------------------------|-------------------------------------|---------|-------|--------|-------|----------------------|
| SAF-001 | [parity_protected_register](components/interrupt_safety/parity_protected_register/README.md)       | Parity-protected Register           | planned | A2    | P1     | 0.1.0 | 面积与读写延迟       |
| SAF-002 | [ecc_protected_memory_shell](components/interrupt_safety/ecc_protected_memory_shell/README.md)     | ECC-protected Memory Shell          | planned | A2    | P1     | 0.1.0 | 纠错路径和带宽       |
| SAF-003 | [dual_modular_comparator](components/interrupt_safety/dual_modular_comparator/README.md)           | Dual Modular Comparator             | planned | A2    | P2     | 0.1.0 | 比较覆盖与延迟       |
| SAF-004 | [lockstep_alignment_buffer](components/interrupt_safety/lockstep_alignment_buffer/README.md)       | Lockstep Alignment Buffer           | planned | A2    | P2     | 0.1.0 | 双核对齐与状态       |
| SAF-005 | [lockstep_comparator](components/interrupt_safety/lockstep_comparator/README.md)                   | Lockstep Comparator                 | planned | A2    | P2     | 0.1.0 | 比较宽度与错误延迟   |
| SAF-006 | [temporal_redundancy_ctrl](components/interrupt_safety/temporal_redundancy_ctrl/README.md)         | Temporal Redundancy Controller      | planned | A2    | P3     | 0.1.0 | 性能开销             |
| SAF-007 | [tmr_voter](components/interrupt_safety/tmr_voter/README.md)                                       | TMR Voter                           | planned | A1/A2 | P3     | 0.1.0 | 面积、共因失效边界   |
| SAF-008 | [safety_bypass_mode](components/interrupt_safety/safety_bypass_mode/README.md)                     | Safety Mechanism Bypass/Mode        | planned | A2    | P2     | 0.1.0 | 安全状态与测试       |
| SAF-009 | [fault_injection_point](components/interrupt_safety/fault_injection_point/README.md)               | Fault Injection Point               | planned | A1/A2 | P1     | 0.1.0 | 综合隔离和验证       |
| SAF-010 | [error_status_latch](components/interrupt_safety/error_status_latch/README.md)                     | Error Status Latch                  | planned | A2    | P0     | 0.1.0 | 信息保留与面积       |
| SAF-011 | [error_aggregator](components/interrupt_safety/error_aggregator/README.md)                         | Error Aggregator                    | planned | A2    | P0     | 0.1.0 | 扇入、延迟、去重     |
| SAF-012 | [error_router](components/interrupt_safety/error_router/README.md)                                 | Error Router                        | planned | A2    | P1     | 0.1.0 | 高扇出和配置         |
| SAF-013 | [error_escalation_ctrl](components/interrupt_safety/error_escalation_ctrl/README.md)               | Error Escalation Controller         | planned | A2    | P2     | 0.1.0 | 状态和响应延迟       |
| SAF-014 | [alarm_handler_core](components/interrupt_safety/alarm_handler_core/README.md)                     | Alarm Handler Core                  | planned | A4    | P2     | 0.1.0 | 接近IP，需边界治理   |
| SAF-015 | [bus_transaction_monitor](components/interrupt_safety/bus_transaction_monitor/README.md)           | Bus Transaction Monitor             | planned | A3    | P1     | 0.1.0 | 插入延迟与观测覆盖   |
| SAF-016 | [e2e_protection_codec](components/interrupt_safety/e2e_protection_codec/README.md)                 | End-to-end Protection Codec         | planned | A3    | P2     | 0.1.0 | 带宽、延迟、标准配置 |
| SAF-017 | [duplicate_sequence_checker](components/interrupt_safety/duplicate_sequence_checker/README.md)     | Duplicate/Sequence Checker          | planned | A2/A3 | P2     | 0.1.0 | 窗口容量             |
| SAF-018 | [heartbeat_monitor](components/interrupt_safety/heartbeat_monitor/README.md)                       | Alive/Heartbeat Monitor             | planned | A2    | P1     | 0.1.0 | 误报和监控时钟       |
| SAF-019 | [clock_monitor_shell](components/interrupt_safety/clock_monitor_shell/README.md)                   | Clock Monitor Digital Shell         | planned | A2    | P2     | 0.1.0 | 参考时钟与计数误差   |
| SAF-020 | [reset_monitor](components/interrupt_safety/reset_monitor/README.md)                               | Reset Monitor                       | planned | A2    | P2     | 0.1.0 | RDC与安全状态        |
| SAF-021 | [vt_monitor_wrapper](components/interrupt_safety/vt_monitor_wrapper/README.md)                     | Voltage/Temperature Monitor Wrapper | planned | A0/A2 | P3     | 0.1.0 | 模拟监控器接口       |
| SAF-022 | [safe_state_ctrl](components/interrupt_safety/safe_state_ctrl/README.md)                           | Safe-state Controller               | planned | A2/A4 | P2     | 0.1.0 | 失效响应时间         |
| SAF-023 | [mem_addr_data_protection](components/interrupt_safety/mem_addr_data_protection/README.md)         | Memory Address/Data Protection      | planned | A2    | P2     | 0.1.0 | 存储与延迟开销       |
| SAF-024 | [latent_fault_test_ctrl](components/interrupt_safety/latent_fault_test_ctrl/README.md)             | Latent Fault Test Controller        | planned | A2    | P3     | 0.1.0 | 业务中断与覆盖       |
| SAF-025 | [safety_counter_checker](components/interrupt_safety/safety_counter_checker/README.md)             | Safety Counter Checker              | planned | A1/A2 | P2     | 0.1.0 | 诊断覆盖与面积       |
| SAF-026 | [safety_fsm_checker](components/interrupt_safety/safety_fsm_checker/README.md)                     | Safety FSM Checker                  | planned | A1/A2 | P1     | 0.1.0 | 编码与综合保持       |
| SAF-027 | [interrupt_source_conditioner](components/interrupt_safety/interrupt_source_conditioner/README.md) | Interrupt Source Conditioner        | planned | A2    | P0     | 0.1.0 | PIC前端复用重点      |
| SAF-028 | [interrupt_aggregator](components/interrupt_safety/interrupt_aggregator/README.md)                 | Interrupt Aggregator                | planned | A2    | P0     | 0.1.0 | 大位宽扇入           |
| SAF-029 | [interrupt_router](components/interrupt_safety/interrupt_router/README.md)                         | Interrupt Router                    | planned | A2/A3 | P1     | 0.1.0 | 到CLIC/安全岛双送    |
| SAF-030 | [interrupt_rate_limiter](components/interrupt_safety/interrupt_rate_limiter/README.md)             | Interrupt Rate Limiter              | planned | A2    | P2     | 0.1.0 | 中断风暴控制         |

#### components/monitor_debug（16，implemented=0）

| ID      | 名称                                                                                        | 构件族                           | 状态    | 抽象  | 优先级 | 版本  | 功能/描述        |
|---------|---------------------------------------------------------------------------------------------|----------------------------------|---------|-------|--------|-------|------------------|
| MON-001 | [event_counter](components/monitor_debug/event_counter/README.md)                           | Event Counter                    | planned | A1/A2 | P0     | 0.1.0 | 位宽和门控       |
| MON-002 | [multi_event_counter_bank](components/monitor_debug/multi_event_counter_bank/README.md)     | Multi-event Counter Bank         | planned | A2    | P1     | 0.1.0 | 多事件更新与面积 |
| MON-003 | [cycle_busy_idle_counter](components/monitor_debug/cycle_busy_idle_counter/README.md)       | Cycle/Busy/Idle Counter          | planned | A2    | P0     | 0.1.0 | 时钟功耗         |
| MON-004 | [latency_monitor](components/monitor_debug/latency_monitor/README.md)                       | Latency Monitor                  | planned | A2/A3 | P1     | 0.1.0 | 表项和量化       |
| MON-005 | [bandwidth_monitor](components/monitor_debug/bandwidth_monitor/README.md)                   | Bandwidth Monitor                | planned | A2/A3 | P1     | 0.1.0 | 计数位宽         |
| MON-006 | [occupancy_monitor](components/monitor_debug/occupancy_monitor/README.md)                   | Occupancy Monitor                | planned | A2    | P1     | 0.1.0 | 除法与采样近似   |
| MON-007 | [stall_backpressure_monitor](components/monitor_debug/stall_backpressure_monitor/README.md) | Stall/Backpressure Monitor       | planned | A3    | P1     | 0.1.0 | 信号扇入         |
| MON-008 | [activity_toggle_sampler](components/monitor_debug/activity_toggle_sampler/README.md)       | Activity/Toggle Sampler          | planned | A2    | P2     | 0.1.0 | PPA数据采集开销  |
| MON-009 | [trace_event_encoder](components/monitor_debug/trace_event_encoder/README.md)               | Trace Event Encoder              | planned | A2    | P2     | 0.1.0 | 编码与带宽       |
| MON-010 | [trace_fifo](components/monitor_debug/trace_fifo/README.md)                                 | Trace FIFO                       | planned | A2    | P2     | 0.1.0 | 容量和观测影响   |
| MON-011 | [trace_funnel](components/monitor_debug/trace_funnel/README.md)                             | Trace Funnel                     | planned | A3    | P2     | 0.1.0 | 仲裁与排序       |
| MON-012 | [trigger_qualifier](components/monitor_debug/trigger_qualifier/README.md)                   | Trigger/Qualifier                | planned | A2    | P2     | 0.1.0 | 比较网络         |
| MON-013 | [snapshot_register_bank](components/monitor_debug/snapshot_register_bank/README.md)         | Snapshot Register Bank           | planned | A2    | P1     | 0.1.0 | 面积和采样一致性 |
| MON-014 | [protocol_progress_monitor](components/monitor_debug/protocol_progress_monitor/README.md)   | Protocol Progress Monitor        | planned | A3    | P2     | 0.1.0 | 误报和状态开销   |
| MON-015 | [perf_counter_csr_adapter](components/monitor_debug/perf_counter_csr_adapter/README.md)     | Performance Counter CSR Adapter  | planned | A3    | P1     | 0.1.0 | 统一软件接口     |
| MON-016 | [lightweight_logic_analyzer](components/monitor_debug/lightweight_logic_analyzer/README.md) | Lightweight Logic Analyzer Shell | planned | A4    | P3     | 0.1.0 | 调试配置按需裁剪 |

#### components/noc_interconnect（17，implemented=0）

| ID      | 名称                                                                                           | 构件族                     | 状态    | 抽象  | 优先级 | 版本  | 功能/描述            |
|---------|------------------------------------------------------------------------------------------------|----------------------------|---------|-------|--------|-------|----------------------|
| NOC-001 | [flit_packer_unpacker](components/noc_interconnect/flit_packer_unpacker/README.md)             | Flit Packer/Unpacker       | planned | A3    | P2     | 0.1.0 | Mux、字段映射        |
| NOC-002 | [vc_fifo](components/noc_interconnect/vc_fifo/README.md)                                       | Virtual-channel FIFO       | planned | A3    | P2     | 0.1.0 | RAM利用率与头阻塞    |
| NOC-003 | [vc_allocator](components/noc_interconnect/vc_allocator/README.md)                             | VC Allocator               | planned | A3    | P3     | 0.1.0 | 仲裁规模             |
| NOC-004 | [switch_allocator](components/noc_interconnect/switch_allocator/README.md)                     | Switch Allocator           | planned | A3    | P3     | 0.1.0 | 关键路径核心         |
| NOC-005 | [noc_input_port](components/noc_interconnect/noc_input_port/README.md)                         | NoC Input Port             | planned | A3/A4 | P3     | 0.1.0 | 面积和流控           |
| NOC-006 | [noc_output_port](components/noc_interconnect/noc_output_port/README.md)                       | NoC Output Port            | planned | A3/A4 | P3     | 0.1.0 | 扇入与信用返回       |
| NOC-007 | [crossbar_fabric](components/noc_interconnect/crossbar_fabric/README.md)                       | Crossbar Fabric            | planned | A2/A3 | P2     | 0.1.0 | 布线、Mux、流水      |
| NOC-008 | [route_compute](components/noc_interconnect/route_compute/README.md)                           | Route Compute              | planned | A2/A3 | P3     | 0.1.0 | 组合延迟             |
| NOC-009 | [credit_return_channel](components/noc_interconnect/credit_return_channel/README.md)           | Credit Return Channel      | planned | A3    | P2     | 0.1.0 | 反馈延迟与位宽       |
| NOC-010 | [link_register_slice](components/noc_interconnect/link_register_slice/README.md)               | Link Register Slice        | planned | A3    | P1     | 0.1.0 | 长距离切时序         |
| NOC-011 | [link_cdc_adapter](components/noc_interconnect/link_cdc_adapter/README.md)                     | Link CDC Adapter           | planned | A3    | P2     | 0.1.0 | 时钟关系             |
| NOC-012 | [link_width_converter](components/noc_interconnect/link_width_converter/README.md)             | Link Width Converter       | planned | A3    | P2     | 0.1.0 | Buffer与延迟         |
| NOC-013 | [link_crc_replay_shell](components/noc_interconnect/link_crc_replay_shell/README.md)           | Link CRC/Replay Shell      | planned | A3    | P3     | 0.1.0 | 可靠性和Buffer       |
| NOC-014 | [link_power_state_handshake](components/noc_interconnect/link_power_state_handshake/README.md) | Link Power-state Handshake | planned | A3    | P2     | 0.1.0 | 低功耗序列           |
| NOC-015 | [deadlock_progress_monitor](components/noc_interconnect/deadlock_progress_monitor/README.md)   | Deadlock/Progress Monitor  | planned | A3    | P3     | 0.1.0 | 观测开销             |
| NOC-016 | [chi_ace_channel_slice](components/noc_interconnect/chi_ace_channel_slice/README.md)           | CHI/ACE Channel Slice      | planned | A3    | P3     | 0.1.0 | 一致性协议专项验证   |
| NOC-017 | [chiplet_streaming_adapter](components/noc_interconnect/chiplet_streaming_adapter/README.md)   | Chiplet Streaming Adapter  | planned | A3    | P3     | 0.1.0 | 不替代PHY/标准协议IP |

#### components/register_memory（25，implemented=0）

| ID      | 名称                                                                                            | 构件族                            | 状态    | 抽象  | 优先级 | 版本  | 功能/描述            |
|---------|-------------------------------------------------------------------------------------------------|-----------------------------------|---------|-------|--------|-------|----------------------|
| MEM-001 | [parameter_register](components/register_memory/parameter_register/README.md)                   | Parameter Register                | planned | A1    | P0     | 0.1.0 | Enable推断与时钟功耗 |
| MEM-002 | [shadowed_register](components/register_memory/shadowed_register/README.md)                     | Shadowed Register                 | planned | A2    | P1     | 0.1.0 | 安全一致性与面积     |
| MEM-003 | [sticky_status_register](components/register_memory/sticky_status_register/README.md)           | Sticky/W1C/W1S Register           | planned | A1/A2 | P0     | 0.1.0 | 软件语义与门数       |
| MEM-004 | [register_array](components/register_memory/register_array/README.md)                           | Register Array                    | planned | A2    | P0     | 0.1.0 | 推断RAM或FF阵列      |
| MEM-005 | [rf_1r1w](components/register_memory/rf_1r1w/README.md)                                         | 1R1W Register File                | planned | A2    | P1     | 0.1.0 | 读延迟、RAW bypass   |
| MEM-006 | [rf_multi_read](components/register_memory/rf_multi_read/README.md)                             | Multi-read Register File          | planned | A2    | P1     | 0.1.0 | 面积与端口冲突       |
| MEM-007 | [rf_multi_write](components/register_memory/rf_multi_write/README.md)                           | Multi-write Register File         | planned | A2    | P2     | 0.1.0 | 写冲突与旁路         |
| MEM-008 | [sram_width_composer](components/register_memory/sram_width_composer/README.md)                 | SRAM Width Composer               | planned | A2    | P0     | 0.1.0 | Macro利用率与mask    |
| MEM-009 | [sram_depth_composer](components/register_memory/sram_depth_composer/README.md)                 | SRAM Depth Composer               | planned | A2    | P0     | 0.1.0 | 译码/输出Mux关键路径 |
| MEM-010 | [sram_bank_mapper](components/register_memory/sram_bank_mapper/README.md)                       | SRAM Bank Mapper                  | planned | A2    | P1     | 0.1.0 | 冲突率、地址逻辑     |
| MEM-011 | [sram_port_adapter](components/register_memory/sram_port_adapter/README.md)                     | SRAM Port Adapter                 | planned | A2    | P1     | 0.1.0 | 冲突语义与吞吐       |
| MEM-012 | [memory_raw_bypass](components/register_memory/memory_raw_bypass/README.md)                     | Memory RAW Bypass                 | planned | A2    | P0     | 0.1.0 | 数据一致性与Mux延迟  |
| MEM-013 | [memory_byte_write_adapter](components/register_memory/memory_byte_write_adapter/README.md)     | Memory Byte-write Adapter         | planned | A2    | P1     | 0.1.0 | RMW周期与功耗        |
| MEM-014 | [memory_init_load_adapter](components/register_memory/memory_init_load_adapter/README.md)       | Memory Init/Load Adapter          | planned | A2    | P2     | 0.1.0 | 仿真与综合一致性     |
| MEM-015 | [memory_sleep_ctrl](components/register_memory/memory_sleep_ctrl/README.md)                     | Memory Sleep/Retention Controller | planned | A2    | P2     | 0.1.0 | break-even时间、唤醒 |
| MEM-016 | [memory_ecc_shell](components/register_memory/memory_ecc_shell/README.md)                       | Memory ECC Shell                  | planned | A2    | P1     | 0.1.0 | 延迟、容量、可靠性   |
| MEM-017 | [memory_scrubber](components/register_memory/memory_scrubber/README.md)                         | Memory Scrubber                   | planned | A2    | P2     | 0.1.0 | 带宽占用、功耗       |
| MEM-018 | [memory_bist_if_adapter](components/register_memory/memory_bist_if_adapter/README.md)           | Memory BIST Interface Adapter     | planned | A2    | P2     | 0.1.0 | DFT接口与功能隔离    |
| MEM-019 | [multi_bank_access_scheduler](components/register_memory/multi_bank_access_scheduler/README.md) | Multi-bank Access Scheduler       | planned | A2    | P2     | 0.1.0 | Bank冲突与吞吐       |
| MEM-020 | [ping_pong_buffer](components/register_memory/ping_pong_buffer/README.md)                       | Ping-pong Buffer                  | planned | A2    | P1     | 0.1.0 | 读写重叠与容量       |
| MEM-021 | [line_buffer](components/register_memory/line_buffer/README.md)                                 | Line Buffer                       | planned | A2    | P2     | 0.1.0 | 图像/卷积带宽        |
| MEM-022 | [circular_buffer](components/register_memory/circular_buffer/README.md)                         | Circular Buffer                   | planned | A2    | P1     | 0.1.0 | 地址简化与满空判定   |
| MEM-023 | [lookup_table_rom](components/register_memory/lookup_table_rom/README.md)                       | Lookup Table/ROM                  | planned | A1/A2 | P1     | 0.1.0 | 深宽映射与推断       |
| MEM-024 | [cam](components/register_memory/cam/README.md)                                                 | CAM                               | planned | A2    | P3     | 0.1.0 | 并行比较功耗         |
| MEM-025 | [content_tag_array](components/register_memory/content_tag_array/README.md)                     | Content Tag Array                 | planned | A2    | P3     | 0.1.0 | Cache/TLB公共结构    |

#### components/selection_decode（20，implemented=1）

| ID      | 名称                                                                                               | 构件族                       | 状态        | 抽象 | 优先级 | 版本  | 功能/描述                                                                 |
|---------|----------------------------------------------------------------------------------------------------|------------------------------|-------------|------|--------|-------|---------------------------------------------------------------------------|
| SEL-001 | [binary_mux](components/selection_decode/binary_mux/README.md)                                     | 2:1/N:1 Binary Mux           | planned     | A1   | P0     | 0.1.0 | 扇入、逻辑深度、毛刺                                                      |
| SEL-002 | [onehot_mux](components/selection_decode/onehot_mux/README.md)                                     | One-hot Mux                  | planned     | A1   | P0     | 0.1.0 | One-hot假设、扇出、X处理                                                  |
| SEL-003 | [priority_mux](components/selection_decode/priority_mux/README.md)                                 | Priority Mux                 | planned     | A1   | P1     | 0.1.0 | 优先级链与规模扩展                                                        |
| SEL-004 | [sparse_masked_mux](components/selection_decode/sparse_masked_mux/README.md)                       | Sparse/Masked Mux            | planned     | A1   | P2     | 0.1.0 | 无效输入消除、综合稳定性                                                  |
| SEL-005 | [cross_point_switch](components/selection_decode/cross_point_switch/README.md)                     | Cross-point Switch           | planned     | A2   | P2     | 0.1.0 | 交叉规模、布线与流水                                                      |
| SEL-006 | [binary_encoder](components/selection_decode/binary_encoder/README.md)                             | Binary Encoder               | planned     | A1   | P0     | 0.1.0 | 位宽与深度                                                                |
| SEL-007 | [onehot_encoder](components/selection_decode/onehot_encoder/README.md)                             | One-hot Encoder              | planned     | A1   | P0     | 0.1.0 | 非法输入语义                                                              |
| SEL-008 | [decoder](components/selection_decode/decoder/README.md)                                           | Decoder                      | planned     | A1   | P0     | 0.1.0 | 高扇出、本地译码                                                          |
| SEL-009 | [priority_encoder](components/selection_decode/priority_encoder/README.md)                         | Priority Encoder             | planned     | A1   | P0     | 0.1.0 | 深优先级链                                                                |
| SEL-010 | [thermometer_codec](components/selection_decode/thermometer_codec/README.md)                       | Thermometer Encoder/Decoder  | planned     | A1   | P3     | 0.1.0 | 编码密度与毛刺                                                            |
| SEL-011 | [lzc_lzd](components/selection_decode/lzc_lzd/README.md)                                           | Leading Zero/One Count       | planned     | A1   | P1     | 0.1.0 | 关键路径、前缀结构                                                        |
| SEL-012 | [tzc_lzd](components/selection_decode/tzc_lzd/README.md)                                           | Trailing Zero/One Count      | planned     | A1   | P2     | 0.1.0 | 共享反转逻辑                                                              |
| SEL-013 | [bit_scan_first_set](components/selection_decode/bit_scan_first_set/README.md)                     | Bit Scan/First-set           | planned     | A1   | P1     | 0.1.0 | 大位宽时序                                                                |
| SEL-014 | [popcount](components/selection_decode/popcount/README.md)                                         | Population Count             | implemented | A1   | P1     | 0.1.0 | 面积/时序Pareto（直接加法基线 + 平衡树 + Wallace + 4:2 compressor + LUT） |
| SEL-015 | [onehot_checker](components/selection_decode/onehot_checker/README.md)                             | One-hot Checker              | planned     | A1   | P0     | 0.1.0 | 安全检查复用                                                              |
| SEL-016 | [range_comparator](components/selection_decode/range_comparator/README.md)                         | Range Comparator             | planned     | A1   | P1     | 0.1.0 | 共享比较与译码                                                            |
| SEL-017 | [address_decoder](components/selection_decode/address_decoder/README.md)                           | Address Decoder              | planned     | A2   | P0     | 0.1.0 | 比较器共享、扇出                                                          |
| SEL-018 | [hierarchical_address_decoder](components/selection_decode/hierarchical_address_decoder/README.md) | Hierarchical Address Decoder | planned     | A2   | P1     | 0.1.0 | 大规模地址空间时序                                                        |
| SEL-019 | [configurable_truth_table](components/selection_decode/configurable_truth_table/README.md)         | Configurable Truth Table     | planned     | A1   | P3     | 0.1.0 | 面积与综合推断                                                            |
| SEL-020 | [bit_permutation_network](components/selection_decode/bit_permutation_network/README.md)           | Bit Permutation Network      | planned     | A2   | P3     | 0.1.0 | 布线主导、配置代价                                                        |

#### components/streaming_pipeline（25，implemented=0）

| ID      | 名称                                                                                           | 构件族                    | 状态    | 抽象  | 优先级 | 版本  | 功能/描述          |
|---------|------------------------------------------------------------------------------------------------|---------------------------|---------|-------|--------|-------|--------------------|
| STR-001 | [fixed_delay_line](components/streaming_pipeline/fixed_delay_line/README.md)                   | Fixed Delay Line          | planned | A1/A2 | P0     | 0.1.0 | 延迟、面积、初始化 |
| STR-002 | [enable_delay_line](components/streaming_pipeline/enable_delay_line/README.md)                 | Enable Delay Line         | planned | A1/A2 | P1     | 0.1.0 | 空闲功耗           |
| STR-003 | [data_control_aligner](components/streaming_pipeline/data_control_aligner/README.md)           | Data/Control Aligner      | planned | A2    | P0     | 0.1.0 | 控制数据一致性     |
| STR-004 | [forward_register_slice](components/streaming_pipeline/forward_register_slice/README.md)       | Forward Register Slice    | planned | A3    | P0     | 0.1.0 | 数据关键路径       |
| STR-005 | [backward_register_slice](components/streaming_pipeline/backward_register_slice/README.md)     | Backward Register Slice   | planned | A3    | P0     | 0.1.0 | 反压关键路径       |
| STR-006 | [full_register_slice](components/streaming_pipeline/full_register_slice/README.md)             | Full Register Slice       | planned | A3    | P0     | 0.1.0 | 双向切时序         |
| STR-007 | [bypassable_register_slice](components/streaming_pipeline/bypassable_register_slice/README.md) | Bypassable Register Slice | planned | A3    | P1     | 0.1.0 | 模式Mux与验证      |
| STR-008 | [stream_mux](components/streaming_pipeline/stream_mux/README.md)                               | Stream Mux                | planned | A3    | P0     | 0.1.0 | 选择与反压         |
| STR-009 | [stream_demux](components/streaming_pipeline/stream_demux/README.md)                           | Stream Demux              | planned | A3    | P0     | 0.1.0 | 输出Ready聚合      |
| STR-010 | [stream_fork](components/streaming_pipeline/stream_fork/README.md)                             | Stream Fork               | planned | A3    | P1     | 0.1.0 | 复制和阻塞语义     |
| STR-011 | [stream_join](components/streaming_pipeline/stream_join/README.md)                             | Stream Join               | planned | A3    | P1     | 0.1.0 | 同步等待与Buffer   |
| STR-012 | [stream_merge](components/streaming_pipeline/stream_merge/README.md)                           | Stream Merge              | planned | A3    | P1     | 0.1.0 | 仲裁与包锁定       |
| STR-013 | [stream_split](components/streaming_pipeline/stream_split/README.md)                           | Stream Split              | planned | A3    | P2     | 0.1.0 | 状态与边界         |
| STR-014 | [stream_width_converter](components/streaming_pipeline/stream_width_converter/README.md)       | Stream Width Converter    | planned | A3    | P1     | 0.1.0 | Gearbox与跨拍状态  |
| STR-015 | [stream_gearbox](components/streaming_pipeline/stream_gearbox/README.md)                       | Stream Gearbox            | planned | A3    | P2     | 0.1.0 | 相位、吞吐、布线   |
| STR-016 | [stream_rate_matcher](components/streaming_pipeline/stream_rate_matcher/README.md)             | Stream Rate Matcher       | planned | A3    | P2     | 0.1.0 | 速率与Buffer深度   |
| STR-017 | [stream_packetizer](components/streaming_pipeline/stream_packetizer/README.md)                 | Stream Packetizer         | planned | A3    | P2     | 0.1.0 | 包头Mux与CRC衔接   |
| STR-018 | [stream_depacketizer](components/streaming_pipeline/stream_depacketizer/README.md)             | Stream Depacketizer       | planned | A3    | P2     | 0.1.0 | 解析关键路径       |
| STR-019 | [stream_arbiter](components/streaming_pipeline/stream_arbiter/README.md)                       | Stream Arbiter            | planned | A3    | P1     | 0.1.0 | 公平性和切换气泡   |
| STR-020 | [stream_multicast](components/streaming_pipeline/stream_multicast/README.md)                   | Stream Multicast          | planned | A3    | P2     | 0.1.0 | Ready汇聚与复制    |
| STR-021 | [stream_broadcaster](components/streaming_pipeline/stream_broadcaster/README.md)               | Stream Broadcaster        | planned | A3    | P1     | 0.1.0 | 高扇出与物理距离   |
| STR-022 | [stream_throttler](components/streaming_pipeline/stream_throttler/README.md)                   | Stream Throttler          | planned | A3    | P2     | 0.1.0 | 控制翻转和精度     |
| STR-023 | [stream_traffic_shaper](components/streaming_pipeline/stream_traffic_shaper/README.md)         | Stream Traffic Shaper     | planned | A3    | P3     | 0.1.0 | 速率状态和突发     |
| STR-024 | [stream_monitor_tap](components/streaming_pipeline/stream_monitor_tap/README.md)               | Stream Monitor Tap        | planned | A3    | P2     | 0.1.0 | 零干扰与观测开销   |
| STR-025 | [bubble_inserter_remover](components/streaming_pipeline/bubble_inserter_remover/README.md)     | Bubble Inserter/Remover   | planned | A3    | P3     | 0.1.0 | 时序整形           |

#### templates（24，implemented=0）

| ID      | 名称                                                                                     | 构件族                  | 状态    | 抽象 | 优先级 | 版本  | 功能/描述              |
|---------|------------------------------------------------------------------------------------------|-------------------------|---------|------|--------|-------|------------------------|
| TMP-001 | [multi_bank_sram_subsystem](templates/multi_bank_sram_subsystem/README.md)               | 多Bank SRAM子系统       | planned | A4   | P1     | 0.1.0 | 容量、吞吐、功耗Pareto |
| TMP-002 | [low_latency_rf_subsystem](templates/low_latency_rf_subsystem/README.md)                 | 低延迟寄存器文件子系统  | planned | A4   | P2     | 0.1.0 | 多读端口优化           |
| TMP-003 | [shared_operator_template](templates/shared_operator_template/README.md)                 | 共享运算单元模板        | planned | A4   | P1     | 0.1.0 | 面积换延迟             |
| TMP-004 | [high_throughput_add_mac_tree](templates/high_throughput_add_mac_tree/README.md)         | 高吞吐加法/MAC树        | planned | A4   | P1     | 0.1.0 | 数据通路示范闭环       |
| TMP-005 | [high_freq_ready_valid_channel](templates/high_freq_ready_valid_channel/README.md)       | 高频 Ready/Valid 通道   | planned | A4   | P0     | 0.1.0 | 自动切分反压路径       |
| TMP-006 | [long_distance_physical_link](templates/long_distance_physical_link/README.md)           | 长距离物理链路          | planned | A4   | P1     | 0.1.0 | 跨分区时序收敛         |
| TMP-007 | [hierarchical_arbitration_network](templates/hierarchical_arbitration_network/README.md) | 分层仲裁网络            | planned | A4   | P1     | 0.1.0 | 32/64/128路扩展        |
| TMP-008 | [hierarchical_decode_network](templates/hierarchical_decode_network/README.md)           | 分层地址译码网络        | planned | A4   | P1     | 0.1.0 | 高扇出和响应Mux        |
| TMP-009 | [axi_shared_interconnect_template](templates/axi_shared_interconnect_template/README.md) | AXI共享互联模板         | planned | A4   | P2     | 0.1.0 | 可裁剪互联             |
| TMP-010 | [axi_async_bridge_template](templates/axi_async_bridge_template/README.md)               | AXI异步桥模板           | planned | A4   | P1     | 0.1.0 | 宽总线跨域PPA          |
| TMP-011 | [axi_width_bridge_template](templates/axi_width_bridge_template/README.md)               | AXI宽度转换桥模板       | planned | A4   | P2     | 0.1.0 | 32～1024bit适配        |
| TMP-012 | [apb_peripheral_cluster_template](templates/apb_peripheral_cluster_template/README.md)   | APB外设簇模板           | planned | A4   | P1     | 0.1.0 | 低面积控制面           |
| TMP-013 | [noc_router_template](templates/noc_router_template/README.md)                           | NoC Router模板          | planned | A4   | P3     | 0.1.0 | 先进互联研究           |
| TMP-014 | [safe_interrupt_frontend_template](templates/safe_interrupt_frontend_template/README.md) | 安全中断前端模板        | planned | A4   | P1     | 0.1.0 | PIC/CLIC/安全岛复用    |
| TMP-015 | [error_management_tree_template](templates/error_management_tree_template/README.md)     | 错误管理树模板          | planned | A4   | P1     | 0.1.0 | 功能安全公共架构       |
| TMP-016 | [power_domain_ctrl_template](templates/power_domain_ctrl_template/README.md)             | 电源域控制模板          | planned | A4   | P2     | 0.1.0 | UPF控制闭环            |
| TMP-017 | [clock_reset_manager_template](templates/clock_reset_manager_template/README.md)         | Clock/Reset Manager模板 | planned | A4   | P2     | 0.1.0 | 时钟复位公共方案       |
| TMP-018 | [low_power_pipeline_template](templates/low_power_pipeline_template/README.md)           | 低功耗流水线模板        | planned | A4   | P1     | 0.1.0 | 活动相关功耗优化       |
| TMP-019 | [high_fanout_ctrl_recipe](templates/high_fanout_ctrl_recipe/README.md)                   | 高扇出控制优化配方      | planned | A4   | P1     | 0.1.0 | 布线和时序             |
| TMP-020 | [streaming_data_shaping_template](templates/streaming_data_shaping_template/README.md)   | 流式数据整形模板        | planned | A4   | P2     | 0.1.0 | 复合协议适配           |
| TMP-021 | [e2e_data_protection_channel](templates/e2e_data_protection_channel/README.md)           | 端到端数据保护通道      | planned | A4   | P2     | 0.1.0 | 安全通信链             |
| TMP-022 | [perf_observation_subsystem](templates/perf_observation_subsystem/README.md)             | 性能观测子系统          | planned | A4   | P2     | 0.1.0 | 可观测性按需裁剪       |
| TMP-023 | [memory_bist_access_template](templates/memory_bist_access_template/README.md)           | Memory BIST接入模板     | planned | A4   | P3     | 0.1.0 | DFT一致接入            |
| TMP-024 | [dsp_double_buffer_datapath](templates/dsp_double_buffer_datapath/README.md)             | DSP双缓冲数据通路       | planned | A4   | P3     | 0.1.0 | 搬运计算重叠           |


<!-- REGISTRY-STATUS:END -->

（历史说明：此前 QUE-001 sync_fifo / QUE-012 width_conversion_fifo 工程包已移除、
registry 条目回退 planned；SEL-014 popcount 曾于 2026-08-28 移除后同日重建，
历史证据见 `reports/quality/run_log.md`。完整候选清单见 [`registry.yaml`](registry.yaml:1)。）

## 贡献交付件

新 CBB 交付流程（需求→契约→RTL→验证→PPA→发布）由 cbb-development-suite 定义；本仓库在交付件就绪后：

1. 在 `components/` 对应类别下放置完整工程包（含 `fusesoc/aixsilicon_cbb_<name>.core`）；
2. 在 [`registry.yaml`](registry.yaml:1) 中登记/更新条目（`status=implemented`）；
3. 更新 `CHANGELOG.md` 与版本。

## 许可

Apache-2.0（见 [`LICENSE`](LICENSE:1)）。
