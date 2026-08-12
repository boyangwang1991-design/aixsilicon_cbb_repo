# Wrapper / Instance Generator

生成实例、适配 Wrapper、FuseSoC 依赖（架构文档 10.1 节，P1）。

## 规划功能

- 按 YAML 参数生成 CBB 实例与顶层 Wrapper
- 生成 FuseSoC Core（VLNV `aixsilicon:cbb:<name>:<version>`）与依赖声明
- 生成仿真/综合约束

## 状态

规划中（空工程包）。结构：`src/`、`tests/`、`docs/`。
