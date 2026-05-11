---
name: running-adversarial-tests
description: MUST USE for ANY request to run an adversarial / security / pentest test against a local AI agent. Triggers on phrases like "run an adversarial test on my local agent", "run an adversarial test", "pentest my AI", "security test for my agent", "run owasp_agentic on my assistant", "test my chatbot for jailbreaks", "run a humanbound test", "run hb test on this", "test my agent". Drives the full end-to-end flow — verify humanbound MCP, detect server, discover endpoints, expose via ngrok, dispatch via humanbound MCP, poll, and render findings.
---

# Running an adversarial test against a local agent

This is the orchestrator skill for the `humanbound-test` plugin. It chains four phase skills and provides the top-level structured progress.

## ⛔ DO NOT IMPROVISE

**The user invoked this skill explicitly (or via natural-language match). Follow Steps 1–6 below. Do NOT:**

- Run `hb test` directly via shell. The flow uses MCP tools (`hb_connect` / `hb_run_test`) AFTER tunneling and discovery, never the raw CLI.
- Skip Steps 2–4 even if you find an existing endpoint config (e.g., `.test.env`, `bot-config.json`). The whole point of this plugin is to expose the LOCAL agent through ngrok and test the live tunnel — not to test against whatever stale config sits in the repo.
- Read the user's repo for "the test command" and execute it. The test command IS this skill. Begin at Step 1.
- Search for `.env` / `bot-config` / `.test.env` files and use them as-is. The plugin generates the bot-config from live discovery (Step 3) and the live tunnel URL (Step 4).
- **Run `ls` to "discover" plugin scripts.** The canonical paths are listed below. Use them directly.
- **Compute state paths yourself.** Do NOT put state in `~/.claude/projects/.../state/`. Do NOT mkdir random paths under `~/.claude/`.

If you're reading this and an existing config exists, IGNORE IT and run the documented flow.

## Output format rules (consistent across all 6 steps)

The plugin's user-visible output follows a small vocabulary of glyphs and a strict
hierarchy. **Apply these rules to every print line you emit; do NOT improvise other
formats.**

| Glyph | Meaning | Example |
|---|---|---|
| `▸ Step N/6 — <Title>` | Step header (em-dash, no extra glyph) | `▸ Step 1/6 — Verify humanbound MCP` |
| `  ✓ <label>` | Successful sub-check | `  ✓ ngrok ready` |
| `  ✓ <label> · <detail>` | Successful sub-check with one detail (middle-dot separator, U+00B7) | `  ✓ CLI authenticated · hb v2.0.2` |
| `  → <action>` | In-progress action (gives a "doing" cue before a blocking call) | `  → starting uvicorn` |
| `  ⚠ <message>` | Warning / heads-up | `  ⚠ MCP server can't see your credentials.` |
| `  ✗ <message>` | Failure / blocker | `  ✗ MCP server unreachable. Reload your editor.` |
| 4-space indent (no glyph) | Block of related details under a `✓` headline | `    entry        app:app` |

Sub-check lines are indented 2 spaces under their step header. Detail blocks under a
`✓` headline are indented 4 spaces. Do NOT mix in other indentation widths or glyphs
(no bullets, no dashes, no `•`/`*` markers).

**Step ordering is strict.** Do NOT print a Step N+1 header until Step N has finished
emitting its `✓` lines (or hit a STOP path). If Step N runs a script, wait for the
script to exit and the `✓` summary to print BEFORE moving to Step N+1. This applies
even when a step short-circuits via cached state (e.g. Step 3 hitting cached config) —
still print Step 3's `✓` summary under its own header, never under the next step.

## Canonical paths (use these exact paths — no `ls`, no guessing)

`<project>` = the user's current working directory (the project being tested).
`${CLAUDE_PLUGIN_ROOT}` = the loaded plugin's root directory (Cursor: `~/.cursor/plugins/local/humanbound-test/`).

| What | Path |
|---|---|
| Plugin config (server + tunnel + test only) | `<project>/.humanbound/test/config.toml` |
| Plugin state (JSON) | `<project>/.humanbound/test/state.json` |
| Plugin logs dir | `<project>/.humanbound/test/logs/` |
| Bot config (user-authored, persistent) | `<project>/.humanbound/test/bot-config.json` |
| Pre-flight script | `${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh` |
| Server detect | `${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/detect-server.py` |
| Bot-config prepare/validate | `${CLAUDE_PLUGIN_ROOT}/skills/dispatching-hb-tests/scripts/prepare-bot-config.py` |
| Tunnel start / stop / status | `${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/{start,stop,status}.sh` |
| Ngrok setup | `${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/setup-ngrok.sh` |
| MCP server wrapper | `${CLAUDE_PLUGIN_ROOT}/scripts/start-mcp.sh` |
| Shared lib (paths/log/etc.) | `${CLAUDE_PLUGIN_ROOT}/scripts/lib/{paths,log,pidfile,config}.sh` |

**Run scripts via `bash <full-path>` directly. Never `ls` the plugin tree first to "see what's there."**

## Intent table

The skill is invoked from the slash commands with `intent=<verb>`:

| `intent` value | From command | Behavior |
|---|---|---|
| `run` | `/humanbound-test:run` | Full flow: Steps 1–6 |
| `setup` | `/humanbound-test:setup` | Invoke installing-humanbound-mcp + tunneling-local-agent intent=setup-ngrok (no tunnel start, no test) |
| `status` | `/humanbound-test:status` | Forward to `tunneling-local-agent` (intent=status) |
| `stop` | `/humanbound-test:stop` | Forward to `tunneling-local-agent` (intent=stop) |
| `resume <id>` | `/humanbound-test:resume <id>` | Skip Steps 1–5; resume polling experiment <id> |
| `config` | `/humanbound-test:config` | Forward to `tunneling-local-agent` (intent=config) |

## intent=run — full flow

```
1. Print the banner + overview block (sets user expectations for what's coming):

   ━━━ humanbound-test ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     Running adversarial test:
       1. Verify humanbound MCP
       2. Verify ngrok
       3. Detect local server
       4. Start tunnel
       5. Prepare bot-config
       6. Run test

   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2. Step 1/6 — Verify humanbound MCP:
   Print "▸ Step 1/6 — Verify humanbound MCP".

   2a. CLI pre-flight — invoke `installing-humanbound-mcp`. The skill runs
       check-mcp.sh silently (no prints on success) and returns one of three
       states to the orchestrator:

       "humanbound: ready"         → continue to 2b
       "humanbound: not-logged-in" → fall through to in-flow login recovery (2c)
       "humanbound: missing"       → the skill prints the install prompt itself
                                     and STOPS the flow

   2b. MCP server check (the runtime authoritative check):
       Call hb_whoami MCP tool. Branch on the response:

       ── {"authenticated": true} ─────────────────────────────────────────
         Print:
           "  ✓ CLI authenticated · hb v<version>"
           "  ✓ MCP server authenticated · <username>"
         Continue to Step 2/6.

       ── {"authenticated": false} (any shape of response, populated or empty) ─
         Since 2a confirmed the CLI is logged in, this means the MCP server
         is in a stale state (cached at editor startup, before login). Running
         `hb login` won't help — the credentials file is already correct; the
         MCP server just needs to re-read it, which only happens on restart.
         Print:

           "  ⚠ MCP server can't see your credentials."
           "    The CLI is logged in (we just verified it), but the MCP server"
           "    cached its state at editor startup and won't re-read the file"
           "    until it's restarted."
           ""
           "    Fix: reload the editor window —"
           "      Cursor / VS Code: Cmd+Shift+P → 'Developer: Reload Window'"
           "    Then re-run /humanbound-test:run."
         STOP. (No tunnel is running yet — nothing to remind about.)

       ── hb_whoami tool errors (network failure, MCP server crashed, etc.) ─
         Surface the error verbatim. Print:
           "  ✗ MCP server unreachable. Reload your editor and try again."
         STOP.

   2c. In-flow login recovery (only reached when 2a returned "not-logged-in"):

       AskUserQuestion (single-select, header="Authenticate"):
         question: "humanbound CLI isn't authenticated. Run `hb login` now?"
         options:
           "Yes — open browser and complete OAuth (Recommended)"
           "I'll handle it manually"
           "Cancel"

       On "Yes":
         Run via Bash:  hb login
         Surface stdout + stderr verbatim. `hb login` is interactive and may
         take a minute or two while the user completes OAuth in their browser
         — that's expected; do not retry or timeout the Bash call.

         If exit code != 0:
           Print "  ✗ hb login failed. Falling back to manual instructions."
           Print the manual-branch body below. STOP.

         If exit code == 0:
           Print "  ✓ hb login complete."
           Tell the user to reload the editor (MCP server needs to re-read
           credentials):
             "  ⚠ The MCP server still has its previous (unauthenticated)"
             "    state cached. Reload your editor and re-run /humanbound-test:run."
           STOP. (Don't try to call hb_whoami here — the MCP server is stale.)

       On "I'll handle it manually":
         Print:
           "Run in another terminal:"
           "    hb login"
           "Then reload your editor (Cmd+Shift+P → 'Developer: Reload Window')"
           "and re-run /humanbound-test:run."
         STOP.

       On "Cancel":
         STOP.

3. Step 2/6 — Verify ngrok:
   Print "▸ Step 2/6  Verifying ngrok".
   Invoke `tunneling-local-agent` intent=setup-ngrok. The flow self-checks via
   `setup-ngrok.sh --status` — if ngrok is already installed + authenticated,
   it prints "ngrok is set up" and returns immediately. Otherwise it walks the
   install/auth flow.

   On success, print: "  ✓ ngrok ready (region: <region>)".

4. Step 3/6 — Detect local server:
   Invoke `tunneling-local-agent` intent=detect-only. Runs detect-server.py,
   writes the [server] section of config.toml, prints "▸ Step 3/6  Detecting
   local server" + the "✓" lines. If no FastAPI detected, the script stops
   the flow here with the roadmap pointer.

   Cached-server short-circuit: if config.toml already has a populated [server]
   section from a prior run, detect-server.py skips re-detection and prints a
   one-line cache summary. Run /humanbound-test:config to force re-detection.

5. Step 4/6 — Start tunnel:
   Invoke `tunneling-local-agent` intent=start-tunnel. Launch uvicorn → wait
   for health → launch ngrok → capture public URL. Prints
   "▸ Step 4/6  Starting tunnel".

6. Step 5/6 — Prepare bot-config:
   Print "▸ Step 5/6  Preparing bot-config".
   Run: prepare-bot-config.py prepare <project> <public-url>
   Branch on stdout:

   ── "template_created" (first run in this project) ─────────────
     Print:
       "  Wrote starter template to <project>/.humanbound/test/bot-config.json"
       "  with the current ngrok URL pre-filled."
       ""
       "  Fill in:"
       "    • chat_completion.endpoint  (replace <your-chat-path> with your path)"
       "    • chat_completion.headers   (e.g. {\"x-api-key\": \"<your-token>\"})"
       "    • chat_completion.payload   (must include \"$PROMPT\" placeholder)"
       "    • thread_init.endpoint + headers + payload (if your agent uses sessions)"
       "    • telemetry block (optional — for Langfuse / LangSmith / W&B / Helicone / AgentOps)"
       ""
       "  Schema reference: https://docs.humanbound.ai/getting-started/agent-config/"
       ""
       "  Then re-run /humanbound-test:run to continue."
     STOP. Remind tunnel still running.

   ── "ngrok_refreshed" (subsequent runs) ────────────────────────
     Print:
       "  ✓ ngrok URL refreshed in bot-config.json (host swapped to <public-url>)"
       "  Review/edit <project>/.humanbound/test/bot-config.json if any field needs adjustment."
     Run: prepare-bot-config.py validate <project>
     If validation fails (exit != 0): print the validate stderr verbatim, hint at the
     fix, and STOP. Remind tunnel still running.
     If validation passes: continue to Step 6.

7. Step 6/6 — Run test:
   Invoke `dispatching-hb-tests`. It owns: project picker, test config gathering,
   summary block, confirm prompt, dispatch (hb_connect / hb_run_test), polling
   loop, and findings render. The skill prints "▸ Step 6/6  Running test" and
   reads bot-config.json directly from `<project>/.humanbound/test/bot-config.json`.

8. Final reminder line about `/humanbound-test:stop` — printed by `dispatching-hb-tests`.
```

## intent=resume <id>

```
1. Print: "▸ Resuming experiment <id>"
2. Read state.json. If experiment.id != <id>: warn but proceed.
3. Skip to Step 6/6 of `dispatching-hb-tests` polling loop.
4. Render findings.
```

## intent=setup

```
1. Invoke `installing-humanbound-mcp`. Don't stop on "not-logged-in" — that's expected
   (user is running setup precisely to fix it).
2. Invoke `tunneling-local-agent` intent=setup-ngrok.
3. Print: "✓ humanbound-test setup complete. Run /humanbound-test:run to start a test."
```

## intent=status / intent=stop / intent=config

Direct forwards — the orchestrator's role is purely routing here.

```
intent=status  →  invoke tunneling-local-agent intent=status  +  also include experiment line from state.json if present
intent=stop    →  invoke tunneling-local-agent intent=stop
intent=config  →  invoke tunneling-local-agent intent=config
```

## Cross-cutting rules

The same rules from each phase skill apply at the orchestrator level:
1. Never auto-confirm an install / never echo secrets / never retry on script error.
2. Detected values surface as plain text.
3. `AskUserQuestion` always exposes "Other" automatically.
4. Surface every script's stderr verbatim.
5. Always remind to `/humanbound-test:stop` after a test run (the tunnel survives intentionally).

## See also

- Phase skills: `tunneling-local-agent`, `installing-humanbound-mcp`, `dispatching-hb-tests`.
- Summary block template: `runtime-summary-template.md`.
