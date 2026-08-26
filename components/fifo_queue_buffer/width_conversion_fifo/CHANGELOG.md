# Changelog — width_conversion_fifo

## [0.1.0] - 2026-08-26 (candidate)

### Added
- 单时钟同步 FIFO + 整数比宽度转换（A2/A3，QUE-012）
- 参数化 RTL（`DIRECTION`/`NARROW_WIDTH`/`RATIO`/`DEPTH`）+ 共享契约 package
- SVA 断言：无丢失/无重复/保序/N2W 拼接/W2N 拆分/满空安全/计数不越界
- 非法参数 elaboration `$error` 拦截（PC-001..005）
- FuseSoC Core `aixsilicon:cbb:width_conversion_fifo:0.1.0`
- G3 静态基线：VCS compile/elab（N2W+W2N）、SpyGlass lint（0F/0E）、负向验证
- G4 功能验证：VCS 仿真（N2W 拼接/W2N 序列）、断言变异测试
- G5 配置集：mandatory/boundary/pairwise/negative
- 文档：intake/design/spec/qualification-report
- 证据：`evidence/g3_static/`、`evidence/g4_functional/`

### Known
- G6 PPA：`OPTIONAL_UNAVAILABLE`（无标准单元库/PDK，E0）
- 仅整数比；`DEPTH >= RATIO` 强制；宽侧位宽 ≤ 4096