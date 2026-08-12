# 面向 PPA 优化的 CBB 构件完整清单

> 版本：V1.0  
> 适用范围：通用数字 IP、SoC 集成、DSP/AI 数据通路及功能安全公共逻辑  
> 建库口径：表中一行代表一个具有统一功能契约的“构件族”；不同微架构作为实现变体，不重复虚增构件数量。

## 1. 清单使用说明

### 1.1 抽象级别

| 级别 | 定义 |
|---|---|
| A0 | 工艺、Macro、标准单元或目标平台适配构件 |
| A1 | 功能单一、接口简单的原子机制构件 |
| A2 | 协议无关、可独立复用的通用复合构件 |
| A3 | 带 Ready/Valid、AXI、AHB、APB、CHI、NoC 等协议语义的构件 |
| A4 | 由多个构件组成、可配置生成的子系统模板；应与普通 CBB 分区治理 |


### 1.3 统一变体原则

- `AREA/PERFORMANCE/LOW_POWER` 是优化目标，不作为实现名称；实现必须按真实微架构命名。
- 同一构件族共享功能契约、参考模型和一致性测试，不同实现分别表征。
- CDC/RDC、ICG、Isolation、Retention、Clock Mux 等采用白名单实现，AI 只能选型和参数化。
- A4 模板若出现大量软件可见寄存器、复杂业务状态或独立路线，应升级为 IP 产品。

---

## 2. A0 工艺与物理实现适配

| ID | 构件族 | 主要实现/配置 | 优先级 | PPA与工程关注点 |
|---|---|---|---|---|
| TEC-001 | 通用组合标准单元 Wrapper | AND/OR/XOR/MUX/AOI/OAI 映射 | P2 | 保持可移植 RTL 与定向映射双路径 |
| TEC-002 | DFF Wrapper | 普通、Enable、Set/Reset、Scan | P1 | 面积、时钟功耗、DFT约束 |
| TEC-003 | Multi-bit FF Wrapper | 2/4/8-bit MBFF | P2 | 时钟功耗与布局可实现性 |
| TEC-004 | Latch Wrapper | 普通、门控、Scan | P3 | 时序借用与验证边界 |
| TEC-005 | ICG Wrapper | 不同使能/测试使能接口 | P0 | 时钟功耗、门控检查、DFT |
| TEC-006 | Glitch-free Clock Mux Wrapper | 2/4 路时钟选择 | P0 | 无毛刺、切换延迟、CTS |
| TEC-007 | Clock Divider Cell Wrapper | 2/N 分频、旁路 | P1 | 占空比、generated clock |
| TEC-008 | Clock Buffer/Delay Wrapper | Buffer tree、delay cell | P3 | 仅供受控物理实现使用 |
| TEC-009 | Level Shifter Wrapper | Up/Down、Enable LS | P1 | 电压域、方向、隔离组合 |
| TEC-010 | Isolation Cell Wrapper | Clamp-0/1、Latch isolation | P1 | 控制极性、位置、UPF一致性 |
| TEC-011 | Retention FF/Bank Wrapper | Save/restore、always-on | P2 | 状态范围、唤醒延迟、面积 |
| TEC-012 | Power Switch Control Wrapper | Header/footer 控制接口 | P3 | 物理专用，不承载电源网实现 |
| TEC-013 | Tie/Constant Cell Wrapper | Tie-high/low | P2 | 避免逻辑常量不规范直连 |
| TEC-014 | Scan/Lockup Wrapper | Lockup latch、scan bypass | P3 | DFT链与跨时钟域 |
| TEC-015 | SRAM Macro Wrapper | 1P、SP、1R1W、TDP | P0 | 统一读延迟、mask、sleep、BIST |
| TEC-016 | Register File Macro Wrapper | 多读写端口、同步/异步读 | P1 | 端口语义与 bypass |
| TEC-017 | ROM Macro Wrapper | Mask ROM、compiler ROM | P2 | 初始化、时序和测试接口 |
| TEC-018 | CAM/TCAM Macro Wrapper | Binary/ternary、分段 | P3 | 高功耗宏，严格适用范围 |
| TEC-019 | eFuse/OTP Macro Wrapper | Read/program/test 抽象接口 | P3 | 安全、一次性编程、厂商差异 |
| TEC-020 | PLL/DLL/OSC Digital Wrapper | 配置、锁定、旁路、状态同步 | P3 | 仅数字接口适配，不替代模拟IP |
| TEC-021 | FPGA Memory Wrapper | BRAM/URAM/LUTRAM | P1 | ASIC/FPGA双实现映射 |
| TEC-022 | FPGA DSP Wrapper | DSP slice、MAC、pre-adder | P2 | 推断稳定性与流水位置 |

---

## 3. 基础位操作、编码与选择网络

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| SEL-001 | 2:1/N:1 Binary Mux | Linear、balanced tree、pipelined | A1 | P0 | 扇入、逻辑深度、毛刺 |
| SEL-002 | One-hot Mux | OR-tree、AND-OR、segmented | A1 | P0 | One-hot假设、扇出、X处理 |
| SEL-003 | Priority Mux | Linear、tree、grouped | A1 | P1 | 优先级链与规模扩展 |
| SEL-004 | Sparse/Masked Mux | sparse map、mask select | A1 | P2 | 无效输入消除、综合稳定性 |
| SEL-005 | Cross-point Switch | full、sparse、staged | A2 | P2 | 交叉规模、布线与流水 |
| SEL-006 | Binary Encoder | combinational、tree | A1 | P0 | 位宽与深度 |
| SEL-007 | One-hot Encoder | strict、first-hot、last-hot | A1 | P0 | 非法输入语义 |
| SEL-008 | Decoder | binary-to-onehot、segmented | A1 | P0 | 高扇出、本地译码 |
| SEL-009 | Priority Encoder | leading/trailing、tree | A1 | P0 | 深优先级链 |
| SEL-010 | Thermometer Encoder/Decoder | binary/thermometer conversion | A1 | P3 | 编码密度与毛刺 |
| SEL-011 | Leading Zero/One Count | tree、segmented、pipelined | A1 | P1 | 关键路径、前缀结构 |
| SEL-012 | Trailing Zero/One Count | reverse、tree | A1 | P2 | 共享反转逻辑 |
| SEL-013 | Bit Scan/First-set | LSB/MSB、priority tree | A1 | P1 | 大位宽时序 |
| SEL-014 | Population Count | adder tree、compressor、lookup | A1 | P1 | 面积/时序Pareto |
| SEL-015 | One-hot Checker | zero/one/multi-hot detect | A1 | P0 | 安全检查复用 |
| SEL-016 | Range Comparator | single/multi-range、tree | A1 | P1 | 共享比较与译码 |
| SEL-017 | Address Decoder | range、mask、base+size | A2 | P0 | 比较器共享、扇出 |
| SEL-018 | Hierarchical Address Decoder | cluster/local decode | A2 | P1 | 大规模地址空间时序 |
| SEL-019 | Configurable Truth Table | LUT/case/ROM mapped | A1 | P3 | 面积与综合推断 |
| SEL-020 | Bit Permutation Network | fixed、programmable、Benes | A2 | P3 | 布线主导、配置代价 |

---

## 4. 算术与数值数据通路

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| ARI-001 | Incrementer/Decrementer | ripple、segmented | A1 | P0 | Counter专用优化 |
| ARI-002 | Adder/Subtractor | ripple、CLA、prefix、segmented | A1 | P0 | 位宽、进位结构、流水 |
| ARI-003 | Carry-save Adder | 3:2、4:2 compressor | A1 | P1 | 多操作数压缩 |
| ARI-004 | Multi-operand Adder | linear、balanced、CSA tree | A2 | P1 | 操作数数量与树平衡 |
| ARI-005 | Adder Tree | balanced、registered、saturating | A2 | P1 | 流水级与吞吐 |
| ARI-006 | Accumulator | wrap、saturate、clear/load | A2 | P0 | 反馈路径与门控 |
| ARI-007 | Absolute Value/Negate | signed、saturating | A1 | P1 | 最小负数语义 |
| ARI-008 | Comparator | signed/unsigned、segmented | A1 | P0 | Early-out与关键路径 |
| ARI-009 | Multi-way Min/Max | linear、balanced、pipelined | A2 | P1 | 路数、索引回传 |
| ARI-010 | Clamp/Clip | symmetric/asymmetric limits | A1 | P1 | 比较共享与常量特化 |
| ARI-011 | Saturating Add/Sub | signed/unsigned | A1 | P1 | 溢出判定与延迟 |
| ARI-012 | Fixed-point Round | truncate、RNE、RNA、stochastic | A1 | P1 | 精度、偏差、随机源 |
| ARI-013 | Fixed-point Resize | extend、round、saturate | A1 | P0 | 位宽最小化 |
| ARI-014 | Scale/Shift | power-of-two、programmable | A1 | P1 | 常量传播与复用 |
| ARI-015 | Logical/Arithmetic Shifter | staged、barrel、iterative | A1/A2 | P1 | 面积、周期数、路由 |
| ARI-016 | Rotator/Funnel Shifter | barrel、staged | A2 | P2 | 双输入拼接与布线 |
| ARI-017 | Integer Multiplier | array、Booth、Wallace/Dadda | A2 | P1 | 位宽、符号、流水 |
| ARI-018 | Constant Multiplier | shift-add、CSD、MCM | A2 | P1 | 常量特化与共享 |
| ARI-019 | Multiply-Accumulate | fused、separate、pipelined | A2 | P1 | 融合、截断、吞吐 |
| ARI-020 | Dot-product Engine | parallel、time-mux、tree | A2 | P2 | 并行度、累加宽度 |
| ARI-021 | Integer Divider | restoring、non-restoring、SRT | A2 | P2 | 面积/延迟/吞吐 |
| ARI-022 | Constant Divider | reciprocal multiply、shift-add | A2 | P2 | 误差与常量特化 |
| ARI-023 | Modulo/Reducer | arbitrary、power-of-two、Barrett | A2 | P3 | 除法消除与延迟 |
| ARI-024 | Square/Sum-of-squares | dedicated、shared multiplier | A2 | P3 | DSP场景资源共享 |
| ARI-025 | Average/Weighted Sum | shift、reciprocal、MAC | A2 | P2 | 系数与位宽增长 |
| ARI-026 | Reciprocal/RSqrt Approximation | LUT+iteration、piecewise | A2 | P3 | 精度/延迟/面积 |
| ARI-027 | CORDIC | iterative、unrolled、pipelined | A2 | P3 | 迭代次数、精度 |
| ARI-028 | Polynomial Evaluator | Horner、parallel tree | A2 | P3 | 系数常量化与MAC复用 |
| ARI-029 | BCD/Binary Converter | iterative、double-dabble | A2 | P3 | 周期与面积 |
| ARI-030 | Decimal/BCD Arithmetic | add/adjust/compare | A2 | P3 | 专用业务驱动 |
| ARI-031 | FP Classify/Compare | IEEE754 subsets | A1/A2 | P3 | NaN/Inf/zero语义 |
| ARI-032 | FP Add/Multiply/FMA Shell | vendor/core wrapper、config | A2 | P3 | 不重复造完整FPU，重在适配 |
| ARI-033 | Block Floating-point Scale | shared exponent、normalize | A2 | P3 | 精度与存储带宽 |
| ARI-034 | Quantize/Dequantize | affine、symmetric、per-channel | A2 | P2 | AI数据通路位宽与功耗 |
| ARI-035 | Packed SIMD Lane Operator | add/mul/min/max、lane mask | A2 | P3 | Lane复用与门控 |

---

## 5. CRC、编码、压缩与数据完整性算法

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| COD-001 | Parity Generator/Checker | even/odd、tree、pipelined | A1 | P0 | XOR树平衡 |
| COD-002 | CRC Generator/Checker | serial、parallel、sliced | A2 | P1 | 多项式、数据宽度、吞吐 |
| COD-003 | SECDED ECC | encode/decode/correct、pipelined | A2 | P0 | 校验位、纠错延迟 |
| COD-004 | Configurable Hamming ECC | shortened、extended | A2 | P1 | 参数合法域 |
| COD-005 | BCH/RS Codec Wrapper | iterative/vendor-wrapper | A2 | P3 | 算法复杂度与授权边界 |
| COD-006 | Gray/Binary Converter | combinational、pipelined | A1 | P0 | CDC计数器复用 |
| COD-007 | Scrambler/Descrambler | self-synchronous、LFSR | A2 | P2 | 并行展开与吞吐 |
| COD-008 | LFSR/PRBS | Fibonacci、Galois、parallel | A1/A2 | P1 | 多项式与切换功耗 |
| COD-009 | Run-length Encoder/Decoder | streaming、bounded run | A2 | P3 | 数据相关吞吐 |
| COD-010 | Zero Suppression/Bitmap Codec | sparse、block mask | A2 | P3 | 元数据开销与活动率 |
| COD-011 | Byte/Bit Order Converter | endian swap、bit reverse | A1 | P0 | 固定连线优先 |
| COD-012 | Data Packer/Unpacker | field map、aligned/unaligned | A2 | P1 | Mux规模与时序 |

---

## 6. 寄存器、存储器与存储映射

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| MEM-001 | Parameter Register | plain、enable、masked write | A1 | P0 | Enable推断与时钟功耗 |
| MEM-002 | Shadowed Register | dual-copy、commit | A2 | P1 | 安全一致性与面积 |
| MEM-003 | Sticky/W1C/W1S Register | status semantics variants | A1/A2 | P0 | 软件语义与门数 |
| MEM-004 | Register Array | async/sync read、byte mask | A2 | P0 | 推断RAM或FF阵列 |
| MEM-005 | 1R1W Register File | flop、macro、replicated | A2 | P1 | 读延迟、RAW bypass |
| MEM-006 | Multi-read Register File | replicated、banked、muxed | A2 | P1 | 面积与端口冲突 |
| MEM-007 | Multi-write Register File | arbitration、banked | A2 | P2 | 写冲突与旁路 |
| MEM-008 | SRAM Width Composer | concat、byte-lane banking | A2 | P0 | Macro利用率与mask |
| MEM-009 | SRAM Depth Composer | cascaded decode、bank select | A2 | P0 | 译码/输出Mux关键路径 |
| MEM-010 | SRAM Bank Mapper | interleave、hash、range | A2 | P1 | 冲突率、地址逻辑 |
| MEM-011 | SRAM Port Adapter | 1R1W↔SP/TDP语义适配 | A2 | P1 | 冲突语义与吞吐 |
| MEM-012 | Memory RAW Bypass | write-first/read-first/no-change | A2 | P0 | 数据一致性与Mux延迟 |
| MEM-013 | Memory Byte-write Adapter | RMW、native mask | A2 | P1 | RMW周期与功耗 |
| MEM-014 | Memory Init/Load Adapter | ROM/file/bus initialization | A2 | P2 | 仿真与综合一致性 |
| MEM-015 | Memory Sleep/Retention Controller | idle-based、software-driven | A2 | P2 | break-even时间、唤醒 |
| MEM-016 | Memory ECC Shell | sidecar/in-line、scrub | A2 | P1 | 延迟、容量、可靠性 |
| MEM-017 | Memory Scrubber | periodic、on-demand、priority | A2 | P2 | 带宽占用、功耗 |
| MEM-018 | Memory BIST Interface Adapter | march controller interface | A2 | P2 | DFT接口与功能隔离 |
| MEM-019 | Multi-bank Access Scheduler | fixed/RR/conflict-aware | A2 | P2 | Bank冲突与吞吐 |
| MEM-020 | Ping-pong Buffer | dual-bank、N-bank rotation | A2 | P1 | 读写重叠与容量 |
| MEM-021 | Line Buffer | shift/SRAM/circular | A2 | P2 | 图像/卷积带宽 |
| MEM-022 | Circular Buffer | pointer/wrap、power-of-two | A2 | P1 | 地址简化与满空判定 |
| MEM-023 | Lookup Table/ROM | case、distributed、macro | A1/A2 | P1 | 深宽映射与推断 |
| MEM-024 | CAM | register-based、banked | A2 | P3 | 并行比较功耗 |
| MEM-025 | Content Tag Array | tag+valid+compare | A2 | P3 | Cache/TLB公共结构 |

---

## 7. FIFO、Queue 与 Buffer

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| QUE-001 | Synchronous FIFO | register、shift、SRAM | A2 | P0 | 深宽自动映射 |
| QUE-002 | Asynchronous FIFO | Gray pointer、bundled reset | A2 | P0 | CDC正确性、深度限制 |
| QUE-003 | Fall-through FIFO | combinational head、registered | A2 | P0 | 首拍延迟与Ready路径 |
| QUE-004 | Shift-register FIFO | shift-all、tap pointer | A2 | P1 | 小深度面积与翻转 |
| QUE-005 | SRAM FIFO | single/dual-port、prefetch | A2 | P1 | 读延迟隐藏 |
| QUE-006 | Elastic Buffer | 1/2-entry、bubble-free | A2 | P0 | 满吞吐与反压 |
| QUE-007 | Skid Buffer | output/input registered | A3 | P0 | 切断Ready组合链 |
| QUE-008 | Pipeline FIFO | distributed entries | A2/A3 | P1 | 物理距离与吞吐 |
| QUE-009 | Packet FIFO | packet commit/drop | A2 | P2 | 包边界和回滚 |
| QUE-010 | Frame Buffer Queue | descriptor+payload | A2 | P3 | 容量与元数据 |
| QUE-011 | Credit FIFO | credit-aware enqueue/dequeue | A2/A3 | P1 | Credit一致性 |
| QUE-012 | Width-conversion FIFO | narrow↔wide、gearbox | A2/A3 | P1 | 存储利用率与Mux |
| QUE-013 | Multi-channel FIFO | shared RAM、per-channel pointers | A2 | P2 | RAM共享与仲裁 |
| QUE-014 | Multi-enqueue FIFO | 2/N push、compaction | A2 | P2 | 写合并与指针更新 |
| QUE-015 | Multi-dequeue FIFO | 2/N pop、lookahead | A2 | P2 | 读端口与输出Mux |
| QUE-016 | Reorder Queue | tag/index、CAM/window | A2 | P3 | 存储与比较功耗 |
| QUE-017 | Priority Queue | heap、bucket、sorted array | A2 | P3 | 延迟与容量 |
| QUE-018 | Descriptor Queue | linked/ring/indexed | A2 | P2 | 控制开销与访存 |
| QUE-019 | Replay/Retry Buffer | checkpoint、selective replay | A2 | P3 | 状态容量和恢复延迟 |
| QUE-020 | Broadcast/Replication Buffer | reference count、copy | A2/A3 | P2 | 数据复制与背压 |

---

## 8. 流水、Ready/Valid 与流处理

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| STR-001 | Fixed Delay Line | FF、SRL、RAM-based | A1/A2 | P0 | 延迟、面积、初始化 |
| STR-002 | Enable Delay Line | clock-enable/data-gated | A1/A2 | P1 | 空闲功耗 |
| STR-003 | Data/Control Aligner | fixed/programmable latency | A2 | P0 | 控制数据一致性 |
| STR-004 | Forward Register Slice | payload registered | A3 | P0 | 数据关键路径 |
| STR-005 | Backward Register Slice | ready registered | A3 | P0 | 反压关键路径 |
| STR-006 | Full Register Slice | skid/full throughput | A3 | P0 | 双向切时序 |
| STR-007 | Bypassable Register Slice | static/dynamic bypass | A3 | P1 | 模式Mux与验证 |
| STR-008 | Stream Mux | binary/one-hot/arbitrated | A3 | P0 | 选择与反压 |
| STR-009 | Stream Demux | decoded/multicast | A3 | P0 | 输出Ready聚合 |
| STR-010 | Stream Fork | all-ready、independent buffer | A3 | P1 | 复制和阻塞语义 |
| STR-011 | Stream Join | lockstep、tagged join | A3 | P1 | 同步等待与Buffer |
| STR-012 | Stream Merge | priority/RR/interleaved | A3 | P1 | 仲裁与包锁定 |
| STR-013 | Stream Split | field/length/packet based | A3 | P2 | 状态与边界 |
| STR-014 | Stream Width Converter | integer/non-integer ratio | A3 | P1 | Gearbox与跨拍状态 |
| STR-015 | Stream Gearbox | bit/byte lane gearbox | A3 | P2 | 相位、吞吐、布线 |
| STR-016 | Stream Rate Matcher | throttle/replicate/drop | A3 | P2 | 速率与Buffer深度 |
| STR-017 | Stream Packetizer | header/trailer insert | A3 | P2 | 包头Mux与CRC衔接 |
| STR-018 | Stream Depacketizer | parse/strip/metadata extract | A3 | P2 | 解析关键路径 |
| STR-019 | Stream Arbiter | transfer/packet locked | A3 | P1 | 公平性和切换气泡 |
| STR-020 | Stream Multicast | all/subset destinations | A3 | P2 | Ready汇聚与复制 |
| STR-021 | Stream Broadcaster | registered/distributed | A3 | P1 | 高扇出与物理距离 |
| STR-022 | Stream Throttler | fixed/token-bucket | A3 | P2 | 控制翻转和精度 |
| STR-023 | Stream Traffic Shaper | token/leaky bucket | A3 | P3 | 速率状态和突发 |
| STR-024 | Stream Monitor Tap | passive/filtered/sampled | A3 | P2 | 零干扰与观测开销 |
| STR-025 | Bubble Inserter/Remover | scheduled/elastic | A3 | P3 | 时序整形 |

---

## 9. 仲裁、调度、共享与流控

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| ARB-001 | Fixed-priority Arbiter | linear、tree、grouped | A2 | P0 | 优先级链 |
| ARB-002 | Round-robin Arbiter | mask、rotate+priority、pointer | A2 | P0 | 规模扩展、翻转 |
| ARB-003 | Weighted RR Arbiter | quota、smooth WRR | A2 | P2 | 权重状态与公平性 |
| ARB-004 | Deficit RR Arbiter | byte/packet quantum | A2 | P3 | 加法状态与包长 |
| ARB-005 | Age-based Arbiter | timestamp/counter | A2 | P3 | 比较网络面积 |
| ARB-006 | Lottery/Random Arbiter | LFSR-weighted | A2 | P3 | 随机质量与验证 |
| ARB-007 | Multi-grant Arbiter | top-K、prefix、bank-aware | A2 | P2 | 多授权组合复杂度 |
| ARB-008 | Hierarchical Arbiter | local+global、cluster | A2 | P1 | 大规模请求时序 |
| ARB-009 | Pipelined Arbiter | registered grant、lookahead | A2 | P1 | 延迟与满吞吐 |
| ARB-010 | Packet-locking Arbiter | lock until EOP/length | A2/A3 | P1 | 锁定状态与公平性 |
| ARB-011 | Credit Manager | per-VC/shared pool | A2 | P0 | 计数一致性和位宽 |
| ARB-012 | Token Allocator | bitmap/free-list/tree | A2 | P1 | 分配/回收时序 |
| ARB-013 | Resource Pool Manager | free list、stack、bitmap | A2 | P2 | 容量、并行分配 |
| ARB-014 | Request Coalescer | same target/address merge | A2 | P2 | 比较网络和Buffer |
| ARB-015 | Request Distributor | RR/hash/load-aware | A2 | P2 | 均衡度与路由逻辑 |
| ARB-016 | Shared Operator Scheduler | static/dynamic/time-mux | A2/A4 | P1 | 资源面积与排队延迟 |
| ARB-017 | Bank Conflict Resolver | replay/stall/remap | A2 | P1 | 冲突率和吞吐 |
| ARB-018 | Outstanding Tracker | counter/tag table/bitmap | A2 | P1 | 容量与匹配逻辑 |
| ARB-019 | Reservation/Lock Manager | owner/timeout/priority | A2 | P3 | 死锁与状态开销 |
| ARB-020 | Barrier/Join Controller | count/bitmap/generation | A2 | P2 | 参与者数量与扇入 |

---

## 10. CDC、RDC 与多时钟域

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| CDC-001 | Single-bit Synchronizer | 2/3-stage、hardened cell | A1 | P0 | MTBF、属性、布局 |
| CDC-002 | Multi-bit Static Synchronizer | per-bit + stability contract | A1/A2 | P0 | 仅适用于静态配置总线 |
| CDC-003 | Pulse Synchronizer | toggle、stretch、acknowledged | A2 | P0 | 脉宽与连续脉冲间隔 |
| CDC-004 | Toggle Synchronizer | event toggle、counter extension | A2 | P0 | 事件丢失边界 |
| CDC-005 | Handshake Synchronizer | 2-phase、4-phase | A2 | P0 | 延迟、吞吐、复位 |
| CDC-006 | Bundled-data CDC | req/ack + stable data | A2 | P1 | 数据稳定窗口和约束 |
| CDC-007 | Bus Snapshot CDC | shadow/latch/snapshot | A2 | P1 | 原子采样 |
| CDC-008 | Gray Counter CDC | binary-gray-sync-decode | A2 | P0 | 最大跳变与约束 |
| CDC-009 | Async FIFO | small register/large SRAM | A2 | P0 | 指针、满空、复位 |
| CDC-010 | Mesochronous Elastic Buffer | phase-slip/elastic | A2 | P3 | 同频异相场景 |
| CDC-011 | Plesiochronous Rate Matcher | skip/repeat/elastic | A2 | P3 | 频偏吸收 |
| CDC-012 | Clock-domain Event Aggregator | per-source sync + collect | A2 | P1 | 同时事件和扇入 |
| CDC-013 | Clock-domain Config Bridge | shadow+update handshake | A2/A3 | P1 | 一致性与低频配置 |
| RDC-001 | Async Assert/Sync Release Reset | 2/3-stage | A1 | P0 | 复位恢复/移除时间 |
| RDC-002 | Fully Synchronous Reset Bridge | request/ack sequence | A2 | P1 | 域间顺序 |
| RDC-003 | Reset Pulse Stretcher | min-cycle programmable | A1/A2 | P0 | 最短复位周期 |
| RDC-004 | Reset Domain Isolation | clamp/handshake | A2 | P1 | 失复位域影响隔离 |
| RDC-005 | Reset Sequencer | dependency DAG、timeout | A2/A4 | P1 | 扇出、启动延迟 |
| RDC-006 | Warm/Cold Reset Controller | cause/filter/distribution | A2/A4 | P2 | 状态保留边界 |

---

## 11. 时钟、复位、功耗与高扇出优化

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| CRP-001 | Local Clock Enable | CE inference、ICG wrapper | A1/A0 | P0 | 门控粒度与工具识别 |
| CRP-002 | Hierarchical Clock Gating Controller | local/global enables | A2 | P1 | ICG共享与扇出 |
| CRP-003 | Auto Clock Gating Detector | idle/activity based | A2 | P2 | 收益阈值与唤醒 |
| CRP-004 | Clock Divider | integer/even/odd/fraction shell | A2 | P1 | 占空比与毛刺 |
| CRP-005 | Clock Switch Controller | glitch-free mux protocol | A2 | P1 | 切换握手和无时钟场景 |
| CRP-006 | Clock Request/Acknowledge | gated source handshake | A2 | P1 | 启停延迟 |
| CRP-007 | Reset Synchronizer | parameterized stages | A1 | P0 | RDC签核属性 |
| CRP-008 | Reset Filter/Deglitch | sampled/qualified | A2 | P2 | 外部复位噪声 |
| CRP-009 | Reset Cause Collector | sticky/priority encode | A2 | P1 | 软件可观测性 |
| CRP-010 | Reset Distribution Helper | partition/local replication | A2 | P1 | 高扇出和局部化 |
| CRP-011 | Operand Isolation | input hold/zero/mux isolation | A1/A2 | P1 | 动态功耗与时序代价 |
| CRP-012 | Data Gating | valid-based/change-based | A1/A2 | P1 | 毛刺和翻转抑制 |
| CRP-013 | Pipeline Freeze Controller | clock/data enable | A2 | P1 | 状态一致性与唤醒 |
| CRP-014 | Idle Detector | counter/window/protocol-aware | A2 | P1 | 检测功耗和误判 |
| CRP-015 | Activity Detector | toggle/event/window | A2 | P1 | 监控开销 |
| CRP-016 | Power-domain Handshake | request/ack/isolate/save | A2 | P2 | UPF状态序列 |
| CRP-017 | Isolation Control Sequencer | clamp/unclamp ordering | A2 | P2 | 安全时序 |
| CRP-018 | Retention Control Sequencer | save/restore/check | A2 | P2 | 数据完整性 |
| CRP-019 | Memory Sleep Controller | bank/global idle policy | A2 | P2 | break-even与唤醒 |
| CRP-020 | High-fanout Replicator | register/mux/decode replication | A2 | P1 | 功能等价与物理收益 |
| CRP-021 | Config Mirror/Local Decode | centralized/distributed | A2 | P1 | 布线与寄存器面积 |
| CRP-022 | Enable Tree Helper | hierarchical enable pipeline | A2 | P1 | 时钟周期与控制对齐 |

---

## 12. 控制、计数、事件与状态管理

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| CTL-001 | Up/Down Counter | binary/Gray/saturating | A1 | P0 | 最小位宽、切换功耗 |
| CTL-002 | Modulo Counter | arbitrary/power-of-two | A1 | P0 | 比较与回绕 |
| CTL-003 | Timestamp Counter | free-running/prescaled | A1/A2 | P1 | 位宽、跨域采样 |
| CTL-004 | Timer | one-shot/periodic/cascade | A2 | P0 | Prescaler共享 |
| CTL-005 | Timeout Monitor | cycle/event/progress based | A2 | P0 | 监控开销与恢复 |
| CTL-006 | Watchdog | windowed/non-windowed | A2 | P1 | 安全诊断覆盖 |
| CTL-007 | Prescaler/Rate Divider | integer/fraction accumulator | A1/A2 | P1 | 精度和切换 |
| CTL-008 | FSM Shell | binary/one-hot/Gray encoding | A1/A2 | P0 | 编码按表征选型 |
| CTL-009 | Hierarchical FSM | parent/child decomposition | A2 | P2 | 状态爆炸控制 |
| CTL-010 | Micro-sequencer | ROM/table-driven | A2 | P2 | 控制ROM与可配置性 |
| CTL-011 | Command Sequencer | queue/FSM/table | A2 | P2 | 状态与Buffer |
| CTL-012 | Retry Controller | bounded/backoff/selective | A2 | P2 | 活锁与计数器 |
| CTL-013 | Event Edge Detector | rise/fall/both | A1 | P0 | CDC前后使用约束 |
| CTL-014 | Pulse Stretcher/Compressor | fixed/programmable | A1 | P0 | 最小脉宽 |
| CTL-015 | Event Collector | OR/tree/bitmap/count | A2 | P0 | 事件丢失语义 |
| CTL-016 | Event Router | programmable/static map | A2 | P1 | Mux、扇出和配置 |
| CTL-017 | Event Debouncer/Filter | count/window/majority | A2 | P2 | 延迟和外部输入 |
| CTL-018 | Token/Credit Counter | saturating/checked | A2 | P0 | 上下溢保护 |
| CTL-019 | Sequence Number Manager | wrap/window/compare | A2 | P2 | 回绕比较 |
| CTL-020 | Bitmap Allocator | linear/tree/hierarchical | A2 | P1 | 查找与更新关键路径 |
| CTL-021 | Free-list Manager | FIFO/stack/bitmap | A2 | P2 | 多分配/回收 |
| CTL-022 | Scoreboard | bit/vector/tagged | A2 | P2 | CAM/bitmap权衡 |
| CTL-023 | Dependency Tracker | counter/bitmap/DAG subset | A2 | P3 | 状态规模 |
| CTL-024 | Quiesce/Drain Controller | stop-accept/drain/ack | A2 | P1 | 低功耗与复位切换 |

---

## 13. 中断、错误与功能安全公共构件

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| SAF-001 | Parity-protected Register | data+parity、auto-check | A2 | P1 | 面积与读写延迟 |
| SAF-002 | ECC-protected Memory Shell | SECDED、scrub、bypass | A2 | P1 | 纠错路径和带宽 |
| SAF-003 | Dual Modular Comparator | cycle/transaction compare | A2 | P2 | 比较覆盖与延迟 |
| SAF-004 | Lockstep Alignment Buffer | fixed/elastic delay | A2 | P2 | 双核对齐与状态 |
| SAF-005 | Lockstep Comparator | configurable compare masks | A2 | P2 | 比较宽度与错误延迟 |
| SAF-006 | Temporal Redundancy Controller | replay/double-execute | A2 | P3 | 性能开销 |
| SAF-007 | TMR Voter | bit/word/state voter | A1/A2 | P3 | 面积、共因失效边界 |
| SAF-008 | Safety Mechanism Bypass/Mode | controlled mux + status | A2 | P2 | 安全状态与测试 |
| SAF-009 | Fault Injection Point | force/flip/stuck-at/pulse | A1/A2 | P1 | 综合隔离和验证 |
| SAF-010 | Error Status Latch | sticky/first-error/count | A2 | P0 | 信息保留与面积 |
| SAF-011 | Error Aggregator | OR/tree/vector/priority | A2 | P0 | 扇入、延迟、去重 |
| SAF-012 | Error Router | destination mask/multicast | A2 | P1 | 高扇出和配置 |
| SAF-013 | Error Escalation Controller | threshold/window/stage | A2 | P2 | 状态和响应延迟 |
| SAF-014 | Alarm Handler Core | class/severity/timeout subset | A4 | P2 | 接近IP，需边界治理 |
| SAF-015 | Bus Transaction Monitor | timeout/protocol/address | A3 | P1 | 插入延迟与观测覆盖 |
| SAF-016 | End-to-end Protection Codec | data+sequence+CRC | A3 | P2 | 带宽、延迟、标准配置 |
| SAF-017 | Duplicate/Sequence Checker | rolling window/bitmap | A2/A3 | P2 | 窗口容量 |
| SAF-018 | Alive/Heartbeat Monitor | periodic/windowed | A2 | P1 | 误报和监控时钟 |
| SAF-019 | Clock Monitor Digital Shell | missing/too-fast/too-slow | A2 | P2 | 参考时钟与计数误差 |
| SAF-020 | Reset Monitor | cause/order/duration check | A2 | P2 | RDC与安全状态 |
| SAF-021 | Voltage/Temperature Monitor Wrapper | alarm/status synchronizer | A0/A2 | P3 | 模拟监控器接口 |
| SAF-022 | Safe-state Controller | local/global request/ack | A2/A4 | P2 | 失效响应时间 |
| SAF-023 | Memory Address/Data Protection | parity/tag/ECC sideband | A2 | P2 | 存储与延迟开销 |
| SAF-024 | Latent Fault Test Controller | periodic test handshake | A2 | P3 | 业务中断与覆盖 |
| SAF-025 | Safety Counter Checker | dual counter/encoded counter | A1/A2 | P2 | 诊断覆盖与面积 |
| SAF-026 | Safety FSM Checker | illegal state/transition monitor | A1/A2 | P1 | 编码与综合保持 |
| SAF-027 | Interrupt Source Conditioner | sync/pulse2level/sticky/mask | A2 | P0 | PIC前端复用重点 |
| SAF-028 | Interrupt Aggregator | vector/tree/hierarchical | A2 | P0 | 大位宽扇入 |
| SAF-029 | Interrupt Router | static/configurable/multicast | A2/A3 | P1 | 到CLIC/安全岛双送 |
| SAF-030 | Interrupt Rate Limiter | debounce/count/window | A2 | P2 | 中断风暴控制 |

---

## 14. APB/AHB/寄存器接口构件

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| BUS-001 | Generic CSR Bus Adapter | req/rsp、single outstanding | A3 | P0 | 内部统一接口 |
| BUS-002 | APB Slave Adapter | APB3/APB4、wait/error | A3 | P0 | 低面积与时序 |
| BUS-003 | APB Register Slice | request/response/full | A3 | P1 | PREADY返回路径 |
| BUS-004 | APB Decoder | one-to-N、hierarchical | A3 | P0 | 地址译码与PREADY Mux |
| BUS-005 | APB Mux/Interconnect | N-to-M、fixed arbitration | A3/A4 | P1 | 规模与共享路径 |
| BUS-006 | APB CDC Bridge | handshake/async queue | A3 | P1 | 低吞吐CDC优化 |
| BUS-007 | APB Width Adapter | 32/64/custom | A3 | P2 | Byte strobe与跨拍 |
| BUS-008 | APB Timeout/Default Slave | programmable/fixed | A3 | P0 | 防挂死与低开销 |
| BUS-009 | AHB-Lite Slave Adapter | pipelined address/data | A3 | P1 | 地址/数据相位 |
| BUS-010 | AHB-Lite Register Slice | forward/full | A3 | P1 | HREADY路径 |
| BUS-011 | AHB-Lite Decoder/Mux | one-to-N/N-to-one | A3 | P2 | 响应Mux时序 |
| BUS-012 | AHB-Lite CDC Bridge | handshake/async FIFO | A3 | P2 | 相位与响应 |
| BUS-013 | AHB↔APB Bridge | single/multi APB port | A3/A4 | P1 | Buffer与时钟比 |
| BUS-014 | CSR Shadow/Commit Adapter | atomic update/snapshot | A3 | P1 | 配置一致性 |
| BUS-015 | CSR Access Policy Filter | RO/RW/W1C/privilege | A3 | P1 | 译码与安全策略 |
| BUS-016 | Register Broadcast Adapter | one-to-N/local mirrors | A3 | P2 | 高扇出优化 |

---

## 15. AXI4/AXI4-Lite/AXI-Stream 构件

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| AXI-001 | AXI Channel Register Slice | per-channel F/B/full/skid | A3 | P0 | 五通道独立切时序 |
| AXI-002 | AXI-Lite Register Slice | combined/per-channel | A3 | P0 | 小面积低延迟 |
| AXI-003 | AXI Buffer | channel depth/transaction buffer | A3 | P1 | Outstanding与背压 |
| AXI-004 | AXI Data Width Converter | upsize/downsize | A3 | P1 | Burst、strobe、unaligned |
| AXI-005 | AXI Address Width Adapter | extend/truncate/window | A3 | P1 | 地址合法性 |
| AXI-006 | AXI ID Width Converter | remap/compress/expand | A3 | P1 | ID表面积和并发 |
| AXI-007 | AXI User Signal Adapter | map/tie/filter | A3 | P2 | 固定字段裁剪 |
| AXI-008 | AXI Burst Splitter | boundary/max-length/4KB | A3 | P1 | 状态与吞吐 |
| AXI-009 | AXI Burst Merger/Coalescer | adjacent/same attribute | A3 | P2 | 比较、Buffer、顺序 |
| AXI-010 | AXI Burst Length Adapter | fixed/max programmable | A3 | P2 | 地址推进 |
| AXI-011 | AXI Outstanding Limiter | global/per-ID/per-channel | A3 | P1 | 计数器和阻塞 |
| AXI-012 | AXI ID Remapper | static/table/free-list | A3 | P2 | 表容量与匹配 |
| AXI-013 | AXI Transaction Serializer | full/per-ID | A3 | P1 | 面积换并发 |
| AXI-014 | AXI Read/Write Interleaver | ordered/tagged | A3 | P3 | 顺序规则复杂度 |
| AXI-015 | AXI Clock Converter | async FIFO/handshake hybrid | A3 | P0 | 全通道CDC正确性 |
| AXI-016 | AXI Protocol Converter | AXI4↔AXI4-Lite subset | A3 | P1 | Burst拆分与错误 |
| AXI-017 | AXI-to-APB Bridge | single/multi port | A3/A4 | P1 | 队列、译码、时钟 |
| AXI-018 | AXI-to-AHB Bridge | buffered/pipelined | A3/A4 | P2 | 顺序和响应映射 |
| AXI-019 | AXI Address Decoder | region/mask/hierarchical | A3 | P0 | 比较和路由关键路径 |
| AXI-020 | AXI Demux | static/dynamic target | A3 | P1 | 响应路由状态 |
| AXI-021 | AXI Mux | fixed/RR/QoS arbitration | A3 | P1 | 五通道仲裁与锁定 |
| AXI-022 | AXI Crossbar | shared/full/sparse | A4 | P2 | 面积、布线、并发 |
| AXI-023 | AXI Default Slave | DECERR/SLVERR programmable | A3 | P0 | 无目标响应 |
| AXI-024 | AXI Timeout Monitor | per-channel/transaction | A3 | P1 | 表项和恢复策略 |
| AXI-025 | AXI Firewall/Region Filter | address/ID/privilege | A3 | P2 | 安全策略与关键路径 |
| AXI-026 | AXI Exclusive Access Monitor | local/global table | A3 | P3 | 表项与一致性范围 |
| AXI-027 | AXI Atomic Adapter | subset/emulation | A3 | P3 | 原子性和锁定 |
| AXI-028 | AXI QoS Mapper | static/table/traffic class | A3 | P2 | 配置和仲裁衔接 |
| AXI-029 | AXI Performance Monitor | latency/bandwidth/outstanding | A3 | P1 | 被动观测开销 |
| AXI-030 | AXI Error Injector | channel/response/data | A3 | P2 | 验证模式隔离 |
| AXIS-001 | AXI-Stream Register Slice | F/B/full/skid | A3 | P0 | Ready路径 |
| AXIS-002 | AXI-Stream Width Converter | byte-aligned/general ratio | A3 | P1 | TKEEP/TLAST对齐 |
| AXIS-003 | AXI-Stream Switch | mux/demux/crossbar | A3/A4 | P2 | 包锁定与路由 |
| AXIS-004 | AXI-Stream Packet FIFO | store-forward/cut-through | A3 | P1 | 包边界与容量 |
| AXIS-005 | AXI-Stream Broadcaster | all/subset outputs | A3 | P2 | Ready汇聚 |
| AXIS-006 | AXI-Stream Combiner/Subset | TDATA/TUSER composition | A3 | P2 | Lane映射 |
| AXIS-007 | AXI-Stream Frame Length Monitor | min/max/count | A3 | P2 | 低开销检查 |
| AXIS-008 | AXI-Stream Rate Limiter | token bucket/gap insert | A3 | P2 | 吞吐整形 |

---

## 16. NoC、片间与高级互联公共构件

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| NOC-001 | Flit Packer/Unpacker | fixed/variable header | A3 | P2 | Mux、字段映射 |
| NOC-002 | Virtual-channel FIFO | shared/dedicated storage | A3 | P2 | RAM利用率与头阻塞 |
| NOC-003 | VC Allocator | separable/input-first/output-first | A3 | P3 | 仲裁规模 |
| NOC-004 | Switch Allocator | speculative/non-speculative | A3 | P3 | 关键路径核心 |
| NOC-005 | NoC Input Port | buffer+route+VC state | A3/A4 | P3 | 面积和流控 |
| NOC-006 | NoC Output Port | arbitration+credit | A3/A4 | P3 | 扇入与信用返回 |
| NOC-007 | Crossbar Fabric | full/sparse/multistage | A2/A3 | P2 | 布线、Mux、流水 |
| NOC-008 | Route Compute | table/XY/source route | A2/A3 | P3 | 组合延迟 |
| NOC-009 | Credit Return Channel | aggregated/per-VC | A3 | P2 | 反馈延迟与位宽 |
| NOC-010 | Link Register Slice | forward/reverse/full | A3 | P1 | 长距离切时序 |
| NOC-011 | Link CDC Adapter | async FIFO/mesochronous | A3 | P2 | 时钟关系 |
| NOC-012 | Link Width Converter | flit segmentation/assembly | A3 | P2 | Buffer与延迟 |
| NOC-013 | Link CRC/Replay Shell | detect/retry/sequence | A3 | P3 | 可靠性和Buffer |
| NOC-014 | Link Power-state Handshake | quiesce/isolate/wakeup | A3 | P2 | 低功耗序列 |
| NOC-015 | Deadlock/Progress Monitor | timeout/dependency summary | A3 | P3 | 观测开销 |
| NOC-016 | CHI/ACE Channel Slice | protocol-channel pipeline | A3 | P3 | 一致性协议专项验证 |
| NOC-017 | Chiplet Streaming Adapter | die-to-die logical stream | A3 | P3 | 不替代PHY/标准协议IP |

---

## 17. 监控、调试、性能与可观测性

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| MON-001 | Event Counter | saturating/wrapping/clear-on-read | A1/A2 | P0 | 位宽和门控 |
| MON-002 | Multi-event Counter Bank | shared prescaler/muxed update | A2 | P1 | 多事件更新与面积 |
| MON-003 | Cycle/Busy/Idle Counter | gated/free-running | A2 | P0 | 时钟功耗 |
| MON-004 | Latency Monitor | timestamp/FIFO/histogram | A2/A3 | P1 | 表项和量化 |
| MON-005 | Bandwidth Monitor | bytes/beats/window | A2/A3 | P1 | 计数位宽 |
| MON-006 | Occupancy Monitor | current/max/average/histogram | A2 | P1 | 除法与采样近似 |
| MON-007 | Stall/Backpressure Monitor | reason bitmap/counter | A3 | P1 | 信号扇入 |
| MON-008 | Activity/Toggle Sampler | sampled/windowed | A2 | P2 | PPA数据采集开销 |
| MON-009 | Trace Event Encoder | fixed/variable format | A2 | P2 | 编码与带宽 |
| MON-010 | Trace FIFO | lossless/drop/overwrite | A2 | P2 | 容量和观测影响 |
| MON-011 | Trace Funnel | priority/RR/timestamp merge | A3 | P2 | 仲裁与排序 |
| MON-012 | Trigger/Qualifier | match/mask/sequence | A2 | P2 | 比较网络 |
| MON-013 | Snapshot Register Bank | atomic capture/readout | A2 | P1 | 面积和采样一致性 |
| MON-014 | Protocol Progress Monitor | state/timeout/event | A3 | P2 | 误报和状态开销 |
| MON-015 | Performance Counter CSR Adapter | APB/AXI-Lite/generic CSR | A3 | P1 | 统一软件接口 |
| MON-016 | Lightweight Logic Analyzer Shell | trigger+buffer+readout | A4 | P3 | 调试配置按需裁剪 |

---

## 18. DFT、测试与可制造性辅助

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| DFT-001 | Test-mode Synchronizer | static test control sync | A1 | P1 | 功能/测试模式隔离 |
| DFT-002 | Scan-enable Distribution Helper | local latch/replication | A2 | P2 | 高扇出与CTS |
| DFT-003 | Clock-control Test Override | ICG/mux bypass | A0/A2 | P1 | DFT与无毛刺 |
| DFT-004 | Reset-control Test Override | controlled bypass/force | A2 | P1 | RDC与测试顺序 |
| DFT-005 | MBIST Port Arbiter | functional/test ownership | A2 | P2 | Mux延迟和隔离 |
| DFT-006 | LBIST/MISR | configurable polynomial/width | A2 | P3 | 面积和切换峰值 |
| DFT-007 | PRPG | LFSR/phase shifter | A2 | P3 | 随机模式与功耗 |
| DFT-008 | Signature Comparator | expected/masked compare | A1/A2 | P3 | 测试数据路径 |
| DFT-009 | Test Access Mux | scan/JTAG/internal bus | A3 | P2 | 功能路径零影响目标 |
| DFT-010 | Memory Repair Data Adapter | fuse/OTP/BISR mapping | A2 | P3 | 工艺相关元数据 |

---

## 19. DSP、图像与 AI 数据搬运公共构件

这些构件只承载通用数据整形和规则计算；完整 FFT、FIR、卷积核、矩阵引擎通常应作为 IP，而不是基础 CBB。

| ID | 构件族 | 主要实现变体 | 级别 | 优先级 | PPA关注点 |
|---|---|---|---|---|---|
| DSP-001 | Lane Packer/Unpacker | fixed/masked lanes | A2/A3 | P2 | 布线和有效位 |
| DSP-002 | Vector Reduction | sum/min/max/and/or | A2 | P2 | 树形、流水、精度 |
| DSP-003 | Dot-product Tree | full parallel/folded | A2 | P2 | MAC数量与吞吐 |
| DSP-004 | Sliding Window Generator | register/SRAM line buffer | A2/A3 | P2 | 存储带宽和边界 |
| DSP-005 | Tensor Layout Converter | NHWC/NCHW/block/tile | A3 | P3 | Buffer和地址生成 |
| DSP-006 | Tile Address Generator | nested counter/affine | A2 | P2 | 乘法消除、增量地址 |
| DSP-007 | Stride/Dilation Address Generator | nested/parameterized | A2 | P2 | 控制面积和吞吐 |
| DSP-008 | Scatter/Gather Index Generator | list/affine/masked | A2 | P3 | 随机访存和队列 |
| DSP-009 | DMA Descriptor Walker Core | ring/linked list subset | A4 | P3 | 若含完整DMA则升级为IP |
| DSP-010 | Quantization Pipeline | scale/zero-point/clamp | A2/A3 | P2 | 位宽、乘法与流水 |
| DSP-011 | Activation Approximation | ReLU/PReLU/LUT-piecewise | A2 | P3 | 精度/面积 |
| DSP-012 | Sparse Bitmap/Index Decoder | bitmap/RLE/block sparse | A2/A3 | P3 | 控制分支与吞吐 |
| DSP-013 | Accumulator Bank | banked/multi-lane/reduction | A2 | P2 | 写冲突和位宽 |
| DSP-014 | Double-buffer Controller | ping-pong/N-buffer | A2 | P2 | 计算搬运重叠 |
| DSP-015 | Loop/Nested-counter Generator | programmable/static | A2 | P2 | 控制复用 |

---

## 20. 子系统模板与参考架构配方

以下资产进入独立的 `templates/recipes` Catalog，不与普通 RTL CBB 数量混算。

| ID | 模板/配方 | 组成与主要变体 | 级别 | 优先级 | 核心价值 |
|---|---|---|---|---|---|
| TMP-001 | 多Bank SRAM子系统 | bank mapper + scheduler + ECC + sleep | A4 | P1 | 容量、吞吐、功耗Pareto |
| TMP-002 | 低延迟寄存器文件子系统 | RF + bypass + replication | A4 | P2 | 多读端口优化 |
| TMP-003 | 共享运算单元模板 | arbiter + operand queue + result route | A4 | P1 | 面积换延迟 |
| TMP-004 | 高吞吐加法/MAC树 | compressor + pipeline + isolation | A4 | P1 | 数据通路示范闭环 |
| TMP-005 | 高频 Ready/Valid 通道 | F/B/full slice组合 | A4 | P0 | 自动切分反压路径 |
| TMP-006 | 长距离物理链路 | slice + replication + CDC可选 | A4 | P1 | 跨分区时序收敛 |
| TMP-007 | 分层仲裁网络 | local/global arbiter + buffers | A4 | P1 | 32/64/128路扩展 |
| TMP-008 | 分层地址译码网络 | global region + local decode | A4 | P1 | 高扇出和响应Mux |
| TMP-009 | AXI共享互联模板 | decode + arbitrate + buffer + monitor | A4 | P2 | 可裁剪互联 |
| TMP-010 | AXI异步桥模板 | channel CDC + depth selection | A4 | P1 | 宽总线跨域PPA |
| TMP-011 | AXI宽度转换桥模板 | splitter/packer/ID tracking | A4 | P2 | 32～1024bit适配 |
| TMP-012 | APB外设簇模板 | bridge + decoder + timeout + CSR | A4 | P1 | 低面积控制面 |
| TMP-013 | NoC Router模板 | VC + allocators + crossbar + credit | A4 | P3 | 先进互联研究 |
| TMP-014 | 安全中断前端模板 | condition + sticky + route + monitor | A4 | P1 | PIC/CLIC/安全岛复用 |
| TMP-015 | 错误管理树模板 | local aggregate + route + escalation | A4 | P1 | 功能安全公共架构 |
| TMP-016 | 电源域控制模板 | quiesce + isolate + save + switch + restore | A4 | P2 | UPF控制闭环 |
| TMP-017 | Clock/Reset Manager模板 | source switch + divide + gate + reset seq | A4 | P2 | 时钟复位公共方案 |
| TMP-018 | 低功耗流水线模板 | valid gating + freeze + operand isolate | A4 | P1 | 活动相关功耗优化 |
| TMP-019 | 高扇出控制优化配方 | mirror + local decode + enable tree | A4 | P1 | 布线和时序 |
| TMP-020 | 流式数据整形模板 | width/rate/packet/buffer pipeline | A4 | P2 | 复合协议适配 |
| TMP-021 | 端到端数据保护通道 | sequence + CRC + timeout + retry | A4 | P2 | 安全通信链 |
| TMP-022 | 性能观测子系统 | event mux + counters + trace + CSR | A4 | P2 | 可观测性按需裁剪 |
| TMP-023 | Memory BIST接入模板 | mux + isolate + controller adapter | A4 | P3 | DFT一致接入 |
| TMP-024 | DSP双缓冲数据通路 | DMA-side stream + ping-pong + compute feed | A4 | P3 | 搬运计算重叠 |

---

## 21. 明确不纳入基础 CBB Catalog 的资产

| 类型 | 示例 | 管理建议 |
|---|---|---|
| 完整业务 IP | DMA、GIC、CLIC、完整PIC、FFT、NPU、Cache Controller | 独立 IP 仓库和版本生命周期 |
| 模拟/混合信号 IP | PLL、ADC、PHY、PMIC接口宏 | CBB库只保留数字 Wrapper |
| 单项目胶水逻辑 | 特定层次路径、项目地址常量、临时workaround | 留在项目仓库；高复用后再提炼 |
| 纯工具函数 | clog2、位宽推导、静态断言宏 | 放公共 SystemVerilog package |
| 验证组件 | VIP、BFM、scoreboard、coverage model | 放验证资产库；CBB包可声明依赖 |
| 物理实现脚本 | Floorplan、CTS、route directive | 放技术适配/实现 Recipe 库 |
| 未经验证代码片段 | 个人snippet、AI临时代码 | 进入 incubator，不进入正式Catalog |

---

## 22. 推荐的首期落地集合

### 22.1 P0 最小公共底座

建议首先形成约 40 个可发布构件族，而不是立即实现全清单：

1. SRAM/ICG/Clock Mux Wrapper；
2. Mux、Encoder、Decoder、LZC、Popcount；
3. Adder/Subtractor、Accumulator、Compare、Resize；
4. Parity、SECDED、Gray converter；
5. Address Decoder、Register Array、SRAM拼宽/拼深、RAW Bypass；
6. Sync FIFO、Async FIFO、Fall-through FIFO、Elastic/Skid Buffer；
7. Forward/Backward/Full Ready-Valid Slice；
8. Fixed Priority、Round-robin Arbiter、Credit Manager；
9. 单比特、Pulse、Handshake、Gray Counter CDC；
10. Reset Synchronizer、Reset Stretcher；
11. Counter、Timer、Timeout、Event Collector；
12. Interrupt Conditioner/Aggregator；
13. Generic CSR/APB Adapter、APB Decoder/Timeout；
14. AXI/AXI-Lite/AXI-Stream Register Slice、AXI Decoder、Default Slave。

### 22.2 P1 PPA示范集合

- 多操作数 Adder/CSA/Compressor Tree；
- Constant Multiplier、Pipelined Multiplier/MAC；
- SRAM FIFO、Width-conversion FIFO、Multi-channel FIFO；
- Hierarchical Arbiter、Pipelined Arbiter；
- AXI Width Converter、Outstanding Limiter、Clock Converter；
- 高扇出 Replication、Local Decode、Operand Isolation、Pipeline Freeze；
- 多Bank SRAM、共享运算单元、高频 Ready/Valid、分层仲裁四类参考模板。

---

## 23. Catalog 建库字段建议

每个表中构件落库时至少补齐：

```yaml
cbb:
  id: QUE-001
  name: sync_fifo
  abstraction_level: A2
  primary_domain: storage_queue
  secondary_domains: [streaming]
  priority: P0

contract:
  interface: ready_valid
  ordering: fifo
  throughput: 1_per_cycle
  latency_definition: first_word_to_output
  reset_behavior: empty_after_reset

implementations:
  - impl_register_pointer
  - impl_shift_register
  - impl_sram_prefetch

parameters:
  data_width: {min: 1, max: 2048}
  depth: {min: 2, max: 4096}
  fall_through: [false, true]

evidence:
  quality_gates: [lint, simulation, formal, synthesis]
  ppa_characterization: required
  characterized_implementations: []
```

除上述字段外，还应登记维护人、版本、依赖、License、支持工艺、合法参数域、时钟/复位假设、约束文件、验证状态、PPA数据集和已知限制。

---

## 24. 清单治理建议

- `candidate`：已登记需求，但功能契约尚未评审；
- `incubator`：有RTL与初步验证，尚未完成统一质量门禁；
- `qualified`：功能、质量和至少一个基准环境PPA表征通过；
- `released`：版本稳定，可通过FuseSoC/Catalog正式依赖；
- `preferred`：在明确适用区域内处于Pareto前沿并有项目复用证据；
- `deprecated`：停止新增使用，保留迁移路径；
- `retired`：从新版本Catalog移除，但历史发布包仍可追溯。

本清单用于定义“候选全集”，不意味着所有构件同时开工。实际建设顺序应由跨项目复用频率、PPA潜在收益、正确性风险、现有资产成熟度和表征成本共同决定。
