# HAC-SHELL-001 HAC Shell 模板

> 分组：模板（A4）　优先级：P1
> 状态：规划中（空工程包，仅模块划分）

## 模块划分

```text
hac_shell/
├── hac_csr                  # AXI4-Lite/CSR 与软件可见状态
├── hac_cmd_queue            # 命令接收与排队
├── hac_desc_fetch           # Descriptor 获取和校验
├── hac_ap_ctrl_adapter      # ap_ctrl_hs/chain 兼容
├── hac_mem_frontend         # HAC-MEM 接收与限流
├── hac_axi_read_engine      # AXI 读引擎
├── hac_axi_write_engine     # AXI 写引擎
├── hac_burst_splitter       # 4KB/长度/对齐处理
├── hac_tag_tracker          # Tag、ID 及完成关联
├── hac_stream_adapter       # HAC-STREAM/AXIS 适配
├── hac_lmem_adapter         # SRAM/Bank/ECC 适配
├── hac_event_router         # 事件聚合和路由
├── hac_irq_ctrl             # IRQ/MSI 控制
├── hac_error_monitor        # 超时和错误记录
├── hac_perf_monitor         # 性能计数
├── hac_clock_power_ctrl     # 时钟、电源、排空
└── hac_cdc_bridge           # 可选跨时钟
```

## Shell 分层

| 层次 | 内容 | 复用范围 |
|---|---|---|
| L0 Protocol | Interface、typedef、编码、SVA | 全部 HAC |
| L1 Primitive | FIFO、Skid Buffer、Tag Pool、CDC | CBB 公共库 |
| L2 Adapter | AP/AXI/AXIS/SRAM Adapter | 多 HAC 复用 |
| L3 Shell | CSR、Queue、Event、Power 组合 | 按 Profile 配置 |
| L4 Product Wrapper | 算法参数、Descriptor、专用寄存器 | 单个 IP |

## 成熟度

- [ ] E0 Concept
- [ ] E1 Functional
- [ ] E2 Verified
- [ ] E3 Characterized
- [ ] E4 Released

> 开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
