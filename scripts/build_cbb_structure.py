#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_cbb_structure.py — 根据 cbb_repo_list.md 生成 CBB 目录结构

- 解析 cbb_repo_list.md（第 2~20 节表格）
- 按功能类别生成目录：adapters/（A0）、components/<类别>/（A1~A3）、templates/（A4）
- 每个 CBB 目录以**功能名**命名（如 apb_slave_adapter），内含 README.md 需求说明占位
- 生成各类别 README 与根 registry.yaml 索引（ID 保留在元数据中）

用法:
  python3 scripts/build_cbb_structure.py
"""
import os
import re
import shutil
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST_PATH = os.path.join(ROOT, "cbb_repo_list.md")

# 章节号 -> (顶层目录, 类别目录, 类别标题)
SECTIONS = {
    2:  ("adapters", None, "工艺与物理实现适配"),
    3:  ("components", "selection_decode", "基础位操作、编码与选择网络"),
    4:  ("components", "arithmetic_datapath", "算术与数值数据通路"),
    5:  ("components", "coding_integrity", "CRC、编码、压缩与数据完整性算法"),
    6:  ("components", "register_memory", "寄存器、存储器与存储映射"),
    7:  ("components", "fifo_queue_buffer", "FIFO、Queue 与 Buffer"),
    8:  ("components", "streaming_pipeline", "流水、Ready/Valid 与流处理"),
    9:  ("components", "arbitration_scheduling", "仲裁、调度、共享与流控"),
    10: ("components", "cdc_rdc", "CDC、RDC 与多时钟域"),
    11: ("components", "clock_reset_power", "时钟、复位、功耗与高扇出优化"),
    12: ("components", "control_event_status", "控制、计数、事件与状态管理"),
    13: ("components", "interrupt_safety", "中断、错误与功能安全公共构件"),
    14: ("components", "apb_ahb_register", "APB/AHB/寄存器接口构件"),
    15: ("components", "axi_axi_stream", "AXI4/AXI4-Lite/AXI-Stream 构件"),
    16: ("components", "noc_interconnect", "NoC、片间与高级互联公共构件"),
    17: ("components", "monitor_debug", "监控、调试、性能与可观测性"),
    18: ("components", "dft_test", "DFT、测试与可制造性辅助"),
    19: ("components", "dsp_ai_datapath", "DSP、图像与 AI 数据搬运公共构件"),
    20: ("templates", None, "子系统模板与参考架构配方"),
}

# ID -> 功能名（目录名，小写蛇形；与 IP 功能相关）
CBB_NAMES = {
    # ---- A0 工艺与物理实现适配（TEC）----
    "TEC-001": "generic_comb_wrapper", "TEC-002": "dff_wrapper",
    "TEC-003": "mbff_wrapper", "TEC-004": "latch_wrapper",
    "TEC-005": "icg_wrapper", "TEC-006": "glitch_free_clock_mux",
    "TEC-007": "clock_divider_cell_wrapper", "TEC-008": "clock_buffer_wrapper",
    "TEC-009": "level_shifter_wrapper", "TEC-010": "isolation_cell_wrapper",
    "TEC-011": "retention_ff_wrapper", "TEC-012": "power_switch_ctrl_wrapper",
    "TEC-013": "tie_cell_wrapper", "TEC-014": "scan_lockup_wrapper",
    "TEC-015": "sram_macro_wrapper", "TEC-016": "register_file_macro_wrapper",
    "TEC-017": "rom_macro_wrapper", "TEC-018": "cam_macro_wrapper",
    "TEC-019": "efuse_otp_wrapper", "TEC-020": "pll_dll_osc_wrapper",
    "TEC-021": "fpga_memory_wrapper", "TEC-022": "fpga_dsp_wrapper",
    # ---- 基础位操作、编码与选择网络（SEL）----
    "SEL-001": "binary_mux", "SEL-002": "onehot_mux",
    "SEL-003": "priority_mux", "SEL-004": "sparse_masked_mux",
    "SEL-005": "cross_point_switch", "SEL-006": "binary_encoder",
    "SEL-007": "onehot_encoder", "SEL-008": "decoder",
    "SEL-009": "priority_encoder", "SEL-010": "thermometer_codec",
    "SEL-011": "lzc_lzd", "SEL-012": "tzc_lzd",
    "SEL-013": "bit_scan_first_set", "SEL-014": "popcount",
    "SEL-015": "onehot_checker", "SEL-016": "range_comparator",
    "SEL-017": "address_decoder", "SEL-018": "hierarchical_address_decoder",
    "SEL-019": "configurable_truth_table", "SEL-020": "bit_permutation_network",
    # ---- 算术与数值数据通路（ARI）----
    "ARI-001": "incrementer_decrementer", "ARI-002": "adder_subtractor",
    "ARI-003": "carry_save_adder", "ARI-004": "multi_operand_adder",
    "ARI-005": "adder_tree", "ARI-006": "accumulator",
    "ARI-007": "absolute_value_negate", "ARI-008": "comparator",
    "ARI-009": "multiway_min_max", "ARI-010": "clamp_clip",
    "ARI-011": "saturating_add_sub", "ARI-012": "fixed_point_round",
    "ARI-013": "fixed_point_resize", "ARI-014": "scale_shift",
    "ARI-015": "logical_arith_shifter", "ARI-016": "rotator_funnel_shifter",
    "ARI-017": "integer_multiplier", "ARI-018": "constant_multiplier",
    "ARI-019": "mac", "ARI-020": "dot_product_engine",
    "ARI-021": "integer_divider", "ARI-022": "constant_divider",
    "ARI-023": "modulo_reducer", "ARI-024": "square_sum_squares",
    "ARI-025": "average_weighted_sum", "ARI-026": "reciprocal_rsqrt_approx",
    "ARI-027": "cordic", "ARI-028": "polynomial_evaluator",
    "ARI-029": "bcd_binary_converter", "ARI-030": "decimal_bcd_arith",
    "ARI-031": "fp_classify_compare", "ARI-032": "fp_math_shell",
    "ARI-033": "block_fp_scale", "ARI-034": "quantize_dequantize",
    "ARI-035": "packed_simd_lane_op",
    # ---- CRC、编码、压缩与数据完整性（COD）----
    "COD-001": "parity_gen_check", "COD-002": "crc_gen_check",
    "COD-003": "secded_ecc", "COD-004": "hamming_ecc",
    "COD-005": "bch_rs_codec_wrapper", "COD-006": "gray_binary_converter",
    "COD-007": "scrambler_descrambler", "COD-008": "lfsr_prbs",
    "COD-009": "run_length_codec", "COD-010": "zero_suppress_bitmap_codec",
    "COD-011": "byte_bit_order_converter", "COD-012": "data_packer_unpacker",
    # ---- 寄存器、存储器与存储映射（MEM）----
    "MEM-001": "parameter_register", "MEM-002": "shadowed_register",
    "MEM-003": "sticky_status_register", "MEM-004": "register_array",
    "MEM-005": "rf_1r1w", "MEM-006": "rf_multi_read",
    "MEM-007": "rf_multi_write", "MEM-008": "sram_width_composer",
    "MEM-009": "sram_depth_composer", "MEM-010": "sram_bank_mapper",
    "MEM-011": "sram_port_adapter", "MEM-012": "memory_raw_bypass",
    "MEM-013": "memory_byte_write_adapter", "MEM-014": "memory_init_load_adapter",
    "MEM-015": "memory_sleep_ctrl", "MEM-016": "memory_ecc_shell",
    "MEM-017": "memory_scrubber", "MEM-018": "memory_bist_if_adapter",
    "MEM-019": "multi_bank_access_scheduler", "MEM-020": "ping_pong_buffer",
    "MEM-021": "line_buffer", "MEM-022": "circular_buffer",
    "MEM-023": "lookup_table_rom", "MEM-024": "cam",
    "MEM-025": "content_tag_array",
    # ---- FIFO、Queue 与 Buffer（QUE）----
    "QUE-001": "sync_fifo", "QUE-002": "async_fifo",
    "QUE-003": "fall_through_fifo", "QUE-004": "shift_reg_fifo",
    "QUE-005": "sram_fifo", "QUE-006": "elastic_buffer",
    "QUE-007": "skid_buffer", "QUE-008": "pipeline_fifo",
    "QUE-009": "packet_fifo", "QUE-010": "frame_buffer_queue",
    "QUE-011": "credit_fifo", "QUE-012": "width_conversion_fifo",
    "QUE-013": "multi_channel_fifo", "QUE-014": "multi_enqueue_fifo",
    "QUE-015": "multi_dequeue_fifo", "QUE-016": "reorder_queue",
    "QUE-017": "priority_queue", "QUE-018": "descriptor_queue",
    "QUE-019": "replay_retry_buffer", "QUE-020": "broadcast_replication_buffer",
    # ---- 流水、Ready/Valid 与流处理（STR）----
    "STR-001": "fixed_delay_line", "STR-002": "enable_delay_line",
    "STR-003": "data_control_aligner", "STR-004": "forward_register_slice",
    "STR-005": "backward_register_slice", "STR-006": "full_register_slice",
    "STR-007": "bypassable_register_slice", "STR-008": "stream_mux",
    "STR-009": "stream_demux", "STR-010": "stream_fork",
    "STR-011": "stream_join", "STR-012": "stream_merge",
    "STR-013": "stream_split", "STR-014": "stream_width_converter",
    "STR-015": "stream_gearbox", "STR-016": "stream_rate_matcher",
    "STR-017": "stream_packetizer", "STR-018": "stream_depacketizer",
    "STR-019": "stream_arbiter", "STR-020": "stream_multicast",
    "STR-021": "stream_broadcaster", "STR-022": "stream_throttler",
    "STR-023": "stream_traffic_shaper", "STR-024": "stream_monitor_tap",
    "STR-025": "bubble_inserter_remover",
    # ---- 仲裁、调度、共享与流控（ARB）----
    "ARB-001": "fixed_priority_arbiter", "ARB-002": "round_robin_arbiter",
    "ARB-003": "weighted_rr_arbiter", "ARB-004": "deficit_rr_arbiter",
    "ARB-005": "age_based_arbiter", "ARB-006": "lottery_arbiter",
    "ARB-007": "multi_grant_arbiter", "ARB-008": "hierarchical_arbiter",
    "ARB-009": "pipelined_arbiter", "ARB-010": "packet_locking_arbiter",
    "ARB-011": "credit_manager", "ARB-012": "token_allocator",
    "ARB-013": "resource_pool_manager", "ARB-014": "request_coalescer",
    "ARB-015": "request_distributor", "ARB-016": "shared_operator_scheduler",
    "ARB-017": "bank_conflict_resolver", "ARB-018": "outstanding_tracker",
    "ARB-019": "reservation_lock_manager", "ARB-020": "barrier_join_controller",
    # ---- CDC、RDC 与多时钟域（CDC/RDC）----
    "CDC-001": "single_bit_synchronizer", "CDC-002": "multibit_static_synchronizer",
    "CDC-003": "pulse_synchronizer", "CDC-004": "toggle_synchronizer",
    "CDC-005": "handshake_synchronizer", "CDC-006": "bundled_data_cdc",
    "CDC-007": "bus_snapshot_cdc", "CDC-008": "gray_counter_cdc",
    "CDC-009": "async_fifo_cdc", "CDC-010": "mesochronous_elastic_buffer",
    "CDC-011": "plesiochronous_rate_matcher", "CDC-012": "cdc_event_aggregator",
    "CDC-013": "cdc_config_bridge",
    "RDC-001": "async_assert_sync_release_reset", "RDC-002": "sync_reset_bridge",
    "RDC-003": "reset_pulse_stretcher", "RDC-004": "reset_domain_isolation",
    "RDC-005": "reset_sequencer", "RDC-006": "warm_cold_reset_ctrl",
    # ---- 时钟、复位、功耗与高扇出优化（CRP）----
    "CRP-001": "local_clock_enable", "CRP-002": "hierarchical_clock_gating",
    "CRP-003": "auto_clock_gating_detector", "CRP-004": "clock_divider",
    "CRP-005": "clock_switch_ctrl", "CRP-006": "clock_request_ack",
    "CRP-007": "reset_synchronizer", "CRP-008": "reset_filter_deglitch",
    "CRP-009": "reset_cause_collector", "CRP-010": "reset_distribution_helper",
    "CRP-011": "operand_isolation", "CRP-012": "data_gating",
    "CRP-013": "pipeline_freeze_ctrl", "CRP-014": "idle_detector",
    "CRP-015": "activity_detector", "CRP-016": "power_domain_handshake",
    "CRP-017": "isolation_ctrl_sequencer", "CRP-018": "retention_ctrl_sequencer",
    "CRP-019": "mem_sleep_controller", "CRP-020": "high_fanout_replicator",
    "CRP-021": "config_mirror_local_decode", "CRP-022": "enable_tree_helper",
    # ---- 控制、计数、事件与状态管理（CTL）----
    "CTL-001": "up_down_counter", "CTL-002": "modulo_counter",
    "CTL-003": "timestamp_counter", "CTL-004": "timer",
    "CTL-005": "timeout_monitor", "CTL-006": "watchdog",
    "CTL-007": "prescaler_rate_divider", "CTL-008": "fsm_shell",
    "CTL-009": "hierarchical_fsm", "CTL-010": "micro_sequencer",
    "CTL-011": "command_sequencer", "CTL-012": "retry_controller",
    "CTL-013": "event_edge_detector", "CTL-014": "pulse_stretcher_compressor",
    "CTL-015": "event_collector", "CTL-016": "event_router",
    "CTL-017": "event_debouncer_filter", "CTL-018": "token_credit_counter",
    "CTL-019": "sequence_number_manager", "CTL-020": "bitmap_allocator",
    "CTL-021": "free_list_manager", "CTL-022": "scoreboard",
    "CTL-023": "dependency_tracker", "CTL-024": "quiesce_drain_ctrl",
    # ---- 中断、错误与功能安全公共构件（SAF）----
    "SAF-001": "parity_protected_register", "SAF-002": "ecc_protected_memory_shell",
    "SAF-003": "dual_modular_comparator", "SAF-004": "lockstep_alignment_buffer",
    "SAF-005": "lockstep_comparator", "SAF-006": "temporal_redundancy_ctrl",
    "SAF-007": "tmr_voter", "SAF-008": "safety_bypass_mode",
    "SAF-009": "fault_injection_point", "SAF-010": "error_status_latch",
    "SAF-011": "error_aggregator", "SAF-012": "error_router",
    "SAF-013": "error_escalation_ctrl", "SAF-014": "alarm_handler_core",
    "SAF-015": "bus_transaction_monitor", "SAF-016": "e2e_protection_codec",
    "SAF-017": "duplicate_sequence_checker", "SAF-018": "heartbeat_monitor",
    "SAF-019": "clock_monitor_shell", "SAF-020": "reset_monitor",
    "SAF-021": "vt_monitor_wrapper", "SAF-022": "safe_state_ctrl",
    "SAF-023": "mem_addr_data_protection", "SAF-024": "latent_fault_test_ctrl",
    "SAF-025": "safety_counter_checker", "SAF-026": "safety_fsm_checker",
    "SAF-027": "interrupt_source_conditioner", "SAF-028": "interrupt_aggregator",
    "SAF-029": "interrupt_router", "SAF-030": "interrupt_rate_limiter",
    # ---- APB/AHB/寄存器接口构件（BUS）----
    "BUS-001": "generic_csr_adapter", "BUS-002": "apb_slave_adapter",
    "BUS-003": "apb_register_slice", "BUS-004": "apb_decoder",
    "BUS-005": "apb_mux_interconnect", "BUS-006": "apb_cdc_bridge",
    "BUS-007": "apb_width_adapter", "BUS-008": "apb_timeout_default_slave",
    "BUS-009": "ahb_lite_slave_adapter", "BUS-010": "ahb_lite_register_slice",
    "BUS-011": "ahb_lite_decoder_mux", "BUS-012": "ahb_lite_cdc_bridge",
    "BUS-013": "ahb_apb_bridge", "BUS-014": "csr_shadow_commit_adapter",
    "BUS-015": "csr_access_policy_filter", "BUS-016": "register_broadcast_adapter",
    # ---- AXI4/AXI4-Lite/AXI-Stream 构件（AXI/AXIS）----
    "AXI-001": "axi_channel_register_slice", "AXI-002": "axi_lite_register_slice",
    "AXI-003": "axi_buffer", "AXI-004": "axi_width_converter",
    "AXI-005": "axi_addr_width_adapter", "AXI-006": "axi_id_converter",
    "AXI-007": "axi_user_signal_adapter", "AXI-008": "axi_burst_splitter",
    "AXI-009": "axi_burst_merger", "AXI-010": "axi_burst_length_adapter",
    "AXI-011": "axi_outstanding_limiter", "AXI-012": "axi_id_remapper",
    "AXI-013": "axi_transaction_serializer", "AXI-014": "axi_rw_interleaver",
    "AXI-015": "axi_clock_converter", "AXI-016": "axi_protocol_converter",
    "AXI-017": "axi_apb_bridge", "AXI-018": "axi_ahb_bridge",
    "AXI-019": "axi_address_decoder", "AXI-020": "axi_demux",
    "AXI-021": "axi_mux", "AXI-022": "axi_crossbar",
    "AXI-023": "axi_default_slave", "AXI-024": "axi_timeout_monitor",
    "AXI-025": "axi_firewall_region_filter", "AXI-026": "axi_exclusive_access_monitor",
    "AXI-027": "axi_atomic_adapter", "AXI-028": "axi_qos_mapper",
    "AXI-029": "axi_perf_monitor", "AXI-030": "axi_error_injector",
    "AXIS-001": "axis_register_slice", "AXIS-002": "axis_width_converter",
    "AXIS-003": "axis_switch", "AXIS-004": "axis_packet_fifo",
    "AXIS-005": "axis_broadcaster", "AXIS-006": "axis_combiner_subset",
    "AXIS-007": "axis_frame_length_monitor", "AXIS-008": "axis_rate_limiter",
    # ---- NoC、片间与高级互联公共构件（NOC）----
    "NOC-001": "flit_packer_unpacker", "NOC-002": "vc_fifo",
    "NOC-003": "vc_allocator", "NOC-004": "switch_allocator",
    "NOC-005": "noc_input_port", "NOC-006": "noc_output_port",
    "NOC-007": "crossbar_fabric", "NOC-008": "route_compute",
    "NOC-009": "credit_return_channel", "NOC-010": "link_register_slice",
    "NOC-011": "link_cdc_adapter", "NOC-012": "link_width_converter",
    "NOC-013": "link_crc_replay_shell", "NOC-014": "link_power_state_handshake",
    "NOC-015": "deadlock_progress_monitor", "NOC-016": "chi_ace_channel_slice",
    "NOC-017": "chiplet_streaming_adapter",
    # ---- 监控、调试、性能与可观测性（MON）----
    "MON-001": "event_counter", "MON-002": "multi_event_counter_bank",
    "MON-003": "cycle_busy_idle_counter", "MON-004": "latency_monitor",
    "MON-005": "bandwidth_monitor", "MON-006": "occupancy_monitor",
    "MON-007": "stall_backpressure_monitor", "MON-008": "activity_toggle_sampler",
    "MON-009": "trace_event_encoder", "MON-010": "trace_fifo",
    "MON-011": "trace_funnel", "MON-012": "trigger_qualifier",
    "MON-013": "snapshot_register_bank", "MON-014": "protocol_progress_monitor",
    "MON-015": "perf_counter_csr_adapter", "MON-016": "lightweight_logic_analyzer",
    # ---- DFT、测试与可制造性辅助（DFT）----
    "DFT-001": "test_mode_synchronizer", "DFT-002": "scan_enable_distribution",
    "DFT-003": "clock_ctrl_test_override", "DFT-004": "reset_ctrl_test_override",
    "DFT-005": "mbist_port_arbiter", "DFT-006": "lbist_misr",
    "DFT-007": "prpg", "DFT-008": "signature_comparator",
    "DFT-009": "test_access_mux", "DFT-010": "memory_repair_data_adapter",
    # ---- DSP、图像与 AI 数据搬运公共构件（DSP）----
    "DSP-001": "lane_packer_unpacker", "DSP-002": "vector_reduction",
    "DSP-003": "dot_product_tree", "DSP-004": "sliding_window_generator",
    "DSP-005": "tensor_layout_converter", "DSP-006": "tile_address_generator",
    "DSP-007": "stride_dilation_addr_gen", "DSP-008": "scatter_gather_index_gen",
    "DSP-009": "dma_descriptor_walker", "DSP-010": "quantization_pipeline",
    "DSP-011": "activation_approx", "DSP-012": "sparse_bitmap_index_decoder",
    "DSP-013": "accumulator_bank", "DSP-014": "double_buffer_ctrl",
    "DSP-015": "loop_nested_counter_gen",
    # ---- 子系统模板与参考架构配方（TMP，A4）----
    "TMP-001": "multi_bank_sram_subsystem", "TMP-002": "low_latency_rf_subsystem",
    "TMP-003": "shared_operator_template", "TMP-004": "high_throughput_add_mac_tree",
    "TMP-005": "high_freq_ready_valid_channel", "TMP-006": "long_distance_physical_link",
    "TMP-007": "hierarchical_arbitration_network", "TMP-008": "hierarchical_decode_network",
    "TMP-009": "axi_shared_interconnect_template", "TMP-010": "axi_async_bridge_template",
    "TMP-011": "axi_width_bridge_template", "TMP-012": "apb_peripheral_cluster_template",
    "TMP-013": "noc_router_template", "TMP-014": "safe_interrupt_frontend_template",
    "TMP-015": "error_management_tree_template", "TMP-016": "power_domain_ctrl_template",
    "TMP-017": "clock_reset_manager_template", "TMP-018": "low_power_pipeline_template",
    "TMP-019": "high_fanout_ctrl_recipe", "TMP-020": "streaming_data_shaping_template",
    "TMP-021": "e2e_data_protection_channel", "TMP-022": "perf_observation_subsystem",
    "TMP-023": "memory_bist_access_template", "TMP-024": "dsp_double_buffer_datapath",
}

ID_RE = re.compile(r"^[A-Z]+-\d+$")


def folder_name(cid):
    """优先使用功能名映射；缺失时回退为 ID 小写下划线。"""
    return CBB_NAMES.get(cid, cid.lower().replace("-", "_"))


def parse():
    """解析清单，返回 {section: [row]}，row 为 dict。"""
    result = {}
    current = None
    with open(LIST_PATH, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^##\s+(\d+)\.", line.strip())
            if m:
                current = int(m.group(1))
                result.setdefault(current, [])
                continue
            if current is None or current not in SECTIONS:
                continue
            stripped = line.strip()
            if not stripped.startswith("|"):
                continue
            cells = [c.strip() for c in stripped.strip("|").split("|")]
            if not cells or not ID_RE.match(cells[0]):
                continue
            row = {"id": cells[0], "name": cells[1] if len(cells) > 1 else ""}
            row["impl"] = cells[2] if len(cells) > 2 else ""
            if current == 2:
                row["level"] = "A0"
                row["priority"] = cells[3] if len(cells) > 3 else ""
                row["ppa"] = cells[4] if len(cells) > 4 else ""
            else:
                row["level"] = cells[3] if len(cells) > 3 else ""
                row["priority"] = cells[4] if len(cells) > 4 else ""
                row["ppa"] = cells[5] if len(cells) > 5 else ""
            result[current].append(row)
    return result


def rel_to_root(path):
    depth = len(path.split("/"))
    return "../" * depth


def write_cbb_readme(cbb_dir, row, group_label, rel):
    content = """# {id} {name}

> 分组：{group}（{level}）　优先级：{priority}
> 状态：规划中（空工程包，仅需求说明）

## 需求说明

- 构件族：{name}
- 主要实现变体：{impl}
- PPA 关注点：{ppa}

### 功能契约
（待补充：接口、时钟域、顺序 / 背压 / 异常行为）

### 成熟度
- [ ] E0 Concept
- [ ] E1 Functional
- [ ] E2 Verified
- [ ] E3 Characterized
- [ ] E4 Released

### PPA 表征计划
（待补充：基准环境、参数扫描计划）

> 开发时按 [docs/cbb_spec]({rel}docs/cbb_spec/README.md) 展开标准工程包（rtl/interface、rtl/impl、verification、characterization 等）。
""".format(
        id=row["id"], name=row["name"], group=group_label,
        level=row["level"], priority=row["priority"],
        impl=row["impl"] or "（待补充）", ppa=row["ppa"] or "（待补充）",
        rel=rel,
    )
    with open(os.path.join(cbb_dir, "README.md"), "w", encoding="utf-8") as f:
        f.write(content)


CBB_VERSION = "0.1.0"


def write_fusesoc_core(cbb_dir, name, row):
    """为每个 CBB 生成 fusesoc/aixsilicon_cbb_<name>.core（CAPI=2，占位实现）。"""
    core = """CAPI=2:

name: aixsilicon:cbb:{name}:{ver}
description: |
  {id} {cbb_name} - {ppa}

filesets:
  rtl_interface:
    files:
      - ../rtl/interface/*.sv
    file_type: systemVerilogSource
  rtl_impl:
    files:
      - ../rtl/impl/*.sv
    file_type: systemVerilogSource
  sim_tb:
    files:
      - ../verification/simulation/*.sv
    file_type: systemVerilogSource

targets:
  rtl:
    filesets: [rtl_interface, rtl_impl]
  synth:
    filesets: [rtl_interface, rtl_impl]
  sim:
    filesets: [rtl_interface, rtl_impl, sim_tb]
  default:
    filesets: [rtl_interface, rtl_impl]
""".format(name=name, ver=CBB_VERSION, id=row["id"], cbb_name=row["name"],
           ppa=row["ppa"] or "PPA 待表征")
    os.makedirs(os.path.join(cbb_dir, "fusesoc"), exist_ok=True)
    path = os.path.join(cbb_dir, "fusesoc", "aixsilicon_cbb_%s.core" % name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(core)


def write_ip_package(cbb_dir, name, row, category_path):
    """为每个 CBB 生成 ip-package.yaml（iprepo-management-suite 统一仓规范）。"""
    pkg = """schema_version: "2.0"
name: {name}
version: "{ver}"
vendor: aixsilicon
library: cbb
description: |
  {id} {cbb_name} - {ppa}
license: internal
path: {path}
maturity: E0
classification:
  abstraction: {level}
  priority: {priority}
quality:
  gates:
    G0: pass
    G1: unknown
    G2: unknown
    G3: unknown
    G4: unknown
    G5: unknown
fusesoc:
  core: aixsilicon:cbb:{name}:{ver}
""".format(name=name, ver=CBB_VERSION, id=row["id"], cbb_name=row["name"],
           ppa=row["ppa"] or "PPA 待表征", path=category_path + "/" + name,
           level=row["level"], priority=row["priority"])
    with open(os.path.join(cbb_dir, "ip-package.yaml"), "w", encoding="utf-8") as f:
        f.write(pkg)


def build():
    sections = parse()

    for top in ("adapters", "components", "templates"):
        base = os.path.join(ROOT, top)
        os.makedirs(base, exist_ok=True)
        for entry in os.listdir(base):
            p = os.path.join(base, entry)
            if os.path.isdir(p):
                shutil.rmtree(p)

    registry = []
    total = 0
    missing = []

    for sec in sorted(SECTIONS.keys()):
        top, cat, title = SECTIONS[sec]
        rows = sections.get(sec, [])
        if not rows:
            continue

        if cat is None:
            group_dir = os.path.join(ROOT, top)
            group_label = title
            category_path = top
        else:
            group_dir = os.path.join(ROOT, top, cat)
            group_label = "{cat}（{title}）".format(cat=cat, title=title)
            category_path = "{top}/{cat}".format(top=top, cat=cat)

        os.makedirs(group_dir, exist_ok=True)

        lines = ["# {cat} — {title}".format(cat=cat or top, title=title), ""]
        lines.append("对应 cbb_repo_list.md 第 {sec} 节。".format(sec=sec))
        lines.append("")
        lines.append("| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |")
        lines.append("| --- | --- | --- | --- | --- |")
        for row in rows:
            lines.append("| {id} | {name} | {level} | {priority} | {ppa} |".format(
                id=row["id"], name=row["name"], level=row["level"],
                priority=row["priority"], ppa=row["ppa"]))
        lines.append("")
        lines.append("> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。")
        with open(os.path.join(group_dir, "README.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

        for row in rows:
            name = folder_name(row["id"])
            if name == row["id"].lower().replace("-", "_"):
                missing.append(row["id"])
            cbb_dir = os.path.join(group_dir, name)
            os.makedirs(cbb_dir, exist_ok=True)
            rel = rel_to_root(category_path + "/" + name)
            write_cbb_readme(cbb_dir, row, group_label, rel)
            write_fusesoc_core(cbb_dir, name, row)
            write_ip_package(cbb_dir, name, row, category_path)
            registry.append({
                "id": row["id"],
                "name": name,
                "group": category_path,
                "abstraction": row["level"],
                "priority": row["priority"],
                "status": "planned",
                "version": CBB_VERSION,
                "path": category_path + "/" + name,
            })
            total += 1

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    reg = []
    reg.append('schema_version: "2.0"')
    reg.append('updated: "%s"' % ts)
    reg.append("vendor: aixsilicon")
    reg.append("library: cbb")
    reg.append('unified_repo: ""')
    reg.append("")
    reg.append("cbbs:")
    for e in registry:
        reg.append("  - id: %s" % e["id"])
        reg.append("    name: %s" % e["name"])
        reg.append("    group: %s" % e["group"])
        reg.append("    abstraction: %s" % e["abstraction"])
        reg.append("    priority: %s" % e["priority"])
        reg.append("    status: %s" % e["status"])
        reg.append("    version: \"%s\"" % e["version"])
        reg.append("    path: %s" % e["path"])
    with open(os.path.join(ROOT, "registry.yaml"), "w", encoding="utf-8") as f:
        f.write("\n".join(reg) + "\n")

    print("==> 生成完成：共 %d 个 CBB（registry.yaml 已更新）" % total)
    if missing:
        print("==> 警告：以下 ID 未配置功能名（使用 ID 回退）：%s" % ", ".join(missing))


if __name__ == "__main__":
    build()
