#!/usr/bin/env bash
# start-mcp.sh — launch `hb mcp` with PATH augmented for sandboxed harnesses.
#
# Some editor harnesses (Cursor's Bash tool, certain MCP server launchers)
# spawn child processes with a stripped PATH and sometimes empty HOME. This
# wrapper resolves both before exec'ing `hb mcp`.

# NOTE: intentionally NOT using `set -u` — HOME may be unset under sandbox.
set -eo pipefail

# ── Resolve user home robustly. ─────────────────────────────────────────────
USER_HOME="${HOME:-}"
if [ -z "$USER_HOME" ]; then
  USER_HOME="$(eval echo ~ 2>/dev/null || true)"
fi
if [ -z "$USER_HOME" ] || [ "$USER_HOME" = "~" ]; then
  if [ -n "${USER:-}" ] && [ -d "/Users/$USER" ]; then
    USER_HOME="/Users/$USER"
  elif command -v id >/dev/null 2>&1; then
    _u="$(id -un 2>/dev/null || true)"
    [ -n "$_u" ] && [ -d "/Users/$_u" ] && USER_HOME="/Users/$_u"
  fi
fi
[ -n "$USER_HOME" ] && export HOME="$USER_HOME"  # `hb` itself reads $HOME for config

# ── Augment PATH. ───────────────────────────────────────────────────────────
for _p in \
  "$USER_HOME/.pyenv/shims" \
  "$USER_HOME/.local/bin" \
  "$USER_HOME/Library/Python/3.12/bin" \
  "$USER_HOME/Library/Python/3.11/bin" \
  "$USER_HOME/Library/Python/3.10/bin" \
  "/opt/homebrew/bin" \
  "/usr/local/bin" \
; do
  [ -z "$_p" ] && continue
  case ":$PATH:" in *":$_p:"*) ;; *) [ -d "$_p" ] && PATH="$_p:$PATH" ;; esac
done
export PATH

exec hb mcp "$@"
