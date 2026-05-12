<h3 align="center">humanbound-test</h3>

<p align="center">
  Adversarial / security testing for your local AI agent.
  <br/>
  Auto-detects your FastAPI server, exposes it via ngrok, you fill in
  <code>bot-config.json</code>, the plugin dispatches via the
  <code>humanbound</code> MCP and renders findings.
</p>

<p align="center">
  <a href="#slash-commands">Slash commands</a> &middot;
  <a href="#install">Install</a> &middot;
  <a href="#configuration">Configuration</a> &middot;
  <a href="https://docs.humanbound.ai/">Documentation</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-preview-FD9506?style=flat-square" alt="Status: preview"/>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-FD9506?style=flat-square" alt="License"/></a>
  <a href="https://discord.gg/gQyXjVBF"><img src="https://img.shields.io/badge/discord-community-FD9506?style=flat-square" alt="Discord"/></a>
  <a href="https://docs.humanbound.ai/getting-started/agent-config/"><img src="https://img.shields.io/badge/docs-humanbound.ai-FD9506?style=flat-square" alt="Docs"/></a>
</p>

---

> 📖 **`bot-config.json` schema reference** lives at
> [docs.humanbound.ai/getting-started/agent-config/](https://docs.humanbound.ai/getting-started/agent-config/).

> ⚠ **Preview (0.1.0).** Slash-command names, `bot-config.json` schema, and
> `<project>/.humanbound/test/` on-disk layout may change before 1.0. Pin to
> a specific tag if you depend on a particular shape.

Works in **Claude Code** and **Cursor**.

## Slash commands

```text
/humanbound-test:run [--unit | --system | --full]
    Main flow — verify MCP → verify ngrok → detect server → tunnel → prepare bot-config → run test

/humanbound-test:setup
    One-time: install humanbound[mcp] + ngrok, log in

/humanbound-test:status
    Show running tunnels and experiments

/humanbound-test:resume <experiment-id>
    Resume polling a previously-started experiment

/humanbound-test:stop
    Tear down the tunnel

/humanbound-test:config
    Edit .humanbound/test/config.toml interactively
```

## Natural-language triggers

The main test flow (`/humanbound-test:run`) can also be invoked by describing
what you want — no slash needed. The orchestrator skill matches phrases like:

- *"run an adversarial test on my local agent"*
- *"pentest my AI"*
- *"security test for my agent"*
- *"test my chatbot for jailbreaks"*
- *"run a humanbound test"*

The agent infers your intent, asks for any missing config interactively, and
walks the same `verify MCP → verify ngrok → detect server → tunnel →
bot-config → run test` flow.

> **Note:** the other five commands (`setup`, `status`, `resume`, `stop`,
> `config`) are slash-only by design — their internal skills explicitly avoid
> auto-trigger to keep teardown, secrets handling, and config edits intentional.

## Install

Both flows are documented in the [umbrella README](../../README.md#install-in-claude-code).
Short version:

### Claude Code

```text
/plugin marketplace add https://github.com/humanbound/plugins.git
/plugin install humanbound-test@humanbound-plugins
```

### Cursor

```bash
git clone https://github.com/humanbound/plugins.git ~/src/humanbound-plugins
mkdir -p ~/.cursor/plugins/local
ln -s ~/src/humanbound-plugins/plugins/humanbound-test ~/.cursor/plugins/local/humanbound-test
# Restart Cursor
```

## Requirements

- macOS (primary) or Linux (best-effort)
- Python ≥ 3.11 (`tomllib` from stdlib)
- `humanbound[mcp]` Python package — the plugin offers to install it on first
  run. Authentication via `hb login` is required: this plugin dispatches
  adversarial tests through the hosted Humanbound platform, so a logged-in
  `hb` session is a hard prerequisite for `/humanbound-test:run`.
- `ngrok` CLI authenticated — the plugin walks you through
  `brew install ngrok` + auth-token setup if needed.

## Supported frameworks

Currently ships **FastAPI server detection only**. Other server frameworks
(Flask, Django, LangServe, Streamlit, Gradio, Express, Next.js, Hono, …) are
not supported — running the plugin in a non-FastAPI project errors out with
a pointer to the roadmap. See [ROADMAP](../../ROADMAP.md) for the prioritised
expansion plan (LangServe + runtime OpenAPI scrape are the top items planned
next).

The plugin does **NOT** auto-detect agent endpoints, payload shapes, or auth.
You author those yourself in `bot-config.json`. This keeps the plugin honest —
we don't pattern-match against route decorators or guess at Pydantic field
names. You know your agent better than our detector.

## Configuration

Two files live under `<project>/.humanbound/test/`:

**`config.toml`** — auto-generated on first run by `detect-server.py`. Holds
the server section (FastAPI entry point, package manager, port) and tunnel
section (ngrok region, optional basic auth). Use `/humanbound-test:config` to
edit interactively. Per-run test config (category, testing level, fail-on) is
collected fresh each run — not stored here.

**`bot-config.json`** — you author this. The plugin generates a starter
template on the first `/humanbound-test:run` (with the current ngrok URL
pre-filled and `<your-...>` placeholders for paths / auth / payload /
telemetry). Fill it in once; on every subsequent run the plugin just refreshes
the ngrok URL host. Schema reference:
[docs.humanbound.ai/getting-started/agent-config/](https://docs.humanbound.ai/getting-started/agent-config/).

## State layout

All runtime artifacts live under `<project>/.humanbound/test/`
(auto-gitignored):

```
<project>/.humanbound/test/
├── config.toml      # server + tunnel config (auto-detected, you tweak via /humanbound-test:config)
├── bot-config.json  # YOUR agent's endpoints, headers, payload, telemetry (you author once)
├── state.json       # runtime: tunnel pids, public URL, current experiment_id
└── logs/            # server.log, tunnel.log
```

Everything is project-local — no fallback to `$HOME`. Auth tokens live inline
in `bot-config.json` (which is gitignored). If you want to share a config
across projects, copy `bot-config.json` over.

## Host differences

| Capability | Claude Code | Cursor |
|---|---|---|
| Slash-command Bash gating | Per-command via `allowed-tools` frontmatter | Session-wide via `beforeShellExecution` hook ([shell-guard.sh](hooks/shell-guard.sh)) — audits every exec, blocks tampered plugin paths |
| `${CLAUDE_PLUGIN_ROOT}` expansion in manifest | Yes | No |
| `${CURSOR_PLUGIN_ROOT}` expansion in `mcpServers.env` block | N/A | Yes |
| Hook event names | PascalCase (`SessionEnd`) | camelCase (`sessionEnd`) |
| Install from GitHub URL | `/plugin marketplace add <git-url>` | Not supported as of 2.5 — symlink to `~/.cursor/plugins/local/` |

The plugin handles all of the above transparently; the table is for reference.

## License

[Apache-2.0](../../LICENSE) — see repo root.
