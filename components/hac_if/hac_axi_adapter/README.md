# HAC-AXI-001 HAC-MEM 到 AXI Adapter

> 分组：HAC 接口适配（A3）　优先级：P1
> 状态：规划中（空工程包，仅需求说明）

## 需求说明

- 构件族：HAC-MEM → AXI4 Master Adapter
- 主要实现变体：read engine / write engine / combined
- PPA 关注点：Outstanding 深度、Burst 效率、4KB 切分开销、延迟

### 功能契约

- 生成 AXI `AR/AW/W` 通道；
- 请求切分及合并；
- 处理 4 KB 边界；
- 限制最大 Burst 长度；
- `tag` 到 AXI ID 的映射；
- AXI 响应重排和回压；
- 非对齐访问转换（可选）；
- Outstanding 限流；
- AXI 属性映射；
- `RRESP/BRESP` 到 HAC 状态码转换；
- 超时、孤儿响应和协议错误检测；
- 可选宽度转换、寄存切片和 CDC。

### 成熟度

- [ ] E0 Concept
- [ ] E1 Functional
- [ ] E2 Verified
- [ ] E3 Characterized
- [ ] E4 Released

### PPA 表征计划

（待补充：基准环境、参数扫描计划）

> 开发时按 [docs/cbb_spec](../../../docs/cbb_spec/README.md) 展开标准工程包。
