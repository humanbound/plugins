---
name: installing-humanbound-mcp
description: Internal phase skill for humanbound-test. Verifies the `humanbound[mcp]` Python package is installed and `hb login` is current (CLI pre-flight). Drives part of Step 1 (Verify humanbound MCP) of the orchestrator. Do NOT trigger on user phrasing.
---

# Installing humanbound[mcp]

Part of Step 1 of the orchestrator (the CLI pre-flight for humanbound MCP). The orchestrator follows up with an `hb_whoami` MCP-tool call to verify the running server sees the credentials. This skill handles the CLI half: is `hb` installed, is it logged in. Two outcomes only — keep it simple.

## ⛔ Canonical paths — DO NOT improvise, DO NOT `ls` to discover

Use these EXACT paths. Do not guess, do not run `ls` to find them, do not put state in `~/.claude/projects/...`.

| What | Path |
|---|---|
| The pre-flight script | `${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh` |
| The state file | `<project>/.humanbound/test/state.json` |
| The log dir | `<project>/.humanbound/test/logs/` |

If `${CLAUDE_PLUGIN_ROOT}` isn't expanded by your harness, fall back to the symlink target you already know — Cursor: `~/.cursor/plugins/local/humanbound-test/...`. NEVER ls the plugin tree to discover scripts.

## Flow

```
1. Run the pre-flight script directly (no ls first, no `bash` prefix — the script
   has a shebang and is executable). Capture the captured `hb` version from the
   output and remember it; the orchestrator will surface it on success.
     ${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh
   Branch on the first stdout line — only three possible states:

   ── "humanbound: ready" ────────────────────────────────────────
     Print NOTHING. Return "ready" + the detected `hb` version to the orchestrator,
     which owns the user-visible "✓ CLI authenticated · hb v<version>" line.

   ── "humanbound: not-logged-in" ────────────────────────────────
     Print NOTHING. Return "not-logged-in" to the orchestrator, which routes to
     its in-flow `hb login` recovery prompt (Step 2c of the orchestrator). Do
     NOT print the legacy three-line STOP banner here — that flow is handled
     by the orchestrator now.

   ── "humanbound: missing" ──────────────────────────────────────
     The package isn't installed. This is a real install situation, so this
     skill DOES print + prompt here (the orchestrator delegates the install
     UX entirely to this skill).

     Capture the second line ("suggest: ...") as the recommended command.
     ONE AskUserQuestion (single-select, header="Install"):
       question: "humanbound[mcp] is not installed. Install now?"
       options:  "<recommended-command> (Recommended)"
                 | "pip install 'humanbound[mcp]'"
                 | "Skip — I'll install manually"
     On Skip: print "Install humanbound[mcp] yourself, then re-run /humanbound-test:run." STOP.
     On install: run the chosen command via Bash. Surface stdout + stderr verbatim.
     After install: print "  ⚠ restart your editor so the humanbound MCP server picks up,
     then re-run /humanbound-test:run." STOP the orchestrator.
```

## Cross-cutting rules

1. **Two outcomes, three states — nothing else.** Do not invent extra steps (no symlink prompts,
   no PATH-fix suggestions, no module-vs-binary distinction). The CLI is `hb`. If it's not on
   PATH, the package isn't installed; ask to install.
2. **Never auto-run `pip install`** — always show the command in `AskUserQuestion`.
3. **Restart prompt is non-negotiable** after a fresh install. MCP server registration is read at
   editor session start; a freshly-installed `hb` won't be discovered until the next session.
4. **`hb login` is a STOP signal, not a prompt.** Do not ask "have you logged in?" — print the
   instruction once and stop. The user re-runs `/humanbound-test:run` after authenticating.
5. **Always run the live check — no caching.** The `check-mcp.sh` script runs on every
   invocation. Adding 200-700ms of pre-flight is invisible in a 30s+ test run and avoids
   the failure mode where a stale cache says "all good" while `hb_whoami` later returns
   `authenticated: false`.

## Reference

| Tool / Script | Purpose |
|---|---|
| `check-mcp.sh` | Local pre-flight (no MCP needed) — emits one of the three states above |
| `hb_whoami` (MCP) | Authoritative login check inside the running test flow (NOT this skill) |
