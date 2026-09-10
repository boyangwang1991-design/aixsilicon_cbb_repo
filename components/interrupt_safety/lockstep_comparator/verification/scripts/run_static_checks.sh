#!/usr/bin/env bash
set -euo pipefail
command -v vcs >/dev/null
exec uv run --no-sync python "$(dirname "$0")/run_adversarial.py" "$@"
