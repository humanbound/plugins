# Changelog

All notable changes to plugins in this repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and each plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
**independently**. Plugin-scoped entries are prefixed with the plugin name.

## [Unreleased]

## [humanbound-test 0.1.0] — 2026-05-11

### Added
- Initial release of `humanbound-test` as part of the `humanbound/plugins`
  marketplace.
- Six slash commands: `/humanbound-test:run`, `:setup`, `:status`, `:resume`,
  `:stop`, `:config`.
- Five orchestrating skills: `running-adversarial-tests` (top-level flow),
  `tunneling-local-agent`, `discovering-agent-endpoints`,
  `dispatching-hb-tests`, `installing-humanbound-mcp`.
- MCP server integration with the `humanbound` Python package via
  `scripts/start-mcp.sh` (Cursor-aware PATH/HOME hardening).
- First-class auto-detection for **FastAPI** projects (entry point,
  package manager, agent chat / thread endpoints via AST walk of
  `@app.post()` / `@router.post()` decorators, Pydantic payload shape).
  Non-FastAPI projects error out with a pointer to the roadmap rather
  than falling back to an untested escape hatch — see [ROADMAP](./ROADMAP.md)
  for the prioritized framework expansion plan.
- Ngrok-based public tunnel with `127.0.0.1` binding by default;
  optional basic-auth for public demos.
- Native Claude Code support via `.claude-plugin/plugin.json` +
  `hooks/hooks.json`.
- Native Cursor support via `.cursor-plugin/plugin.json` + top-level
  `mcp.json` (auto-detected MCP server) + `hooks/hooks-cursor.json`
  (camelCase events; `bash -c` wrapper so `$CURSOR_PLUGIN_ROOT` expands
  at script-exec time).
- Cursor tool gating via `beforeShellExecution` hook
  (`hooks/shell-guard.sh`) — replicates the spirit of Claude Code's
  `allowed-tools` by auditing every shell exec the plugin triggers and
  blocking invocations of `humanbound-test` script paths outside the
  installed plugin root.
- **Host-agnostic state layout** under `<project>/.humanbound/test/`
  (was previously `<project>/.claude/humanbound-test/` and `~/.claude/...`,
  which were Claude-Code-centric). All runtime artifacts — `config.toml`,
  `state.json`, `logs/`, `secrets/`, and the new `bot-config.json` —
  live in a single per-project tree. No user-home fallback; the
  `runtime.state_location` / `runtime.secret_location` config keys are
  removed.
- **Reviewable bot-config workflow** — the orchestrator now writes the
  assembled ClientBotConfiguration to `<project>/.humanbound/test/bot-config.json`
  and pauses for confirmation. Users can inspect or edit the file (e.g. to
  add a `telemetry` block for Langfuse / LangSmith / W&B / Helicone /
  AgentOps whitebox runs, or to tweak the payload template) before the
  dispatch step reads it back and passes it to the MCP.
- **In-flow auth recovery** — when `hb_whoami` returns `authenticated:false`
  at the start of test prep, the orchestrator now offers to run `hb login`
  inline (browser-based OAuth) instead of stopping the flow. After login,
  it re-checks auth: if MCP still doesn't see the refreshed credentials
  (the "MCP cached stale state at editor startup" case), the orchestrator
  surfaces an explicit "restart your editor" instruction rather than the
  prior implicit "re-run" hint.
  - **Stale-cache short-circuit:** if `hb_whoami` returns
    `authenticated:false` but `username` / `email` / `org_id` ARE
    populated, the orchestrator skips the `hb login` offer entirely (it
    won't help — the credentials file is already fresh on disk) and goes
    straight to the editor-reload instruction. Saves the user a
    ~30-second OAuth round-trip that wouldn't have changed the MCP
    server's in-memory state.
- **Cached-config short-circuit** — `/humanbound-test:run` now skips
  Steps 1 + 2 (server detection + endpoint discovery) when a valid
  `<project>/.humanbound/test/config.toml` already exists. The flow
  jumps straight to Step 3 (infrastructure verification) and prints
  a one-block cache summary so users see exactly which fields were
  reused. Run `/humanbound-test:config` to force re-detection or edit
  any field. Saves ~5-10 seconds and an interactive confirm prompt
  on every subsequent run.
- **Tools-first step ordering with printed overview** — the orchestrator
  now runs in the order *1. Verify humanbound MCP → 2. Verify ngrok →
  3. Detect local server → 4. Start tunnel → 5. Prepare bot-config →
  6. Run test*. The banner is followed by a 6-step overview block that
  shows the user what's coming and which steps require their input
  ("auto" vs "you fill in" / "you confirm"). Auth checks (CLI pre-flight
  + `hb_whoami` MCP call + in-flow login recovery + stale-cache detection)
  all live in Step 1 — fails fast on broken auth before any tunnel /
  bot-config / dispatch work. Server detection (Step 3) is renamed from
  "Detect local agent" since the plugin detects the *server*; the
  *agent* is what the user describes in bot-config.json.

- **Tightened slash-command permissions on Claude Code** — `run.md`,
  `setup.md`, `config.md`, and `resume.md` now declare specific
  `Bash(${CLAUDE_PLUGIN_ROOT}/.../script:*)` patterns for the plugin's
  own scripts. Result: no permission prompts on the trusted plugin
  scripts during a normal run, while external side-effect commands
  (`pip install`, `brew install`, `hb login`, `ngrok config add-authtoken`)
  still prompt as before. Cursor ignores `allowed-tools` — the
  `beforeShellExecution` hook (`shell-guard.sh`) provides the equivalent
  path-integrity boundary on Cursor.

### Changed
- **Major simplification: agent endpoint discovery removed.** The plugin
  no longer AST-scans your source code looking for `@app.post()` decorators,
  Pydantic field names, or routing patterns. Instead, the user authors
  `<project>/.humanbound/test/bot-config.json` directly — endpoints, auth
  headers, payload templates, and (optionally) telemetry blocks. The plugin
  generates a starter template with the current ngrok URL pre-filled on
  first run, and refreshes the ngrok host portion automatically on every
  subsequent run. Schema reference:
  https://docs.humanbound.ai/getting-started/agent-config/

  **What this means in practice:**
  - First test in a project: plugin writes template → you fill in 4-7 fields
    → re-run → dispatch
  - Every subsequent test: plugin refreshes ngrok URL → you confirm →
    dispatch
  - Works for ANY agent shape (OpenAI-compatible, custom, etc.) — the plugin
    doesn't guess at your schema
  - Auth tokens live inline in bot-config.json (which lives in the
    auto-gitignored `.humanbound/` tree)

  **Files deleted:** the entire `discovering-agent-endpoints/` skill
  (~430 lines), `dispatching-hb-tests/scripts/bot-config-builder.py`,
  `dispatching-hb-tests/scripts/secrets.sh`. The 6-step flow becomes:
  detect → infra → tunnel → prepare bot-config → dispatch → poll.

### Fixed
- (Previously planned in this release: `--merge` flag on `--write-from-json`
  to fix Step 2's config-toml-overwrite regression. That regression no
  longer exists since Step 2 — endpoint discovery — has been removed
  entirely. The flag was dropped along with the merge-back code path.)

### Known limitations
- Cursor install is via clone + symlink (`~/.cursor/plugins/local/...`).
  Cursor does not yet support installing plugins from a public Git URL.

[Unreleased]: https://github.com/humanbound/plugins/compare/v-humanbound-test-0.1.0...HEAD
[humanbound-test 0.1.0]: https://github.com/humanbound/plugins/releases/tag/v-humanbound-test-0.1.0
