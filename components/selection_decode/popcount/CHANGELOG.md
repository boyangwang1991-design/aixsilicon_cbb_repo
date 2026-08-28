# Changelog

本组件遵循[语义化版本](https://semver.org/lang/zh-CN/)与 Keep a Changelog 规范。

## [0.1.0] - 2026-08-28

### Added

- 首次物化 popcount（SEL-014, A1/P1），纯组合人口统计/位计数。
- 五实现微架构（`PC_IMPL`）：
  - `0=direct` 直接加法基线（O(W) 级加法器链，PPA 参照基线）
  - `1=tree` 平衡归约树（O(log W) 级，全并行，时序最优）
  - `2=wallace` Wallace tree（3:2 FA + 2:1 HA 归约，`tools/gen_popcount.py` 生成）
  - `3=comp4_2` 4:2 compressor（cin/cout 列间链，`tools/gen_popcount.py` 生成）
  - `4=lut` 4bit 子块 LUT 查表 + 小加法树
- 生成器 `tools/gen_popcount.py`：按位宽显式展开 Wallace/compressor 扁平网表
  （rtl/gen/*.sv），结构可复现。
- 验证资产：G3 静态基线（compile/elab/lint/负向）+ G4 功能仿真
  （穷举 W4 + 边界 + 4000 随机 × W{8,16,32,64} × 五实现 + 多实现等价）。
- 参数约束 PC-001..004（elaboration 期 $error 拦截）。
