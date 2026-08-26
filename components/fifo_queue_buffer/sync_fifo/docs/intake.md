# QUE-001 sync_fifo — Intake（G0）

## 边界判定（CBB vs IP）

- 无 CSR/软件契约、无系统级生命周期；参数与端口高度可定制（宽度/深度/输出寄存），
  被多 IP/子系统复用 → **CBB（A2）**。
- 单时钟域同步握手 FIFO，不涉及多时钟异步机制 → 非 CDC 白名单结构，可参数化实现。

## 查重（registry.yaml / Catalog / cbb_repo）

| 条目 | 结论 |
|---|---|
| QUE-003 Fall-through FIFO | 不同构件：无 FWFT 直通语义；本构件为标准弹出时序 |
| QUE-004 Shift-register FIFO | 不同构件：本构件存储由综合推断，非纯移位寄存器 |
| QUE-005 SRAM FIFO | 不同构件：本构件不例化/封装专用 SRAM |
| QUE-012 width_conversion_fifo | 同族已存在：含宽度转换与 RATIO 死锁约束；本构件无宽度转换 |
| 仓库内同名 `sync_fifo` | 不存在 → 新建 |

**结论：新增**，边界清晰，无功能重叠。

## 消费者与场景

- 写侧 producer / 读侧 consumer 同时钟域，需要按序缓冲、背压与满吞吐；
- `OUTPUT_REG=1` 用于高频路径切短输出时序；`OUTPUT_REG=0` 用于延迟/面积敏感场合。

## 风险与成熟度

- 风险等级 **P0**（基础构件被广泛复用）；成熟度起始 **E0**，目标经 G1~G4 升 **E1**；
- 主要风险：读侧输出时序（寄存级选择）、大深度下存储推断差异 —— 由 G3 静态基线/
  G4 Functional（Formal 覆盖）消解。

## Owner / 审批

- Owner：`aixsilicon:cbb`；approvals：rtl-owner（RTL 修改）、dv-owner（验证计划）。