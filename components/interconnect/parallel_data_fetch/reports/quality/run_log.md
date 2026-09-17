# CBB 运行日志（唯一）

- `2026-09-16 09:35:38` | **intake** | G0 | INT-001 注册：新建 components/interconnect 类别，CBB 边界判定与查重完成 | 结果(PASS)
    查重结论：与 stream_mux/stream_width_converter/stream_broadcaster/pipeline_fifo/bus_snapshot_cdc 契约均不同，新增条目。复用候选 toggle_synchronizer/async_fifo/parity_gen_check 中前两者仍为 planned 无实现，故内联同构私有实现并记录替换路径。
- `2026-09-16 09:35:39` | **design** | G2 | 双端点物理边界重构 + 设计论证落地 | 结果(PASS)
    用户指出需拆分为两个模块以便 SoC 跨区集成；据此将 RTL 拆为 requester/provider 端点 + 链路单元，async FIFO 因跨域无法归入单侧故为同级单元；新增 DOC-02 文档先行约束并同步 canonical SKILL。
- `2026-09-16 09:35:39` | **verify** | G3 | G3 静态基线：positive 21/21, negative 15/15 (VCS W-2024.09) | 结果(PASS)
- `2026-09-16 09:35:39` | **verify** | G4 | G4 功能：12/12 参数化用例，52 txn/case，bubbles=0 | 结果(PASS)
    修复过程记录：requester 的 link_req_o 悬空(x)导致 toggle 检测失效；TB 数据源 FSM 依赖 fetch_ready 当前值造成死锁；TB 提前拉低 rsp_ready 导致 HOLD 滞留；parity 注入与 BEAT_COUNT=1 竞争。均已修正并有回归证据。
- `2026-09-16 09:35:39` | **characterize** | G6 | G6 OPTIONAL_UNAVAILABLE：本机无可提交标准单元库快照，PPA 仅为结构推理(E0) | 结果(BLOCKED)
    未伪造门级数据；待库上下文具备后按 characterization/plan.yaml 运行。
- `2026-09-17 02:15:03` | **verify** | G4 | 异步双时钟回归 8/8（A快B慢/A慢B快/临界/同频异相相位0-3-7/互质/深FIFO） | 结果(PASS)
    根因：契约 §14 要求异步不得立即复用请求 toggle；原静默窗口按同步量级设定，导致 A 端错误后立即复用请求时 A=HOLD/B=IDLE 失配。修正：异步 QUIET_MAX 放大为 2*BEAT_COUNT+4*REQ_SYNC_STAGES+16（时序参数推导，不改外部接口）；同步窗口未变。另修正 TB 两处相位缺陷：等响应前多余 negedge 导致错拍漏消费；reset 场景 fork 内预置 rsp_ready 造成错拍。
- `2026-09-17 04:33:15` | **verify** | G5 | G5 Tier A 13/13 代表配置逐点仿真通过；发现并修复异步 pb_ready 接线缺陷 | 结果(PASS)
    缺陷：wrapper 把 pb_ready 接到 link_reserve_ok_i(每拍重估)，当 RSP_FIFO_DEPTH≈BEAT_COUNT 时突发中途停顿、丢 last → ERR_PROTOCOL(4)。修正：reservation 只在启动发送前门控(provider PV_WAIT_DATA 用 link_reserve_ok_i)，发送期改为 ~fifo_full。分层策略：Tier A(默认 13 点,4min) 留在 C4/G5 使 RTL 成为 C5 候选；Tier B(--full 32点) 建议 G6 后执行。实测单配置 ≈20.7s。
