# fifo_queue_buffer — FIFO、Queue 与 Buffer

对应 cbb_repo_list.md 第 7 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| QUE-001 | Synchronous FIFO | A2 | P0 | 深宽自动映射 |
| QUE-002 | Asynchronous FIFO | A2 | P0 | CDC正确性、深度限制 |
| QUE-003 | Fall-through FIFO | A2 | P0 | 首拍延迟与Ready路径 |
| QUE-004 | Shift-register FIFO | A2 | P1 | 小深度面积与翻转 |
| QUE-005 | SRAM FIFO | A2 | P1 | 读延迟隐藏 |
| QUE-006 | Elastic Buffer | A2 | P0 | 满吞吐与反压 |
| QUE-007 | Skid Buffer | A3 | P0 | 切断Ready组合链 |
| QUE-008 | Pipeline FIFO | A2/A3 | P1 | 物理距离与吞吐 |
| QUE-009 | Packet FIFO | A2 | P2 | 包边界和回滚 |
| QUE-010 | Frame Buffer Queue | A2 | P3 | 容量与元数据 |
| QUE-011 | Credit FIFO | A2/A3 | P1 | Credit一致性 |
| QUE-012 | Width-conversion FIFO | A2/A3 | P1 | 存储利用率与Mux |
| QUE-013 | Multi-channel FIFO | A2 | P2 | RAM共享与仲裁 |
| QUE-014 | Multi-enqueue FIFO | A2 | P2 | 写合并与指针更新 |
| QUE-015 | Multi-dequeue FIFO | A2 | P2 | 读端口与输出Mux |
| QUE-016 | Reorder Queue | A2 | P3 | 存储与比较功耗 |
| QUE-017 | Priority Queue | A2 | P3 | 延迟与容量 |
| QUE-018 | Descriptor Queue | A2 | P2 | 控制开销与访存 |
| QUE-019 | Replay/Retry Buffer | A2 | P3 | 状态容量和恢复延迟 |
| QUE-020 | Broadcast/Replication Buffer | A2/A3 | P2 | 数据复制与背压 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
