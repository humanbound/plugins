#!/usr/bin/env bash
# session-end.sh — print a one-line reminder if a tunnel is still running.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../scripts/lib/paths.sh"

state="$HB_TEST_STATE_DIR/state.json"
[[ -f "$state" ]] || exit 0

# Extract public_url + tunnel.pid via python (state file is JSON).
python3 - "$state" <<'PY'
import json, os, sys
try:
    data = json.loads(open(sys.argv[1]).read())
except Exception:
    sys.exit(0)
# state.json (humanbound-test) is flat: server_pid, tunnel_pid, public_url at top level.
pid = data.get("tunnel_pid")
url = data.get("public_url", "")
if not pid:
    sys.exit(0)
# Is the pid alive?
try:
    os.kill(int(pid), 0)
except (OSError, PermissionError, ValueError):
    sys.exit(0)
print(f"⚠ humanbound-test: tunnel still running at {url}. Run /humanbound-test:stop to shut it down.")
PY
