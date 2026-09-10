#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v vcs >/dev/null
uv run --no-sync python verification/scripts/run_verification.py --phase sim "$@"
uv run --no-sync python verification/scripts/run_verification.py --phase mutation "$@"
