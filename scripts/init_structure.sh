#!/usr/bin/env bash
#
# init_structure.sh — 初始化 CBB 平台（FuseSoC 仓库）目录骨架
#
# 用法:
#   bash scripts/init_structure.sh
#
# 说明:
#   - 本仓库是 FuseSoC Library，布局遵循 iprepo-management-suite 统一仓规范
#   - 顶层形态：components/（已交付 CBB 工程包）+ fusesoc.conf + registry.yaml
#   - registry.yaml 为交付件唯一 SSOT；scripts/build_cbb_structure.py 做一致性校验
#   - 每个已实现 CBB 目录以功能名命名，含 cbb.yaml + RTL + verification + evidence
#   - 脚本可重复执行（幂等）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VENDOR="aixsilicon"
LIBRARY="cbb"

echo "==> 初始化 CBB 平台（FuseSoC 仓库）目录骨架: $ROOT"

# --------------------------------------------------------------
# 0) 清理旧版结构（L0~L7 的 cbb/、subsystems、改名工具）
# --------------------------------------------------------------
if [ -d cbb ]; then
  echo "    移除旧版 cbb/（L0~L7 分层）..."
  rm -rf cbb
fi
# A4 子系统模板独立治理（templates/），不并入普通 CBB
rm -rf subsystems

# --------------------------------------------------------------
# 1) 顶层目录
# --------------------------------------------------------------
TOP_LEVEL=(
  adapters
  components
  reports/quality
  scripts
)
mkdir -p "${TOP_LEVEL[@]}"

# --------------------------------------------------------------
# 2) FuseSoC 脚手架
# --------------------------------------------------------------

# 6.1 fusesoc.conf —— 本仓库作为 FuseSoC Library
cat > fusesoc.conf <<EOF
# FuseSoC 库配置文件
# 本 CBB 平台仓库本身即一个 FuseSoC Library。
# 消费者使用: fusesoc library add aixsilicon-cbb <path 或 git-url>

[library.${VENDOR}-${LIBRARY}]
location = .
auto-sync = false
sync-uri = https://github.com/boyangwang1991-design/aixsilicon_cbb_repo.git
sync-type = git
sync-branch = main
EOF

# --------------------------------------------------------------
# 3) registry.yaml SSOT 一致性校验（只读；--rebuild-dirs 可重建缺失空目录）
# --------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/build_cbb_structure.py || true
else
  echo "警告: 未找到 python3，跳过 registry.yaml 校验"
fi

# --------------------------------------------------------------
# 4) 为空目录添加 .gitkeep（保证空目录可被 git 跟踪）
# --------------------------------------------------------------
find . \
  -type d -empty \
  -not -path "./.git/*" \
  -not -path "./.roo/*" \
  -not -path "*/.venv/*" \
  -not -path "*/.pytest_cache/*" \
  -exec touch "{}/.gitkeep" \;

echo "==> 完成。"
echo "    CBB 交付件 SSOT 见 registry.yaml；FuseSoC 库用法见 README.md"
