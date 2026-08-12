# components — A1~A3 构件

通用构件主体（A0 技术适配见 [`adapters/`](../adapters/README.md:1)，A4 子系统模板见 [`templates/`](../templates/README.md:1)）。

## 组织方式

按 **cbb_repo_list.md 的功能类别**组织子目录（第 3~19 节，共 17 个类别、364 个 CBB）；
**抽象层级（A1~A3）与优先级（P0~P3）是 `cbb.yaml`/`registry.yaml` 中的标签**，不是目录层级。

每个 CBB 目录以**功能名**命名（如 `fifo_queue_buffer/sync_fifo`），内含 README 需求说明占位；清单 ID 保留在元数据与 README 标题中。
完整清单见 [`cbb_repo_list.md`](../cbb_repo_list.md:1)。

## 类别一览

| 类别目录 | 章节 | 内容 | 数量 |
| --- | --- | --- | --- |
| [`selection_decode/`](selection_decode/README.md:1) | §3 | 基础位操作、编码与选择网络 | 20 |
| [`arithmetic_datapath/`](arithmetic_datapath/README.md:1) | §4 | 算术与数值数据通路 | 35 |
| [`coding_integrity/`](coding_integrity/README.md:1) | §5 | CRC、编码、压缩与数据完整性算法 | 12 |
| [`register_memory/`](register_memory/README.md:1) | §6 | 寄存器、存储器与存储映射 | 25 |
| [`fifo_queue_buffer/`](fifo_queue_buffer/README.md:1) | §7 | FIFO、Queue 与 Buffer | 20 |
| [`streaming_pipeline/`](streaming_pipeline/README.md:1) | §8 | 流水、Ready/Valid 与流处理 | 25 |
| [`arbitration_scheduling/`](arbitration_scheduling/README.md:1) | §9 | 仲裁、调度、共享与流控 | 20 |
| [`cdc_rdc/`](cdc_rdc/README.md:1) | §10 | CDC、RDC 与多时钟域 | 19 |
| [`clock_reset_power/`](clock_reset_power/README.md:1) | §11 | 时钟、复位、功耗与高扇出优化 | 22 |
| [`control_event_status/`](control_event_status/README.md:1) | §12 | 控制、计数、事件与状态管理 | 24 |
| [`interrupt_safety/`](interrupt_safety/README.md:1) | §13 | 中断、错误与功能安全公共构件 | 30 |
| [`apb_ahb_register/`](apb_ahb_register/README.md:1) | §14 | APB/AHB/寄存器接口构件 | 16 |
| [`axi_axi_stream/`](axi_axi_stream/README.md:1) | §15 | AXI4/AXI4-Lite/AXI-Stream 构件 | 38 |
| [`noc_interconnect/`](noc_interconnect/README.md:1) | §16 | NoC、片间与高级互联公共构件 | 17 |
| [`monitor_debug/`](monitor_debug/README.md:1) | §17 | 监控、调试、性能与可观测性 | 16 |
| [`dft_test/`](dft_test/README.md:1) | §18 | DFT、测试与可制造性辅助 | 10 |
| [`dsp_ai_datapath/`](dsp_ai_datapath/README.md:1) | §19 | DSP、图像与 AI 数据搬运公共构件 | 15 |

## 进入正式 Catalog 的条件（cbb_repo_list.md §2.2 / plan.md 2.2）

功能语义通用、接口契约清晰、有独立验证入口、有综合语义与约束、有版本/维护人/依赖声明；
PPA 型 CBB 至少完成一个基准工艺/库上的表征。
