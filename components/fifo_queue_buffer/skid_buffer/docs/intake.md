# Intake（C0）— skid_buffer

> 结论：实现 vld rdy 接口的打拍模块 → 登记为 `aixsilicon:cbb:skid_buffer`（QUE-007）。

## 1. 任务

用户需求：实现 valid-ready 接口的**打拍模块**（pipeline stage / register slice），
在数据通路插入打拍以改善时序。经确认实现 **skid buffer**（1 槽缓冲切断 ready 组合链，
满吞吐无气泡）。

## 2. CBB/IP 边界判定（domain-rules §1）

| 判定项 | 结论 |
|---|---|
| 无软件可见 CSR / 独立地址空间 | ✅ CBB |
| 无独立驱动/固件/复杂系统状态机 | ✅ CBB（两级寄存器控制，无事务状态机） |
| 主要通过参数和端口定制 | ✅（`DATA_W`） |
| 被多 IP/SoC 作为内部模块复用 | ✅（任何 valid-ready 通路时序打拍） |
| 差异体现为宽度/级数/策略 | ✅（宽度参数化） |

→ **CBB（A3 协议构件）**，不触发 ip/hwif/vip 套件。

## 3. 查重（registry.yaml / Catalog）

- `QUE-007 skid_buffer`（`components/fifo_queue_buffer/skid_buffer`，A3/P0，planned）——**命中**；
- 相邻候选：`STR-004 forward_register_slice`（打拍 data/valid，ready 组合透传）、
  `STR-006 full_register_slice`（双向切时序）——均为 planned；本构件与 skid 语义完全对齐。
- **结论**：复用已登记条目 QUE-007，本次将其物化为标准工程包（planned → implemented）。

## 4. 嵌套依赖解析（composition）

skid_buffer 为独立 A3 构件，**无运行时子 CBB 依赖**（`implementations[].dependencies[] = []`），
无委派需求。

## 5. Owner / 消费者 / 风险

- **Owner**：`aixsilicon:cbb`（rtl-owner）
- **消费者**：使用 valid-ready 接口做时序打拍的 IP/SoC 集成（SoC 集成套件下游）
- **风险级别**：P0（基础时序构件，被广泛复用）
- **非目标**：BYPASS 直通（STR-007）、多级打拍（QUE-008）、fall-through 输出

## 6. 执行模式

`partial-task`（Fast/Standard Loop 之间）：契约 → RTL → G3/G4 验证 → config-gen（G5）。
G6 PPA 依 PDK 扫描结果执行（VCS/DC 本机可用）。
