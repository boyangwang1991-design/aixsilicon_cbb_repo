# HAC-AP-001 AP 到 HAC-CTRL Adapter

> 分组：HAC 接口适配（A3）　优先级：P0
> 状态：规划中（空工程包，仅需求说明）

## 需求说明

- 构件族：AP Control Adapter
- 主要实现变体：`ap_ctrl_hs`、`ap_ctrl_chain`
- PPA 关注点：轻量、低延迟、无额外缓冲

### 功能契约

| AP 信号 | HAC-CTRL 映射 |
|---|---|
| `ap_start` | `cmd_valid` 或 Shell 内部启动脉冲 |
| `ap_ready` | 命令可接收/启动已采样 |
| `ap_done` | 生成 `cpl_valid` |
| `ap_idle` | 映射到 `idle` |
| `ap_continue` | 对应完成接收或流水继续许可 |

兼容策略：

- 单任务 HLS 核可直接使用 `ap_ctrl_hs` Adapter；
- 流水链式核可使用 `ap_ctrl_chain` Adapter；
- `ap_ctrl_none` 核归入 Free-running 扩展，不伪造单任务完成语义；
- AP 接口没有 `job_id`，Adapter 必须限制为单任务，或由 Shell 建立顺序关联表。

### 成熟度

- [ ] E0 Concept
- [ ] E1 Functional
- [ ] E2 Verified
- [ ] E3 Characterized
- [ ] E4 Released

### PPA 表征计划

（待补充：基准环境、参数扫描计划）

> 开发时按 [docs/cbb_spec](../../../docs/cbb_spec/README.md) 展开标准工程包（rtl/interface、rtl/impl、verification、characterization 等）。
