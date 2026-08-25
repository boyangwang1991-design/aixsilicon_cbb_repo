# 快速上手

## 1. 初始化目录结构

```bash
bash scripts/init_structure.sh
```

脚本会：建立 components / adapters / templates / recipes / schemas / tools 框架、
按 [`cbb_repo_list.md`](../../cbb_repo_list.md:1) 生成每个 CBB 的空工程包 + 需求 README 占位与 `registry.yaml`、
生成 FuseSoC 脚手架（`fusesoc.conf`、CI）。可重复执行（幂等）。

## 2. 作为 FuseSoC Library 使用

```bash
fusesoc library add aixsilicon-cbb /path/to/aixsilicon_cbb_repo
fusesoc core list
fusesoc core show aixsilicon:cbb:async_fifo:0.1.0
fusesoc run --target sim aixsilicon:cbb:async_fifo:0.1.0
```

VLNV 格式：`<vendor>:<library>:<name>:<version>` = `aixsilicon:cbb:<cbb_name>:0.1.0`。

## 3. 新增一个 CBB

1. 在 [`cbb_repo_list.md`](../../cbb_repo_list.md:1) 对应章节补充一行（ID/构件族/实现变体/级别/优先级/PPA），
   然后运行 `bash scripts/init_structure.sh`（或 `python3 scripts/build_cbb_structure.py`）
2. 编辑生成的 `components/<category>/<功能名>/README.md`（如 `fifo_queue_buffer/sync_fifo`），补充需求说明
3. 开发 RTL 时按 [`docs/cbb_spec/README.md`](../cbb_spec/README.md:1) 展开标准工程包
4. 用工具链校验元数据与运行验证（见 [`tools/README.md`](../../tools/README.md:1)）

## 4. 目录导航

| 目录 | 说明 |
| --- | --- |
| [`components/`](../../components/README.md:1) | A1~A3 构件（17 类；发布时填充） |
| [`adapters/`](../../adapters/README.md:1) | A0 技术适配构件（发布时填充） |
| [`templates/`](../../templates/README.md:1) | A4 子系统模板（发布时填充） |
| [`recipes/`](../../recipes/README.md:1) | 参考架构与优化配方 |
| [`schemas/`](../../schemas/README.md:1) | 元数据与结果 Schema |
| [`tools/`](../../tools/README.md:1) | 工具链 |
| [`docs/architecture/`](../architecture/README.md:1) | 总体规划（V1.0） |
