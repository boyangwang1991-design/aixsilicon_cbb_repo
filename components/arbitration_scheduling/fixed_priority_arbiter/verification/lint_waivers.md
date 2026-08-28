# Lint Waiver 记录（G3）— fixed_priority_arbiter

> SpyGlass `lint/lint_rtl` 结果：0 Fatal / 0 Error（证据：`build/eda/evidence/g3_static/lint.txt`，不入库）。
> 以下 warning/info 经评估为参数化结构/断言/`===` 比较的预期产物，非 RTL 缺陷，予以 waiver。

| Rule | 位置 | 说明 | 处置 |
|---|---|---|---|
| SYNTH_5064 | rtl/fixed_priority_arbiter.sv:115,118,120,123,132 | `assert` 语句不可综合，综合时忽略（SVA 仅验证期生效） | waiver（预期：断言为验证资产，不影响综合网表） |
| SYNTH_5058 | rtl/fixed_priority_arbiter.sv:131 | `===`（case 相等）综合视作 `==`；X 输入不作承诺（ASM-001），2-state 语义下等价 | waiver（预期：X 不承诺，`===` 用于断言内部判定） |
| SYNTH_5049 | rtl/fixed_priority_arbiter.sv（generate 参数化分支） | 未用参数化分支/实例（PC_IMPL 编译期分派） | waiver（预期：多实现同居，非选中分支被综合裁剪） |
| DetectTopDesignUnits | rtl/fixed_priority_arbiter.sv:18 | top 模块识别（wrapper 为综合/仿真顶层） | info（预期） |

## Waiver 归属

- Owner：rtl-owner（aixsilicon:cbb）
- 范围：断言（SVA）、`===` 比较、generate 参数化裁剪、顶层识别
- 失效条件：改用 X 可观测综合语义 / 移除断言后复审
