# popcount 详设（C3）

五实现微架构详设：

| 实现 | 文档 | 关键点 |
|---|---|---|
| direct | [`direct.md`](direct.md) | O(W) 加法器链基线 |
| tree | [`tree.md`](tree.md) | O(log W) 平衡归约树 |
| wallace | [`wallace.md`](wallace.md) | 3:2 FA + 2:1 HA 归约（生成器） |
| comp4_2 | [`comp4_2.md`](comp4_2.md) | 4:2 compressor 列间链（生成器） |
| lut | [`lut.md`](lut.md) | 4bit 子块 LUT 查表 + 加法树 |

PPA 权衡汇总见 [`reports/ppa-report.md`](../../reports/ppa-report.md)。
