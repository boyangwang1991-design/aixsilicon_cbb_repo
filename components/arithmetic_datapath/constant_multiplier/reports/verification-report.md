# 验证报告

本报告由 verification/summarize.py 从实际工具结果生成，并核对当前 RTL、生成器、参考模型及生成 RTL 的哈希。状态为开发候选，未执行发布门禁转换。

| 检查 | 结果 | 证据 |
|---|---|---|
| VCS 完整回归 | 820 配置、230095 周期通过 | functional-results.json |
| 套件生成矩阵 | 140 配置、24930 周期通过 | matrix-results.json |
| PPA 参数组 RTL 对比 | 15 配置、3735 周期通过 | ppa-functional-results.json |
| 宿主非法配置与图变异 | 26 项通过 | 同上 |
| VCS 负向展开 | 8 项均以 CM-CONFIG 拒绝 | static-results.json |
| 数据损坏 / valid 丢失注入 | 两类均触发 CM-MISMATCH | functional-results.json 的 mutation 与日志哈希 |
| Formality | 9 个代表配置 proved | formal-results.json |

VCS W-2024.09-SP1；Formality V-2023.12-SP3。固定种子 914。小位宽穷举，大位宽端点和随机样本；比较生成结构、参数化 NATIVE 和独立任意精度 oracle。流水计分板在上升沿前采样输入，沿后检查，ce=0 保持、同步复位清空；连续有效、空泡、暂停、ce=0 复位与运行中复位均包含。L=0–8 覆盖，特殊常数不绕过延迟。

VCS 正向编译没有 Error-/Warning- 诊断。同步复位、暂停保持及有效输入未知值检查由 CM_ASSERTIONS 启用。FuseSoC sim 入口实际构建运行，默认 16 位输入穷举 65,536 个值通过 CM-SMOKE-PASS；原始日志位于 build/fusesoc/。

## 形式范围及未完成项

Formality 比较 BINARY/CSD/ADDER_GRAPH 对 NATIVE，覆盖 W8/C45/L0、W8/C-7/L1 的舍入饱和，以及 W128/C-1/L0。这些证明只属于列出的配置，不能外推整个参数域。

W8/C-7/L2 的跨级算术映射尝试未通过：初始内部寄存器匹配不具备相同数值含义，排除这些匹配后仍未建立输出寄存器的跨周期状态关系。原始诊断保留在 build/eda/formal/w8_k-7_l2_binary/formal.txt；该项保持 not_proved，不通过忽略输出比较点来掩盖失败。对应周期语义已通过独立 RTL 仿真，但无无界证明声明。

套件 pairwise 是有限采样，未穷尽全参数域，random 配置集为空（候选池超出工具上限）；随机数据覆盖不替代随机配置覆盖。真实消费者集成、物理实现、门级活动功耗及正式 qualification/release 尚未完成。性能结论见 ppa-report.md；未实施的指标明确标 unavailable。
