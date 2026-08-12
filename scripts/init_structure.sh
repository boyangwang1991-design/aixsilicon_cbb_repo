#!/usr/bin/env bash
#
# init_structure.sh — 初始化 CBB 平台（FuseSoC 仓库）目录骨架
#
# 用法:
#   bash scripts/init_structure.sh
#
# 说明:
#   - 本仓库是 FuseSoC Library，布局遵循 iprepo-management-suite 统一仓规范
#   - 顶层形态参考 plan.md 9.1 节：
#       components/  A1~A3 构件（按 cbb_repo_list.md 功能类别组织）
#       adapters/    A0 技术适配；templates/ A4 子系统模板（独立治理）
#       recipes/ 参考架构与优化配方；schemas/ 元数据 Schema；verification/ 公共验证框架
#       flows/ 表征/回归/发布流程；tools/ 工具链
#   - CBB 目录与 registry.yaml 由 scripts/build_cbb_structure.py 依据 cbb_repo_list.md 生成
#   - 每个 CBB 当前为「空工程包 + README 需求说明占位」
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
rm -rf tools/cbb_generator tools/ppa_characterization tools/ppa_regression

# --------------------------------------------------------------
# 1) 顶层目录
# --------------------------------------------------------------
TOP_LEVEL=(
  docs/architecture
  docs/ppa
  docs/cbb_spec/template
  docs/getting_started
  components
  adapters
  templates
  recipes
  schemas
  verification
  flows
  tools
  scripts
  tests
  examples
  .github/workflows
)
mkdir -p "${TOP_LEVEL[@]}"

# --------------------------------------------------------------
# 2) 参考架构与优化配方（recipes）
# --------------------------------------------------------------
RECIPES=(
  resource_sharing
  width_optimization
  fanout_optimization
  low_power
  high_performance
  storage_auto_selection
)
for r in "${RECIPES[@]}"; do
  mkdir -p "recipes/$r"
done

# --------------------------------------------------------------
# 3) 公共验证框架（verification）
# --------------------------------------------------------------
mkdir -p verification/vip verification/harness verification/formal

# --------------------------------------------------------------
# 4) 流程（flows）
# --------------------------------------------------------------
mkdir -p flows/characterization flows/regression flows/release

# --------------------------------------------------------------
# 5) 工具链（10 个，见 plan.md 10.1 节）
# --------------------------------------------------------------
TOOLS=(
  schema_validator        # P0
  cbb_test_runner         # P0
  characterization_runner # P0
  ppa_comparator          # P0
  catalog_builder         # P0
  cbb_selector            # P1
  wrapper_generator       # P1
  ppa_regression_bot      # P1
  rtl_pattern_scanner     # P2
  ai_ppa_advisor          # P2
)
for tool in "${TOOLS[@]}"; do
  mkdir -p "tools/$tool/src" "tools/$tool/tests" "tools/$tool/docs"
done

# --------------------------------------------------------------
# 6) FuseSoC 脚手架
# --------------------------------------------------------------

# 6.1 fusesoc.conf —— 本仓库作为 FuseSoC Library
cat > fusesoc.conf <<EOF
# FuseSoC 库配置文件
# 本 CBB 平台仓库本身即一个 FuseSoC Library。
# 消费者使用: fusesoc library add aixsilicon-cbb <path 或 git-url>

[library.${VENDOR}-${LIBRARY}]
location = .
auto-sync = false
# 发布后填写远程地址
# sync-uri = https://github.com/<org>/aixsilicon_cbb_repo.git
# sync-type = git
# sync-branch = main
EOF

# 6.2 GitHub Actions CI —— 扫描 *.core 做 FuseSoC lint
cat > .github/workflows/ci.yml <<'EOF'
name: FuseSoC Core Lint

on:
  push:
    paths: ["components/**", "adapters/**", "templates/**", "fusesoc.conf", "registry.yaml"]
  pull_request:
    paths: ["components/**", "adapters/**", "templates/**"]

jobs:
  fusesoc-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Install FuseSoC
        run: pip install fusesoc
      - name: Add CBB library
        run: fusesoc library add aixsilicon-cbb .
      - name: Lint all cores
        run: |
          set -e
          found=0
          for core in $(find components adapters templates -name '*.core' | sort); do
            coredir=$(dirname "$core")
            if ! compgen -G "${coredir}/../rtl/impl/*.sv" >/dev/null 2>&1; then
              echo "skip (no RTL yet): ${core}"
              continue
            fi
            vlnv=$(grep -m1 '^name:' "$core" | awk '{print $2}')
            echo "== lint ${vlnv} =="
            fusesoc core lint "$vlnv"
            found=1
          done
          [ "$found" -eq 0 ] && echo "No RTL cores yet - nothing to lint"
EOF

# --------------------------------------------------------------
# 7) 依据 cbb_repo_list.md 生成 CBB 目录 + registry.yaml
# --------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/build_cbb_structure.py
else
  echo "警告: 未找到 python3，跳过 CBB 目录与 registry.yaml 生成（请手动运行 scripts/build_cbb_structure.py）"
fi

# --------------------------------------------------------------
# 8) 为空目录添加 .gitkeep（保证空目录可被 git 跟踪）
# --------------------------------------------------------------
find . \
  -type d -empty \
  -not -path "./.git/*" \
  -not -path "./.roo/*" \
  -not -path "*/.venv/*" \
  -not -path "*/.pytest_cache/*" \
  -exec touch "{}/.gitkeep" \;

echo "==> 完成。"
echo "    CBB 清单见 cbb_repo_list.md；FuseSoC 用法见 docs/getting_started/README.md"
