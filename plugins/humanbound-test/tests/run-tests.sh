#!/usr/bin/env bash
# Local test runner. Use plain `bats` if installed; otherwise skip.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ pytest"
( cd "$HERE/.." && python3 -m pytest tests/python -v )

if command -v bats >/dev/null 2>&1; then
  echo "→ bats"
  bats "$HERE/bash"
else
  echo "⚠ bats not installed — skipping bash tests. Install with: brew install bats-core"
fi
