# sync_fifo — QUE-001 Synchronous FIFO

## 需求说明

通用单时钟域同步 FIFO，写侧/读侧均为标准 ready/valid 握手（A2 通用复合构件，P0）。

- **保序**：输出顺序与写入顺序严格一致；
- **无丢失/无重复**：握手上 accepted 的数据不丢失、不重复输出；
- **满/空安全**：满时拒收（不覆盖），空时不输出，指针/计数不越界；
- **满吞吐**：连续 push/pop 下每拍 1 进 1 出；
- **可参数化**：`DATA_WIDTH`（两侧同宽）、`DEPTH`（深度≥2）、`OUTPUT_REG`
  （读侧输出寄存器级，切短输出路径）。

存储实现交综合工具推断（`impl_pointer_count` 自动适配 RAM/寄存器堆）；
本构件不提供 FWFT / CDC / 移位寄存器 / 专用 SRAM 封装 / 宽度转换
（分别归 QUE-003 / QUE-002 / QUE-004 / QUE-005 / QUE-012）。

## 位置

- SSOT：`cbb.yaml` / `behavior.yaml`（+`profiles.yaml`）
- 规格：`docs/cbb_spec.md`、`docs/intake.md`、`docs/design.md`
- 验证：`verification/`（plan/configs、simulation、assertions、formal）

VLNV：`aixsilicon:cbb:sync_fifo:<version>`
