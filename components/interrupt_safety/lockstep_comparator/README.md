# SAF-005 锁步比较逻辑 CBB

`lockstep_comparator` 是单时钟 Main/Shadow 锁步观测构件，RTL 顶层为 `lockstep_comparator_logic`。
版本目标 1.0.0；已完成本地实现与验证，仍为 `needs_verification` 候选，尚未进行发布和物理安全签核。

## 功能

- 支持 0～N 周期 Main 延迟及额外启动保护周期。
- 支持单比较器、共享延迟双比较器、完整双路径三级配置。
- 支持静态、运行时与有效位掩码，以及比较使能/两路活动限定。
- 分别报告 Main/Shadow 差异和 LCL 内部故障，提供 sticky、脉冲、位向量和 fail-safe 汇总。
- 支持 A/B 比较与延迟路径注入，以及可选一级比较结果流水。

默认 WIDTH=32、延迟 2、冗余 Level 2、无比较输出流水；三种可选功能默认开启。
参数与接口事实见 [cbb.yaml](cbb.yaml)、[原始合约](../SAF-005-CONTRACT.MD)。

## 文档与证据

- [实现规格](docs/cbb_spec.md)：时序、掩码、清除优先级和注入编码。
- [架构](docs/design.md)与[详细设计](docs/detail-design/impl_redundant.md)。
- [验证报告](reports/verification-report.md)：配置、用例、负向/变异、等价和构建结果。
- [PPA 报告](reports/ppa-report.md)：固定库下的 8 点面积、时序、功耗及对比图。
- [集成说明](docs/integration.md)与[支持边界](reports/qualification-report.md)。

## 复现

以下命令从工程包目录执行，使用已配置的 Python/uv 环境、PyYAML 与 VCS；EDA 运行需要可用许可证。

```bash
uv run --no-sync python verification/scripts/run_checks.py
uv run --no-sync python verification/scripts/run_adversarial.py
uv run --no-sync python verification/scripts/check_negative_configs.py
uv run --no-sync python verification/scripts/run_core.py
uv run --no-sync python characterization/scripts/run_synthesis.py
uv run --no-sync python characterization/scripts/run_synthesis.py --extra
```

综合依赖本机 `build/eda/pdk.local.yaml` 的库快照。运行后将实际综合目录传给
`verification/scripts/run_formal.py` 和 `characterization/scripts/extract_ppa.py`。
精确路径、商业库和原始日志保留在忽略的 build 目录，公开摘要只包含参数、指标与 hash。
FuseSoC Core 可独立导出构建，公开包不依赖私有 skill。
