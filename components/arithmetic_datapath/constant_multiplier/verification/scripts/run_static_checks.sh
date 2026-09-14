#!/usr/bin/env bash
set -euo pipefail
CM_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
command -v vcs
uv run --no-sync python "$CM_ROOT/verification/static.py"
