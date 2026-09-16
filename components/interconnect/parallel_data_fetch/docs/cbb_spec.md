# 规格（派生视图）— parallel_data_fetch

> 本文是 [`../cbb.yaml`](../cbb.yaml) / [`../behavior.yaml`](../behavior.yaml) / [`../profiles.yaml`](../profiles.yaml)
> 的可读派生视图；**YAML 为唯一事实源**，两者不一致时以 YAML 为准。本文不引入新实现要求、不更新 Gate。

## 1. 定位

单次请求的远端宽数据原子快照经窄链路连续回传并在请求端重组，以传输时延换取长距布线资源。
单 outstanding；同步/异步两种时钟模式使用完全相同的 A/B 业务接口。

## 2. 公开模块与端口

| 模块 | 位置 | 说明 |
|---|---|---|
| `parallel_data_fetch_requester` | A 端 | 业务请求/结果 + 链路请求与返回 beat 接口 |
| `parallel_data_fetch_provider` | B 端 | 业务取数/数据 + 链路请求与 beat 发送接口 |
| `pdf_async_fifo` | A/B 之间 | 异步返回 beat 跨域单元（写端口 B 域、读端口 A 域） |
| `parallel_data_fetch` | 仿真/同层集成封装 | 内部实例化上述三者，窄链路为内部连接 |

### 2.1 Requester（A 端）

| 信号 | 方向 | 宽度 | 说明 |
|---|---|---|---|
| `a_clk_i` / `a_rst_ni` | in | 1 | A 域时钟 / 低有效异步复位、同步释放 |
| `a_req_valid_i` / `a_req_ready_o` | in/out | 1 | 请求握手（`req_fire = valid && ready`） |
| `a_rsp_valid_o` / `a_rsp_ready_i` | out/in | 1 | 结果握手 |
| `a_rsp_data_o` | out | DATA_WIDTH | 完整重组结果（失败时为 RESET_VALUE 语义值） |
| `a_rsp_error_o` / `a_rsp_error_code_o` | out | 1 / 3 | 失败标志与错误码 |
| `a_busy_o` / `a_link_up_o` | out | 1 | 存在未完成事务 / 链路可用 |
| `link_req_o` | out | 1 | 请求事件（异步模式为 toggle 编码，A 域） |
| `link_a_alive_o` | out | 1 | A 端存活指示 |
| `link_b_alive_i` | in | 1 | B 端存活指示（异步模式在 A 域同步后判稳） |
| `link_rsp_valid_i` / `link_rsp_last_i` / `link_rsp_error_i` / `link_rsp_parity_i` / `link_rsp_epoch_i` | in | 1 | 来自 async FIFO 读端的 beat bundle 控制 |
| `link_rsp_data_i` | in | LINK_WIDTH | beat 数据 |
| `link_rsp_pop_o` | out | 1 | FIFO 读使能（接收/排空窗口） |

### 2.2 Provider（B 端）

| 信号 | 方向 | 宽度 | 说明 |
|---|---|---|---|
| `b_clk_i` / `b_rst_ni` | in | 1 | B 域时钟 / 复位 |
| `b_fetch_valid_o` / `b_fetch_ready_i` | out/in | 1 | 向本地数据源发起取数 |
| `b_data_valid_i` / `b_data_ready_o` | in/out | 1 | 数据接受握手（同拍锁存整份快照） |
| `b_data_i` / `b_data_error_i` | in | DATA_WIDTH / 1 | 数据源内容 / 错误指示 |
| `b_busy_o` / `b_link_up_o` | out | 1 | 处理中 / 链路可用 |
| `link_req_i` | in | 1 | 请求事件/toggle（B 域） |
| `link_a_alive_i` / `link_b_alive_o` | in/out | 1 | 对端存活 / 本地存活 |
| `link_beat_valid_o` / `link_beat_last_o` / `link_beat_error_o` / `link_beat_parity_o` / `link_beat_epoch_o` | out | 1 | beat bundle 控制（B 域，直连 async FIFO 写端口） |
| `link_beat_data_o` | out | LINK_WIDTH | beat 数据 |
| `link_beat_ready_i` | in | 1 | 下游可接受 beat（FIFO 未满） |
| `link_reserve_ok_i` | in | 1 | FIFO 剩余空间 ≥ BEAT_COUNT（transaction reservation） |

## 3. 参数（合法域摘要）

| 参数 | 默认 | 合法域 | 语义要点 |
|---|---:|---|---|
| `DATA_WIDTH` | 256 | 8–4096 | 快照与重组宽度 |
| `LINK_WIDTH` | 32 | 1–256，且 `DATA_WIDTH % LINK_WIDTH == 0` | 窄链路宽度；`BEAT_COUNT = DATA_WIDTH/LINK_WIDTH` |
| `LSB_FIRST` | 1 | 0/1 | 切片顺序（低位优先/高位优先） |
| `ASYNC_MODE` | 0 | 0/1 | A/B 是否异步时钟域 |
| `PARITY_EN` / `ODD_PARITY` | 1 / 0 | 0/1 | 每 beat 校验及其极性 |
| `TIMEOUT_EN` / `TIMEOUT_CYCLES` | 1 / 1024 | 0/1；8–1048576 且 > BEAT_COUNT | A 端等待上限 |
| `REQ_SYNC_STAGES` | 2 | 2–4 | 跨域同步级数 |
| `RSP_FIFO_DEPTH` | 16 | 2 的幂；异步时 ≥ BEAT_COUNT | 异步返回 FIFO 深度 |
| `LINK_PIPE_STAGES` | 0 | 0–8（仅同步模式） | 长线 bundle 流水级数 |
| `SLICE_IMPL` | 2 | 0/1/2 | 切片微架构 shift/indexed/banked |
| `RESET_DEFAULT_DATA` | 0 | 0/1 | 失败/复位输出数据值（全 0/全 1） |

全部非法组合（不整除、宽度越界、异步深度不足、超时窗口过小、同步级数不足、切片编码越界、
异步模式禁用 pipeline 等）由 RTL `generate` 内 `$error` 在 **elaboration 阶段**拒绝；
约束 ID 与表达式见 [`../cbb.yaml`](../cbb.yaml) 的 `constraints`（PC-001～PC-011）。

## 4. 行为要点（不变量与异常）

- **INV-001 单 outstanding**：请求被接受后至结果被消费前不再接受新请求；
- **INV-002 原子快照**：快照仅在 `b_data_valid_i && b_data_ready_o` 当拍锁存，发送期间不变；
- **INV-003 连续发送**：payload 连续 `BEAT_COUNT` 拍无 bubble，`last` 仅在末拍；
- **INV-004 全或无**：仅在收齐且校验通过后输出结果，失败输出 RESET_VALUE 语义值；
- **INV-005 输出稳定**：`a_rsp_valid_o && !a_rsp_ready_i` 期间 data/error/code 恒定；
- **INV-006 epoch 隔离**：单 bit 代际丢弃超时/恢复后的迟到数据；
- **INV-007 link_up 门控**：两端 alive 稳定后 `link_up=1`，否则不接受请求；
- **INV-008 FIFO 容量**：异步 provider 仅在 `free >= BEAT_COUNT` 时连续发送，不 overflow。

错误码与优先级（多错误合并）：`ERR_NONE(0)`、`ERR_TIMEOUT(1)`、`ERR_PROVIDER(2)`、
`ERR_PARITY(3)`、`ERR_PROTOCOL(4)`、`ERR_REMOTE_RESET(5)`、`ERR_FIFO(6)`、`ERR_INTERNAL(7)`；
优先级 `REMOTE_RESET > FIFO > INTERNAL > PROTOCOL > PARITY > PROVIDER > TIMEOUT`。
错误只经 A 端 response 握手返回，不产生中断、不写软件寄存器。

## 5. 时钟与复位

- 两端口复位可独立断言、异步断言同步释放；
- `ASYNC_MODE=0`：A/B 连接同一时钟，返回 bundle 经 `LINK_PIPE_STAGES` 级同级流水；
- `ASYNC_MODE=1`：请求 toggle 与 alive 用 `REQ_SYNC_STAGES` 级同步器；返回 beat 经 Gray 指针
  async FIFO；同步器/指针寄存器带 `ASYNC_REG`；
- 任一端复位使 `link_up` 失效；事务中对端复位返回 `ERR_REMOTE_RESET`，不自动重发。

## 6. 非目标

见 [`intake.md`](intake.md) §6 与 [`../behavior.yaml`](../behavior.yaml) 的 `non_goals`。
