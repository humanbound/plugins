#!/usr/bin/env bash
# shell-guard.sh — Cursor beforeShellExecution hook.
#
# Replicates the spirit of Claude Code's `allowed-tools` frontmatter under
# Cursor, which doesn't honor that key. Specifically:
#
#   1. Audit: every shell exec the plugin's slash commands trigger is logged
#      to ~/.humanbound/test/logs/cursor-shell-audit.log so the user can
#      inspect exactly what the plugin runs.
#
#   2. Path integrity: if the command references a humanbound-test script
#      path but that path isn't under the actual plugin root (i.e. the agent
#      is trying to invoke a tampered copy elsewhere on disk), block the
#      execution.
#
# Failure mode is fail-open for parse errors — we never want this hook to
# break a user's unrelated shell work. The only path that returns non-zero
# is the explicit "plugin path outside plugin root" check.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024-2026 Humanbound

set -eo pipefail

payload="$(cat || true)"

# Extract the command string from Cursor's hook payload. The payload schema
# is currently in flux across Cursor releases; we try several known shapes
# before giving up.
command_str="$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)
for key in ("command", "cmd", "shellCommand"):
    val = data.get(key)
    if isinstance(val, str) and val:
        print(val); sys.exit(0)
for outer in ("shellExecution", "tool", "input", "params"):
    inner = data.get(outer, {})
    if isinstance(inner, dict):
        for key in ("command", "cmd", "shellCommand"):
            val = inner.get(key)
            if isinstance(val, str) and val:
                print(val); sys.exit(0)
' 2>/dev/null || true)"

# Fail-open on parse failure: we never want to break unrelated shell work.
if [ -z "$command_str" ]; then
  exit 0
fi

# Resolve plugin root. Cursor sets $CURSOR_PLUGIN_ROOT on hook processes.
plugin_root="${CURSOR_PLUGIN_ROOT:-}"
if [ -z "$plugin_root" ]; then
  plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
fi

# Audit log. Per-user, never inside the repo.
audit_dir="${HOME:-/tmp}/.humanbound/test/logs"
mkdir -p "$audit_dir" 2>/dev/null || true
printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$command_str" \
  >> "$audit_dir/cursor-shell-audit.log" 2>/dev/null || true

# Path-integrity check: if the command references a humanbound-test script
# path that doesn't start with the actual plugin root, block it.
if printf '%s' "$command_str" | grep -qE '/humanbound-test/(scripts|skills|hooks)/'; then
  if [ -n "$plugin_root" ] && ! printf '%s' "$command_str" | grep -qF "$plugin_root"; then
    printf 'shell-guard: refusing humanbound-test path outside plugin root (%s)\n' "$plugin_root" >&2
    exit 1
  fi
fi

exit 0
