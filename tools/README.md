# 工具链

支撑 CBB 平台四个支撑平面的工具（架构文档第 10.1 节）。当前均为空工程包（规划中）。

## 工具清单

| 工具 | 优先级 | 目录 | 职责 |
| --- | --- | --- | --- |
| Schema Validator | P0 | [`schema_validator/`](schema_validator/README.md:1) | 校验元数据、参数域、依赖和发布信息 |
| CBB Test Runner | P0 | [`cbb_test_runner/`](cbb_test_runner/README.md:1) | 统一运行 Lint/仿真/Formal/CDC/综合 |
| Characterization Runner | P0 | [`characterization_runner/`](characterization_runner/README.md:1) | 参数采样、综合、STA、功耗、结果归档 |
| PPA Comparator | P0 | [`ppa_comparator/`](ppa_comparator/README.md:1) | 跨实现/参数/版本比较，生成 Pareto 前沿 |
| Catalog Builder | P0 | [`catalog_builder/`](catalog_builder/README.md:1) | 从发布包构建可查询索引 |
| CBB Selector | P1 | [`cbb_selector/`](cbb_selector/README.md:1) | 硬约束过滤、候选排序、理由输出 |
| Wrapper/Instance Generator | P1 | [`wrapper_generator/`](wrapper_generator/README.md:1) | 生成实例、适配 Wrapper、FuseSoC 依赖 |
| PPA Regression Bot | P1 | [`ppa_regression_bot/`](ppa_regression_bot/README.md:1) | 检测退化和 Pareto 变化 |
| RTL Pattern Scanner | P2 | [`rtl_pattern_scanner/`](rtl_pattern_scanner/README.md:1) | 识别可替换热点并匹配 CBB |
| AI PPA Advisor | P2 | [`ai_ppa_advisor/`](ai_ppa_advisor/README.md:1) | 解释热点、生成方案并驱动闭环 |

## 使用原则

- 每个工具采用标准工程包结构（`src/`、`tests/`、`docs/`）
- **规则驱动**：脚本只做确定性操作；判断/权衡由人（或 AI）按规则执行
- AI 适合：需求转约束、热点解释、候选搜索、Recipe 匹配、参数建议、报告生成
- 确定性工具负责：代码生成、Schema 校验、综合、STA、功耗、形式验证和 Gate 判定
- 最终选择必须由工具证据闭环
