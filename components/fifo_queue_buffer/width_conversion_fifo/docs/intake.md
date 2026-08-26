# Intake 结论（G0）— width_conversion_fifo

> CBB 生命周期 G0 Intake 记录。任务 ID：AIX-CBB-0101
> 参考：`cbb_repo_list.md` §7 QUE-012、`registry.yaml`、domain-rules §1。

## 1. CBB / IP 边界判定（domain-rules §1）

| 判定维度 | 结论 |
|---|---|
| 软件可见 CSR / 独立地址空间 | 无（纯数据通路 + ready/valid 接口） |
| 独立驱动 / 固件 / 复杂系统状态机 | 无（单时钟，简单指针/gearbox 状态） |
| 参数化与端口定制 | 是（NARROW_WIDTH / RATIO / DEPTH / DIRECTION） |
| 被多 IP/Subsystem 复用 | 是（SoC 数据通路、DMA 与协议适配常用） |
| 行为契约 + 有限属性可描述 | 是（FIFO 不变量 + 宽度转换对齐语义） |

**结论：CBB**，归属 `components/fifo_queue_buffer/`（QUE 构件族，FIFO/Queue/Buffer 域），抽象粒度 `A2/A3`（协议无关复合构件 + ready/valid 语义）。

## 2. 查重

- `registry.yaml` QUE-012 `width_conversion_fifo` 已登记（status: `planned`，P1，A2/A3），无重复构件；
- 相邻构件边界：QUE-001 `sync_fifo`（无宽度转换）、STR-014 `stream_width_converter`（纯转换非存储）、QUE-012（FIFO + 宽度转换组合）。边界清晰，无语义重叠。

## 3. Owner / 消费者 / 风险

| 项 | 值 |
|---|---|
| Owner | `aixsilicon:cbb`（rtl-owner / dv-owner / ppa-owner 联合） |
| 消费者（Use Case） | ① 窄总线→宽存储写端口（NARROW_TO_WIDE）；② 宽读端口→窄总线分拍（WIDE_TO_NARROW）；③ DMA/协议适配数据整形 |
| 风险级别 | P1（协议无关、单时钟；gearbox 复杂度为 P2 后续） |
| 非目标 | 非整数比 gearbox、异步/多时钟域、乱序、QoS/仲裁 |

## 4. 支持范围声明（本版本 v0.1.0）

- 仅支持**整数比**宽度转换（RATIO = 宽侧/窄侧 为 ≥2 整数）；
- 单时钟域、同步复位；
- FIFO 深度以**窄字**为单位；窄→宽 输出需凑齐 RATIO 个窄字，宽→窄 输入一次写宽字、分 RATIO 拍输出窄字。

## 5. EDA 工具链（本机可用，实测确认）

| 工具 | 版本 | 用途 |
|---|---|---|
| VCS | W-2024.09-SP1 | 编译/Elaboration/仿真/断言（SVA） |
| Design Compiler (dc_shell) | V-2023.12-SP3 | 综合 + PPA 表征 |
| Formality (fm_shell) | V-2023.12-SP3 | 等价性检查 |
| SpyGlass | X-2025.06 | Lint / CDC / RDC |
| Verdi | W-2024.09-SP1 | 波形调试 |

> 注：`aix tool cbb-*` 注册 action 域未装（workflow 侧插件缺失，返回 OPTIONAL_UNAVAILABLE），
> 但原生 EDA 工具完整可用，验证直接调用上述工具，不降级为纯参考模型冒烟。

## 6. 结论

- 进入 C1（specify-cbb）：编写 `cbb.yaml` / `params.yaml` / `behavior.yaml`；
- 执行深度：**Standard Loop**（新 CBB，覆盖边界参数 + Formal/轻量随机仿真 + 代表点 PPA Sweep）；
- 验证路径：VCS 仿真 + SVA 断言 / SpyGlass Lint / DC 综合 PPA / Formality 等价。
