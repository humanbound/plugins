#!/usr/bin/env bash
# check-mcp.sh — emit one of three states for the orchestrator skill to branch on.
#
# Usage:
#   check-mcp.sh
#
# Exits 0 with one of:
#   "humanbound: ready"          — `hb` on PATH and `hb whoami` succeeds
#   "humanbound: not-logged-in"  — `hb` on PATH but `hb whoami` fails
#   "humanbound: missing"        — no `hb` on PATH (suggests pip install)

# NOTE: intentionally NOT using `set -u`. Some harnesses run scripts with HOME
# unset, and we need to handle that gracefully (not crash at first reference).
set -eo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../../../scripts/lib/log.sh"

PROJECT="${PROJECT:-$(pwd)}"

# ── Resolve user home robustly (sandboxed bash often strips HOME). ──────────
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

# ── Augment PATH with common `hb` install locations. ────────────────────────
# Order matters: pyenv shims → user pip → homebrew → system. Empty HOME is OK.
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

# 1. Binary on PATH? (humanbound's CLI is `hb`, installed by `pip install humanbound[mcp]`)
if command -v hb >/dev/null 2>&1; then
  ver="$(hb --version 2>/dev/null | head -1 || echo unknown)"
  if hb whoami >/dev/null 2>&1; then
    echo "humanbound: ready"
    echo "version: $ver"
    exit 0
  fi
  echo "humanbound: not-logged-in"
  echo "version: $ver"
  exit 0
fi

# 2. Missing — suggest install based on detected package manager.
echo "humanbound: missing"
if [ -f "$PROJECT/uv.lock" ]; then
  echo "suggest: uv pip install 'humanbound[mcp]'"
elif [ -f "$PROJECT/poetry.lock" ]; then
  echo "suggest: poetry add 'humanbound[mcp]'"
elif [ -f "$PROJECT/Pipfile.lock" ]; then
  echo "suggest: pipenv install 'humanbound[mcp]'"
else
  echo "suggest: pip install 'humanbound[mcp]'"
fi
exit 0
