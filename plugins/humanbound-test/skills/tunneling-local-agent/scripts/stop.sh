#!/usr/bin/env bash
# stop.sh (humanbound-test) — stop the server + tunnel for the current project (or --all).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../../../scripts/lib"
# shellcheck disable=SC1091
source "$LIB/log.sh"
# shellcheck disable=SC1091
source "$LIB/paths.sh"
# shellcheck disable=SC1091
source "$LIB/pidfile.sh"

stop_one() {
  local project="$1" state
  state=$(PROJECT="$project" bash -c "
    source \"$LIB/paths.sh\";
    source \"$LIB/pidfile.sh\";
    read_state \"$project\"
  " 2>/dev/null) || { echo "no tunnel for $project"; return 0; }
  local sp tp
  sp=$(printf '%s' "$state" | grep -o '"server_pid": [0-9]*' | awk '{print $2}')
  tp=$(printf '%s' "$state" | grep -o '"tunnel_pid": [0-9]*' | awk '{print $2}')
  for pid in "$sp" "$tp"; do
    [ -n "$pid" ] || continue
    if is_running "$pid"; then
      kill "$pid" 2>/dev/null || true
      for _ in $(seq 1 10); do
        is_running "$pid" || break
        sleep 0.5
      done
      is_running "$pid" && kill -9 "$pid" 2>/dev/null || true
    fi
  done
  PROJECT="$project" bash -c "
    source \"$LIB/paths.sh\";
    source \"$LIB/pidfile.sh\";
    clear_state \"$project\"
  "
  echo "stopped tunnel for $project"
}

# State is always project-local. --all is preserved as a CLI alias but has
# nothing extra to scan; both modes operate on the cwd.
stop_one "$(pwd)"
