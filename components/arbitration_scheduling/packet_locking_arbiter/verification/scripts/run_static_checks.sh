#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v vcs >/dev/null
command -v spyglass >/dev/null
uv run --no-sync python verification/scripts/run_verification.py --phase negative "$@"
uv run --no-sync python verification/scripts/run_verification.py --phase lint "$@"
