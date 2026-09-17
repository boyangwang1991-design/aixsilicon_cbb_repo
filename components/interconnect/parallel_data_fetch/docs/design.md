# 架构设计与论证（C2）— parallel_data_fetch

> 构件族：`stateful`（含 `cdc` 结构），文档布局：split（本文 + [`detail-design/`](detail-design/)）。
> 本文承接 [`cbb_spec.md`](cbb_spec.md) 的契约，给出微架构、时序/守恒、复位与错误模型、
> CDC/RDC 结构选型与 PPA 优化点论证；RTL 仅在上游契约与本文落地后编写（workflow-execution DOC-02）。

## 1. 模块划分（集成边界）

物理集成要求把两端放在相距较远的区域，窄链路作为跨区布线。因此公开交付**两个端点模块**：

| 实例 | 所在区域 | 职责 | 时钟域 |
|---|---|---|---|
| `parallel_data_fetch_requester` | A 端（请求侧） | 请求发起、beat 重组、奇偶校验、超时计时、错误码判定与结果输出 | 仅 A 域 |
| `parallel_data_fetch_provider` | B 端（数据侧） | 远端请求边沿检测、向数据源取数、原子快照、切片连续发送 | 仅 B 域 |
| `pdf_async_fifo` | 跨域边界 | 返回 beat bundle 跨域（写端口 B 域、读端口 A 域） | B→A 双域 |
| `parallel_data_fetch` | 同层/仿真 | 内部实例化上述三者，窄链路成为内部连线；仅用于 RTL 仿真与同层级集成 | — |

**为何 async FIFO 不作为端点内部子模块**：其两端分属不同时钟域，无法归入任一单侧端点；
同时要求物理集成把 A/B 端分开摆放，故它作为与端点**同级**的独立库单元，由集成方（或上层 IP 的
link mux）与请求方向同步器一起实例化在链路边界处。这一点是物理分区驱动的结构性决策，不是实现细节。

集成契约（端口级）见 [`cbb_spec.md`](cbb_spec.md) §2；链路信号是公开接口的一部分。

## 2. 微架构

### 2.1 Requester 状态机

```
LINK_WAIT --link_up--> IDLE --req_fire--> RECEIVE --收齐/终结--> HOLD --rsp_fire-->
   ^                     |                   |                                       |
   +---- link_down ------+                   |                                       v
                                             失败终结 --> HOLD ----------------> RECOVER --> IDLE
                                                                                （静默窗口）
```

关键设计决策：

1. **RECEIVE → HOLD 的唯一终结条件**：收齐 `BEAT_COUNT` 拍（成功）或遇到致命错误/超时/last
   （失败）。不存在中间输出状态，从结构上保证"不输出部分数据"。
2. **错误后的静默窗口 `RECOVER`（本实现的关键修正）**：返回链路无 ready，B 端一旦开始发送
   就连续输出 `BEAT_COUNT` 拍。若 A 端因超时/错误提前离开 RECEIVE，后续 beat 仍在途；
   此时若立即接受新请求，在途旧 beat 会污染新事务。`RECOVER` 状态用
   `QUIET_MAX = BEAT_COUNT + LINK_PIPE_STAGES + REQ_SYNC_STAGES + 2` 拍消费并丢弃在途 beat 后再回 IDLE。
   相比"依赖 epoch 过滤"，该方案同时避免异步模式下请求 toggle 在 B 端仍忙时丢失。
3. **epoch 双保险**：每次请求翻转单 bit `epoch_q`，requester 只接收 `beat_epoch_i == epoch_q`
   的 beat；用于过滤跨越静默窗口的极端迟到数据。
4. **计数器位宽**：`beat_cnt_q` 用 `(BEAT_COUNT<=1)?1:$clog2(BEAT_COUNT)`，
   `tmo_cnt_q` 用 `$clog2(TIMEOUT_CYCLES+1)`，`quiet_cnt_q` 同理防零宽（domain-rules §3.1.1）。
5. **重组索引写入**：`assemble_q[beat_cnt*LINK_WIDTH +: LINK_WIDTH]`；末拍在 `always_comb`
   内显式合并当前 beat 后再作为结果输出寄存器输入，避免 NBA 导致末拍缺失。

### 2.2 Provider 状态机

```
LINK_WAIT --link_up--> IDLE --new_req--> FETCH --fetch_fire--> WAIT_DATA
                                                                  |--data_fire--> SEND --last--> IDLE
                                                                  |--data_error-> SEND_ERROR --1拍--> IDLE
```

关键设计决策：

1. **原子快照**：`snapshot_q` 只在 `data_fire = b_data_valid_i && b_data_ready_o && !b_data_error_i`
   当拍锁存整份 `DATA_WIDTH`；发送期间只读 `snapshot_q`，结构上不可能访问实时输入。
2. **发送启动的前置条件**：`PV_WAIT_DATA` 期间 `b_data_ready_o` 需要 `link_reserve_ok_i`
   （异步：FIFO 剩余空间 ≥ BEAT_COUNT；同步：恒为 1）。这使"开始发送后不受 A 端反压影响"
   成为可满足的性质，而不是假设。
3. **请求边沿检测**：`new_req = link_req_i ^ req_seen_q`；接受后更新 `req_seen_q`。
   单 outstanding 保证请求不会在 B 端忙时到达（配合 A 端 RECOVER 静默窗口）。
4. **切片三实现**（`SLICE_IMPL`）：
   - `0 = shift`：每拍移位的寄存器副本，控制最简、翻转率高；
   - `1 = indexed`：`snapshot_q` 不变，用 beat counter 动态索引，翻转少但 MUX 深宽大；
   - `2 = banked`（默认）：按 `LINK_WIDTH` 切为静态数组 `bank_q[BEAT_COUNT]`，小位宽索引
     （`beat_cnt_q` 位宽为 `$clog2(BEAT_COUNT)`），兼顾翻转率与 MUX 深度。
   三者共享同一可观察契约（数据、顺序、last、错误语义），由 SVA
   `ap_slice_matches_snapshot` 约束"输出数据恒等于 snapshot 的对应切片"，从而在结构上排除实现差异造成的功能偏移。

## 3. 时序与守恒论证

- **固定传输成本**：`BEAT_COUNT = DATA_WIDTH / LINK_WIDTH`；
  同步模式总延迟 ≈ `1 (请求进入) + T_provider + BEAT_COUNT + LINK_PIPE_STAGES + 1 (重组输出)`。
- **吞吐**：单 outstanding，请求吞吐 ≈ `1 / (T_provider + BEAT_COUNT + 消费与静默开销)`；
  符合"按需 fetch、低占空比"定位。
- **守恒**：每个被接受的请求恰好产生一个结果；成功结果的每一 bit 等于被接受时快照的对应 bit。
  SVA `ap_success_needs_full_burst` 要求成功响应时 `beat_cnt_q == BEAT_COUNT`，
  TB 逐 bit 与捕获快照比对，二者从"计数"与"数据"两个角度约束守恒。
- **连续发送**：provider 的 `ap_send_continuous` 断言 payload 期间不停拍；
  `ap_last_only_at_end` 断言 last 仅在末拍；error response 为单拍（`ap_error_single_beat`）。

## 4. 复位与错误模型

- 两端复位独立、异步断言同步释放；复位清 valid/busy/计数/部分重组/错误累计；
- `link_up = local_stable && remote_stable`，两侧 alive 各由 `pdf_alive_check` 连续稳定判定；
- 错误累积采用**优先级合并函数** `err_merge`（rank：REMOTE_RESET > FIFO > INTERNAL >
  PROTOCOL > PARITY > PROVIDER > TIMEOUT），而非"先到先记"，保证可解释且与契约一致；
- 失败结果 `a_rsp_data_o = RESET_VALUE 语义值`（全 0 或全 1），SVA `ap_error_no_payload` 约束；
- 事务中对端复位 → `ERR_REMOTE_RESET` → 清部分重组 → RECOVER → 重新等待 link_up，不自动重发。

## 5. CDC / RDC 结构选型（白名单：只选型/参数化/实例化）

| 跨域对象 | 结构 | 选型理由 | 约束 |
|---|---|---|---|
| 请求事件（A→B） | 单 bit toggle + 两级（`REQ_SYNC_STAGES`）同步器 + 本地异或检测 | 单 outstanding 下不会丢失或重复；避免对窄脉冲直接同步 | 同步寄存器标 `ASYNC_REG`；过期事件由 A 端 RECOVER 规避 |
| alive（双向） | 同级数同步器 + 连续稳定计数 | 避免复位释放相位差造成的误判 | 稳定 `REQ_SYNC_STAGES` 拍后才置 `link_up` |
| 返回 beat（B→A） | 单 `pdf_async_fifo`，payload 为完整 bundle（data/last/error/parity/epoch） | 禁止逐 bit 同步与"同步 valid 后直采异步 data"；Gray 指针保证容量判定正确 | 深度为 2 的幂且 ≥ BEAT_COUNT；写侧 reservation 后才发送 |
| 同步模式长线 | 统一 bundle pipeline（`pdf_link_pipe`） | data/valid/last/error/parity/epoch 必须同级，禁止单独给某字段插级 | 仅同步模式实例化（PC-011） |

RDC：`pdf_alive_check` 在 `alive_i=0` 时清零稳定计数，使"对端复位/停钟"被确定性识别；
本构件不引入独立复位域桥（端点各自仅用本地复位）。

## 6. PPA 优化点与预期 Pareto 位置

> **已实测修正（2026-09-17）**：下表原为结构推理（PPA-E0）。GF 28nm LP /
> `sc9_cmos28lp_base_hvt tt_1p00v_25c` 的真实综合（10 点，[`../reports/ppa-report.md`](../reports/ppa-report.md)）
> 修正了其中两处推论，见"实测"列。

| 配置 | 主导资源 | 预期 Pareto 位置 | 实测（run-20260917-01） |
|---|---|---|---|
| sync / DATA_WIDTH=256, LINK_WIDTH=32 | 快照 + 重组寄存器各 256 bit | 面积-时序平衡点（默认） | 3204.9 µm²，slack **0.00 ns**（400 MHz 恰 MET，即临界） |
| sync + LINK_PIPE_STAGES=8 | + 寄存器 | 时序优先、面积略增 | 3973.1 µm²（+24%），slack 仅 +0.02 ns → **收益未体现**：关键路径在端点内部（超时/错误合并/重组末拍），不在长线链路 |
| async | + FIFO 存储 + 指针同步器 | 面积最大，换取跨域能力 | 5787.4 µm²（FIFO=16，**+80.6%**）；FIFO=8 → 4519.7 µm²（**+41.0%**），深度减半约省 22% |
| SLICE_IMPL=0/1/2 | shift 翻转率高；indexed MUX 深；banked 小位宽索引 | 三者同功能、分散在面积-功耗-时序空间 | 面积 shift 3187.7 / indexed 3187.5 / banked 3204.9 µm²（差 <0.6%）；**时序 shift 0.03 / indexed 0.04 优于 banked 0.00**——与原文"banked 时序更优"**相反** |
| DATA_WIDTH=4096, LINK_WIDTH=1 | 4096 拍连续发送，帧最长 | 延迟最差、链路位最少 | 未表征（上界到 1024→128：11893.2 µm²，slack 0.15） |

**面积标度**：实测 `DATA_WIDTH` 64→256→512→1024 bit 为 978.7→3204.9→6176.9→11893.2 µm²，
即 **≈11.4 µm²/bit**、线性度良好，与"至少 `2 × DATA_WIDTH` 数据寄存器"的下界推理一致。

**实现选择修正**：默认 `SLICE_IMPL=2`（banked）的原依据是"时序更优"，实测不成立。
保留 banked 为默认的**正确依据**是**翻转率/功耗**（每拍只动 1 个 bank；shift 每拍翻转全宽），
但本构件无 SAIF 功耗数据可证（见 ppa-report §6）。故：**实现选择应按消费者约束决定**，
`coverage.yaml`/`profiles.yaml` 中的 `support` 保持 `experimental`，不因单次表征升级支持级别。

## 7. 验证策略映射

| REQ | 属性/测试 | 形式 |
|---|---|---|
| REQ-001 | PROP-PDF_SNAPSHOT-001 / PROP-PDF_CONSERVE-002、tc_sync_basic、tc_snapshot_hold、tc_random | SVA + 仿真 |
| REQ-002 | PROP-PDF_CONSERVE-002、tc_beat1、tc_pipe_stages | SVA + 仿真（参数化） |
| REQ-003 | PROP-PDF_BEATSEQ-003 / PROP-PDF_HOLDSTABLE-004、tc_backpressure | SVA + 仿真 |
| REQ-004 | PROP-PDF_LINKUP-005 / PROP-PDF_ERROR-006、tc_reset | SVA + 仿真 |
| REQ-005 | tc_negative_elab | 负向 elaboration（`$error`） |
| REQ-006 | 三实现等价：同参数跑 `SLICE_IMPL=0/1/2` 比对 | 仿真 + SVA |
| REQ-007/008 | 结构审查 + 参数域检查（无总线/CSR 端口、CDC 白名单） | 静态/评审 |
| REQ-009 | PPA 推理（本文 §6）+ 表征计划 | 分析（E0，未表征） |

异步模式（ASYNC_MODE=1）本轮提供结构实现与静态基线，`profiles.yaml` 标注 `experimental`；
其定向/随机回归列入后续工作（见资格报告剩余风险）。

## 8. 异步模式验证方案（ASYNC_MODE=1）

### 8.1 时钟比例策略（两时钟互质，避免锁相假象）

| 比例 | A 周期 : B 周期 | 覆盖意图 |
|---|---|---|
| A 快 B 慢 | 5 : 20（4×） | A 端长时间空转等待，B 端逐拍慢速推送；A 端背压随机 |
| A 慢 B 快 | 20 : 5（1/4×） | B 端快速连续推送，A 端接收能力受限 → 逼近 FIFO 容量边界 |
| A 慢 B 快（临界） | 11 : 20 | 用 `RSP_FIFO_DEPTH == BEAT_COUNT` 使 B 端写满一拍放不下 → 逼出 `reserve_ok` 门控 |
| 同频异相 | 10 : 10，相位偏置 0/3/7 | 同频但字节相位无关，检查相位差不影响结果 |

使用互质或非整数比的周期，避免两端长期锁相同相、掩盖跨域握手缺陷。

### 8.2 激励矩阵

| 用例 | 激励 | 判据 |
|---|---|---|
| `tc_async_modes` | 上表四种时钟比例，每比例 40 次事务，provider 延迟与 A 端背压随机 | 每次成功结果的 data 与被接受快照逐 bit 一致；无 timeout/协议错误 |
| `tc_async_modes`（临界） | `RSP_FIFO_DEPTH == BEAT_COUNT`、A 慢 B 快 | B 端不得在无空间时发送（`reserve_ok` 生效）；不出现 `ERR_FIFO` |
| `tc_async_reset_order` | ①B 复位→B 释放→A 复位→A 释放；②A 复位→A 释放→B 复位→B 释放；③两端同时复位、错开释放 | 复位期间 `a_link_up`/`b_link_up` 均为 0 且不接受请求；释放后 link_up 重新建立并完成新事务 |
| 时钟停摆 | A 时钟停止 N 拍后恢复 | B 端不得挂死；A 端恢复后 link_up 重建（或由 timeout 兜底） |

### 8.3 观测与相位纪律

- A 端域用 `@(negedge a_clk)` 驱动 / `@(posedge a_clk)` 观测；B 端数据源用 `@(posedge b_clk)` 驱动。
- 因两端频率不同，"每笔事务拍数"不是固定值；**不假设固定周期数**，只断言事务级性质（快照一致、无错误、link_up 语义）。
- 计数器/看门狗使用基于时间（`#`）而非拍数，防止慢时钟下误判挂死。

### 8.4 范围与限制

异步回归查出问题后，修复仅允许在既有 CDC 白名单结构内（toggle 同步器、Gray 指针 async FIFO、
`ASYNC_REG`）；不得为了通过而放宽断言或引入未经批准的结构。若发现问题需要改结构，
回 `design-cbb` 重新选型，不在验证阶段临时改微架构。