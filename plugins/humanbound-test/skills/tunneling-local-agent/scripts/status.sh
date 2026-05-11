#!/usr/bin/env bash
# status.sh (humanbound-test) — print state for the current project (or --all).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../../../scripts/lib"
# shellcheck disable=SC1091
source "$LIB/log.sh"
# shellcheck disable=SC1091
source "$LIB/paths.sh"
# shellcheck disable=SC1091
source "$LIB/pidfile.sh"

show_one() {
  local project="$1" state
  state=$(PROJECT="$project" bash -c "
    source \"$LIB/paths.sh\";
    source \"$LIB/pidfile.sh\";
    read_state \"$project\"
  " 2>/dev/null) || { echo "no tunnel for $project"; return 0; }
  echo "=== $project ==="
  printf '%s\n' "$state"
}

# State is always project-local. --all is preserved as a CLI alias but has
# nothing extra to scan; both modes operate on the cwd.
show_one "$(pwd)"
