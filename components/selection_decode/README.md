# selection_decode — 基础位操作、编码与选择网络

对应 cbb_repo_list.md 第 3 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| SEL-001 | 2:1/N:1 Binary Mux | A1 | P0 | 扇入、逻辑深度、毛刺 |
| SEL-002 | One-hot Mux | A1 | P0 | One-hot假设、扇出、X处理 |
| SEL-003 | Priority Mux | A1 | P1 | 优先级链与规模扩展 |
| SEL-004 | Sparse/Masked Mux | A1 | P2 | 无效输入消除、综合稳定性 |
| SEL-005 | Cross-point Switch | A2 | P2 | 交叉规模、布线与流水 |
| SEL-006 | Binary Encoder | A1 | P0 | 位宽与深度 |
| SEL-007 | One-hot Encoder | A1 | P0 | 非法输入语义 |
| SEL-008 | Decoder | A1 | P0 | 高扇出、本地译码 |
| SEL-009 | Priority Encoder | A1 | P0 | 深优先级链 |
| SEL-010 | Thermometer Encoder/Decoder | A1 | P3 | 编码密度与毛刺 |
| SEL-011 | Leading Zero/One Count | A1 | P1 | 关键路径、前缀结构 |
| SEL-012 | Trailing Zero/One Count | A1 | P2 | 共享反转逻辑 |
| SEL-013 | Bit Scan/First-set | A1 | P1 | 大位宽时序 |
| SEL-014 | Population Count | A1 | P1 | 面积/时序Pareto |
| SEL-015 | One-hot Checker | A1 | P0 | 安全检查复用 |
| SEL-016 | Range Comparator | A1 | P1 | 共享比较与译码 |
| SEL-017 | Address Decoder | A2 | P0 | 比较器共享、扇出 |
| SEL-018 | Hierarchical Address Decoder | A2 | P1 | 大规模地址空间时序 |
| SEL-019 | Configurable Truth Table | A1 | P3 | 面积与综合推断 |
| SEL-020 | Bit Permutation Network | A2 | P3 | 布线主导、配置代价 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
