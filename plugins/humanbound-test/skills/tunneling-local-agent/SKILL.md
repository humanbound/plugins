---
name: tunneling-local-agent
description: Internal phase skill for humanbound-test. Drives the local-server detection, ngrok setup/install, and tunnel lifecycle. Invoked by `running-adversarial-tests` (the orchestrator) with `intent=<verb>`. Do NOT trigger directly on user phrasing — this skill is owned by the orchestrator. The user invokes the orchestrator's `/humanbound-test:run` instead.
---

# Tunneling a local agent for humanbound-test

This skill drives the tunnel-related verbs of the `humanbound-test` plugin. It's identical in shape to `humanbound-tunnel`'s `tunneling-local-servers` skill but uses the `humanbound-test` paths. Its intents are invoked at several points by the orchestrator: `intent=setup-ngrok` as Step 2, `intent=detect-only` as Step 3, and `intent=start-tunnel` as Step 4.

Each invocation specifies `intent=<verb>`. Branch on `intent` and run the matching sub-flow.

## Cross-cutting rules

1. **Never auto-confirm an install.** Always ask before `brew install ngrok`, before stopping a running tunnel when ambiguous, etc.
2. **Never echo secrets back to chat** (auth tokens, basic_auth passwords).
3. **Detected values surface as plain text, never as a prompt.** Print `detected: server.port=8000`, do not ask "is 8000 OK?".
4. **`AskUserQuestion` always exposes "Other" automatically.** Single-select with 2-3 sensible suggestions is enough — don't add an "Other" option yourself.
5. **Surface every script's stderr verbatim** if the script exits non-zero. Stop — do not retry the script unchanged.
6. **All paths come from `paths.sh`** — sourced first by every script. Never hard-code `~/.claude/...` here.

---

## intent=detect-only  (called as Step 3 of the orchestrator)

```
1. Print:  "▸ Step 3/6  Detecting local server"
2. Run: detect-server.py "$PROJECT" --json. Capture JSON.
3. From the JSON, print a single ✓ block (style: framework headline + indented
   details). Skip empty fields:
     "  ✓ <framework_capitalised> detected"
     "      entry          <entry_point>"
     "      server         <host>:<port>"
     "      package mgr    <package_mgr>"
4. If <project>/.humanbound/test/config.toml does not exist:
     Run detect-server.py "$PROJECT" --write. This writes the TOML with
     [server] and [tunnel] sections. (Agent endpoints / payloads / auth
     live in user-authored bot-config.json — handled in orchestrator Step 5.
     Per-run test config — category / testing level / fail-on — is
     collected in dispatch Step 4, not persisted here.)
5. Return to orchestrator.
```

---

## intent=start-tunnel  (called as Step 4 of the orchestrator)

```
1. Print:  "▸ Step 4/6  Starting tunnel"

2. Run: setup-ngrok.sh --status. If exit != 0:
     a. Surface its stdout + stderr verbatim.
     b. Invoke intent=setup-ngrok.
     c. After it returns, re-run setup-ngrok.sh --status.
        - If "ready": continue.
        - Else: print "ngrok setup is incomplete — run /humanbound-test:setup, then re-run /humanbound-test:run." and stop.
   Do not loop on intent=setup-ngrok more than once per orchestrator invocation.

3. Run start.sh (no args). Stream its stdout + stderr verbatim — start.sh emits the structured "→/✓/⚠" lines itself.

   **HARD STOP on non-zero exit.** If start.sh returns non-zero, the server or tunnel failed.
   Surface the FULL output verbatim (including the `tail -n 30` server-log dump start.sh prints
   on failure). Do NOT continue to Step 5. Do NOT print "Tunnel is up" or any success line.
   The orchestrator must abort the run and tell the user to fix their server (typically: missing
   Python deps in the active env — `uv pip install -e .` or equivalent for the project).

   On success: capture the URL printed on the final line. Verify the URL was actually emitted —
   if start.sh exited 0 but no URL appeared, that is also a failure; abort the run.

4. If tunnel.ngrok.basic_auth is "" in the config (read via config_get from config.sh):
     AskUserQuestion (single-select, header="Add password"):
       question: "The public URL is currently unauthenticated. Set a password now?"
       options:  "No, leave it open" | "Yes — set basic_auth and restart"
     On "Yes":
       a. Invoke intent=config edit-flow for tunnel.ngrok.basic_auth only.
       b. Warn: "Restarting will change the public URL on free ngrok plans. OK?"
       c. AskUserQuestion (single-select): "Restart now?" — "Yes, restart" | "No, keep current URL"
       d. On "Yes": run stop.sh, then start.sh again.

5. Return the final public URL to the orchestrator.
```

---

## intent=setup-ngrok

```
1. Run setup-ngrok.sh --status. Surface output.
2. State "ngrok: not installed":
     AskUserQuestion: "I can install ngrok via `brew install ngrok`. Proceed?"
       options: "Yes, install with brew" | "No, I'll install manually"
     On Yes: run setup-ngrok.sh --install. On exit 0 → re-run --status.
     On No: print install URL + stop.
3. State "authtoken: missing":
     Print dashboard URL: https://dashboard.ngrok.com/get-started/your-authtoken
     Ask user to paste the token in their next message.
     Take the next user message body verbatim as <token>.
     Run setup-ngrok.sh --auth <token>. NEVER echo back. Confirm with "ngrok ready" only.
4. State "ready": print "ngrok is set up — proceeding."
5. Any other output: surface verbatim and stop.
```

---

## intent=stop

```
0. If "$ARGUMENTS" contains "--all": run stop.sh --all and surface output. Stop here.
1. Run status.sh --all. Capture output.
2. If output contains "no tunnel" for cwd and no other entries: print "no tunnel running" and exit.
3. Exactly one tunnel: run stop.sh (no prompt).
4. >1 tunnel:
     AskUserQuestion (multi-select, header="Stop which?"):
       question: "Which tunnels do you want to stop?"
       options:  one per running tunnel, labelled "<project_path>  ·  <public_url>"
     For each chosen entry: cd <project_path> && "${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/stop.sh".
5. Surface stop.sh output verbatim.
```

---

## intent=status

```
1. Run status.sh "$ARGUMENTS". Pretty-print the JSON (one section per project).
2. If "$ARGUMENTS" empty AND status.sh --all reports ≥2 projects:
     AskUserQuestion (single-select): "Multiple tunnels running. Show all, or just this project?"
     On all: print --all output. On just this: print status.sh (no flag) output.
3. Print "no tunnel" if applicable.
```

---

## intent=config

```
1. Run detect-server.py <project> --json. Capture JSON.
2. If .humanbound/test/config.toml exists:
     a. Read + print the file.
     b. AskUserQuestion (multi-select, header="Edit fields"):
          question: "Which fields do you want to change?"
          options:  server.entry_point, server.port, server.host, server.health_path,
                    tunnel.ngrok.domain, tunnel.ngrok.basic_auth, tunnel.ngrok.region

     (Agent endpoints / payloads / auth / telemetry live in
     `<project>/.humanbound/test/bot-config.json` — not in config.toml — and are
     user-authored. To change those, edit bot-config.json directly. See
     https://docs.humanbound.ai/getting-started/agent-config/ for the schema.
     Per-run test config — category, testing level, fail-on — is collected
     fresh each `/humanbound-test:run`; nothing to edit here.)
     c. Single-edit shortcut: when invoked from another flow (e.g., intent=start-tunnel asks
        for tunnel.ngrok.basic_auth), skip 2b and ask only the requested field.
     d. For each chosen field: AskUserQuestion (single-select) with 2-3 sensible suggestions.
     e. Build flat-dotted dict: parsed current TOML (flatten) + user's new values, pipe to
        detect-server.py --write-from-json.
3. Else (no config exists):
     a. From the JSON: print "Detected: framework=<X>, entry_point=<Y>, port=<Z>" — no prompt.
     b. For each path in `unknown` (server.* first, then tunnel.*):
          AskUserQuestion (single-select) with 2-3 smart-default suggestions.
     c. Always ask basic_auth (recommended) — same flow as humanbound-tunnel.
     d. Build full flat-dotted dict and pipe to detect-server.py --write-from-json.
4. Print final config path + contents.
```

### Suggestion menus

| Field | Suggestions |
|---|---|
| server.provider | `fastapi` (only supported provider) |
| server.host | `127.0.0.1`, `0.0.0.0` |
| server.port | `3000`, `8000`, `5000` |
| server.health_path | `/`, `/health`, `/healthz` |
| server.package_mgr | `uv`, `poetry`, `pip`, `pipenv`, `none` |
| tunnel.ngrok.region | `us`, `eu`, `ap`, `au`, `sa`, `jp`, `in` |
| tunnel.ngrok.basic_auth | `(empty)` (public access), `demo:<random-6>` |

---

## Reference: scripts the skill calls

All paths relative to `${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/`:

- `detect-server.py <project> {--json | --write | --write-from-json}`
- `start.sh` / `stop.sh [--all]` / `status.sh [--all]`
- `setup-ngrok.sh [--status | --install | --auth <token>]`
