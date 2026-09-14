#!/usr/bin/env bash
# G3 静态基线（Compile/Elaboration/Lint/负向）— 按需填充
# 纪律：先探测原生工具（command -v vcs spyglass ...），再决定执行或 OPTIONAL_UNAVAILABLE；
#       VCS 在 build/eda/ 下运行（csrc 等产物进 build/），证据以 *.txt 落盘
#       build/eda/evidence/g3_static/（不入库；*.log 常被 .gitignore 忽略）。
set -euo pipefail
echo "TODO: 填充 G3 静态检查脚本（implement-cbb-rtl SKILL.md step 5）"
exit 10
