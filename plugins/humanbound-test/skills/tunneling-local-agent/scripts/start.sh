#!/usr/bin/env bash
# start.sh (humanbound-test) — orchestrates Step 4/6 of the test flow:
# detect → ngrok pre-check → server start → health → ngrok start → URL → state write.
# Emits structured progress lines (▸ / → / ✓ / ⚠) for the user.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../../../scripts/lib"
# shellcheck disable=SC1091
source "$LIB/log.sh"
# shellcheck disable=SC1091
source "$LIB/paths.sh"
# shellcheck disable=SC1091
source "$LIB/pidfile.sh"
# shellcheck disable=SC1091
source "$LIB/config.sh"
# shellcheck disable=SC1091
source "$HERE/providers/tunnel/ngrok.sh"

# 0. Append .humanbound/ to .gitignore on first run (idempotent).
ensure_gitignore_entry() {
  local project="$1" entry=".humanbound/"
  local gi="$project/.gitignore"
  [[ -f "$gi" ]] || return 0  # don't auto-create .gitignore — best-effort only.
  grep -qxF "$entry" "$gi" 2>/dev/null && return 0
  echo "$entry" >> "$gi"
}

PROJECT="$(pwd)"
echo "▸ Step 4/6  Starting tunnel"

# 1. Ensure config exists; auto-detect on first run.
if ! config_exists "$PROJECT"; then
  echo "  → no .humanbound/test/config.toml — running auto-detection"
  if ! python3 "$HERE/detect-server.py" "$PROJECT" --write; then
    log_error "no FastAPI detected. humanbound-test currently supports FastAPI projects only — see ROADMAP.md for the framework expansion plan."
    exit 1
  fi
fi

# 2. Read config.
SERVER_PROVIDER=$(config_get "$PROJECT" server.provider)
HOST=$(config_get "$PROJECT" server.host)
PORT=$(config_get "$PROJECT" server.port)
HEALTH_PATH=$(config_get "$PROJECT" server.health_path)
TUNNEL_PROVIDER=$(config_get "$PROJECT" tunnel.provider)
REGION=$(config_get "$PROJECT" tunnel.ngrok.region)

# 3. Duplicate-start guard.
if read_state "$PROJECT" >/dev/null 2>&1; then
  existing_sp=$(read_state "$PROJECT" | grep -o '"server_pid": [0-9]*' | awk '{print $2}')
  if [ -n "$existing_sp" ] && is_running "$existing_sp"; then
    url=$(read_state "$PROJECT" | grep -o '"public_url": "[^"]*"' | sed 's/.*: "//;s/"$//')
    echo "  ✓ tunnel already running for this project at $url"
    echo "$url"
    exit 0
  else
    echo "  ⚠ stale state file — cleaning up"
    clear_state "$PROJECT"
  fi
fi

# 4. Tunnel setup checks.
if [ "$TUNNEL_PROVIDER" = "ngrok" ]; then
  if ! ngrok_check_installed || ! ngrok_check_authed; then
    log_error "ngrok isn't ready. Run /humanbound-test:setup to install and configure it, then re-run /humanbound-test:run."
    exit 1
  fi
  echo "  ✓ ngrok ready  ·  region=${REGION:-us}"
fi

# 5. Start the server.
SERVER_LOG="$HB_TEST_LOG_DIR/server.log"
TUNNEL_LOG="$HB_TEST_LOG_DIR/tunnel.log"
: > "$SERVER_LOG"
: > "$TUNNEL_LOG"

case "$SERVER_PROVIDER" in
  fastapi)
    # shellcheck disable=SC1091
    source "$HERE/providers/server/fastapi.sh"
    ENTRY=$(config_get "$PROJECT" server.entry_point)
    MGR=$(config_get "$PROJECT" server.package_mgr)
    echo "  → starting uvicorn  …  (log: ${SERVER_LOG/$HOME/~})"
    ( fastapi_start "$PROJECT" "$ENTRY" "$HOST" "$PORT" "$MGR" >>"$SERVER_LOG" 2>&1 ) &
    SERVER_PID=$!
    ;;
  *)
    log_error "unsupported server provider: $SERVER_PROVIDER (only 'fastapi' is supported)"
    exit 1
    ;;
esac

# 6. Wait for server health.
if ! fastapi_health "$HOST" "$PORT" "$HEALTH_PATH"; then
  log_error "server didn't come up. Last log lines:"; tail -n 30 "$SERVER_LOG" >&2
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi
echo "  ✓ server up at http://$HOST:$PORT  (health $HEALTH_PATH)"

# 7. Start the tunnel.
BASIC_AUTH=$(config_get "$PROJECT" tunnel.ngrok.basic_auth)
DOMAIN=$(config_get "$PROJECT" tunnel.ngrok.domain)
echo "  → starting ngrok    …"
( ngrok_start "$PORT" "$BASIC_AUTH" "$DOMAIN" "${REGION:-us}" >>"$TUNNEL_LOG" 2>&1 ) &
TUNNEL_PID=$!

# 8. Fetch URL.
URL=$(ngrok_fetch_url || true)
if [ -z "$URL" ]; then
  log_error "tunnel didn't expose a URL. Last log lines:"; tail -n 30 "$TUNNEL_LOG" >&2
  kill "$SERVER_PID" "$TUNNEL_PID" 2>/dev/null || true
  exit 1
fi
echo "  ✓ public URL  :  $URL"

# 9. Persist state.
write_state "$PROJECT" "$SERVER_PID" "$TUNNEL_PID" "$URL" "$TUNNEL_PROVIDER"
ensure_gitignore_entry "$PROJECT"

# 10. Print warning + the URL on its own line for the skill to capture.
if [ -z "$BASIC_AUTH" ]; then
  echo
  echo "  ⚠ This URL is unauthenticated. Anyone with it can hit your agent."
  echo "    Set tunnel.ngrok.basic_auth in .humanbound/test/config.toml to add a password."
fi
echo
echo "$URL"
