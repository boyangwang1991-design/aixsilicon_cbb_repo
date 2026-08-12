# verification — 公共验证框架

跨 CBB 复用的公共验证基础设施（VIP、统一 Test Harness、Formal 框架）。

## 目录

| 目录 | 说明 |
| --- | --- |
| [`vip/`](vip/README.md:1) | 公共验证 IP（协议 VIP、参考模型） |
| [`harness/`](harness/README.md:1) | 统一 Test Harness 与约束模板 |
| [`formal/`](formal/README.md:1) | 公共 Formal / 断言框架 |

## 定位

- 为每个 CBB 的 `verification/`（common/simulation/formal/assertions）提供公共基础
- 支撑 G1~G3 质量门禁（功能、鲁棒性、可实现性）
- 由 `CBB Test Runner` 工具统一驱动（见 [`tools/README.md`](../tools/README.md:1)）

## 当前状态

各子目录为空（规划中）。质量门禁与验证要求见
[`docs/architecture/README.md`](../docs/architecture/README.md:1) 第 7.1 节。
