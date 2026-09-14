#!/usr/bin/env bash
# 旧初始化入口已停用：历史实现会删除目录、覆盖配置并忽略校验失败。
set -euo pipefail
cat >&2 <<'NOTICE'
init_structure.sh 已退役，未修改任何文件。
仓库管理由 cbb-development-suite 负责。请按 docs/asset-management.md 维护 registry，
在 workflow 根通过 uv 运行 scripts/build_cbb_structure.py --check，随后刷新 README。
工程物化请使用开发套件的 scaffold/stage；历史脚本见 docs/archive/。
NOTICE
exit 2
