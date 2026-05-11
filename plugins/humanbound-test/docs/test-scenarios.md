# Manual interactive-flow test scenarios

Automated bats / pytest cover scripts and detection logic. The interactive `AskUserQuestion`-driven flows must be tested manually before each release.

## Scenario S1 — first-run on a clean FastAPI project

Setup: clean checkout of any FastAPI app with a `/chat` POST route, no `.humanbound/`.

Steps:
1. Run `/humanbound-test:setup` (in a session where humanbound[mcp] is not yet installed).
   - Expect `installing-humanbound-mcp` to detect missing pkg and offer install.
   - Pick the recommended option. Wait for install. Restart editor.
2. Re-open the project. Run `/humanbound-test:run`.
   - Expect banner + 6-step overview block printed first.
   - Expect ▸ Step 1/6 — Verifying humanbound MCP: CLI ready + MCP server authenticated.
   - Expect ▸ Step 2/6 — Verifying ngrok: ngrok ready (region: us).
   - Expect ▸ Step 3/6 — Detecting local server: FastAPI detected + indented details.
   - Expect ▸ Step 4/6 — Starting tunnel: prints public URL + basic-auth warning.
   - Expect ▸ Step 5/6 — Preparing bot-config:
     - "Wrote starter template to .humanbound/test/bot-config.json"
     - Reference docs link printed
     - Skill STOPs and asks user to fill in the template.
3. Open `.humanbound/test/bot-config.json` and fill in:
   - `chat_completion.endpoint`: replace `<your-chat-path>` with `/chat`
   - `chat_completion.headers`: `{}` (or add `{"x-api-key": "..."}` if your agent needs auth)
   - `chat_completion.payload`: e.g. `{"message": "$PROMPT"}`
   - Leave `thread_init`, `thread_auth`, `telemetry` empty or fill if needed
4. Re-run `/humanbound-test:run`.
   - Expect Steps 1-4 fast (cached MCP auth + already-up tunnel).
   - Expect Step 5 prints "✓ ngrok URL refreshed in bot-config.json" + validation passes.
   - Expect ▸ Step 6/6 — Running test: project picker → summary → confirm → dispatch → spinner → findings render → tunnel-still-running reminder.

## Scenario S2 — second run reuses state + bot-config

Steps:
1. From S1's tunnel: run `/humanbound-test:status`. Should show running tunnel + last experiment.
2. Run `/humanbound-test:run` again.
   - Steps 1-2 reuse cached config and pass infra check.
   - Step 3 detects already-running tunnel and skips re-start (existing public URL reused).
   - Step 4 prints "ngrok_refreshed" (no host change needed since URL is the same).
   - Project picker matches the existing project from S1.

## Scenario S3 — agent with header auth (inline in bot-config.json)

Setup: FastAPI project where `/chat` requires `x-api-key: <token>` header.

Steps:
1. Run `/humanbound-test:run`. On first run, Step 4 writes the template and stops.
2. Edit `.humanbound/test/bot-config.json`:
   ```json
   "chat_completion": {
     "endpoint": "https://abc.ngrok-free.app/chat",
     "headers": {"x-api-key": "fa-443f27814aeafea986cbaf99254ead5dc7cfa4df"},
     "payload": {"message": "$PROMPT"}
   }
   ```
3. Re-run `/humanbound-test:run`.
   - Step 4 validates: passes (endpoint non-placeholder, $PROMPT present, no localhost).
   - Confirm: tokens never echoed back to chat.
4. After dispatch completes, verify `.humanbound/test/bot-config.json` is the only place the token lives. It's gitignored — never accidentally committed.

## Scenario S4 — non-FastAPI project (graceful refusal)

Setup: any non-FastAPI project (e.g. an Express `package.json` with no Python files, a Django repo, a Streamlit app, etc.).

Steps:
1. Run `/humanbound-test:run`.
   - Expect ▸ Step 1/6 ✗ "no FastAPI detected. humanbound-test currently supports FastAPI projects only — see ROADMAP.md for the framework expansion plan."
   - Expect exit code 1, no `.humanbound/` directory created in the project.
   - Expect NO interactive prompts (we don't pretend to support frameworks we can't test end-to-end).

## Scenario S5 — fail-on=critical with a clean run

Setup: any agent that doesn't have critical-severity findings, with `bot-config.json` already filled.

Steps:
1. `/humanbound-test:config` → edit `test.fail_on = critical`.
2. Run `/humanbound-test:run`.
   - Expect "✓ DONE" verdict at end.

## Scenario S6 — resume a long-running experiment

Setup: kick off a `--system` test (long).

Steps:
1. After Step 5 confirms, kill the editor mid-poll (CTRL-C the run loop).
2. Re-open and run `/humanbound-test:resume`.
   - Expect skill to read state.json, find experiment.id, continue polling.
3. After completion, expect findings render.

## Scenario S7 — project-local state layout

State is always project-local; there is no user-home fallback. Verify the filesystem layout after a clean run.

Steps:
1. Run `/humanbound-test:run` on a FastAPI demo with `bot-config.json` filled.
2. After the tunnel comes up + dispatch completes:
   - Expect config at `<project>/.humanbound/test/config.toml` (server + tunnel + test sections, no [agent.*]).
   - Expect bot-config at `<project>/.humanbound/test/bot-config.json` (user-authored, includes inline auth tokens).
   - Expect state at `<project>/.humanbound/test/state.json` (tunnel pids + public URL + experiment id).
   - Expect logs at `<project>/.humanbound/test/logs/{server,tunnel}.log`.
   - Expect `.gitignore` updated with `.humanbound/`.

## Scenario S8 — ngrok URL drift across runs

Setup: a project that's been tested at least once (bot-config.json populated).

Steps:
1. Run `/humanbound-test:stop` to tear down the current tunnel.
2. Run `/humanbound-test:run` again. The new ngrok URL will be DIFFERENT from last time (free ngrok = random URL per session).
3. Verify Step 4 prints "ngrok_refreshed" and `bot-config.json` now contains the new ngrok host in `chat_completion.endpoint` and `thread_init.endpoint`.
4. Verify the path portion of each endpoint is preserved (e.g. `/chat` still `/chat`).
5. Verify validation passes and dispatch proceeds without user intervention.
