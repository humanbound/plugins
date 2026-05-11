# Roadmap

A snapshot of where `humanbound/plugins` is heading. This is a living document.
Open a [discussion](https://github.com/humanbound/plugins/discussions)
or [issue](https://github.com/humanbound/plugins/issues) to weigh in.

## Now — shipping in 0.1.x

- **`humanbound-test`** (Claude Code + Cursor) — adversarial agent testing
  end-to-end, with `humanbound` MCP integration

## Next — target 0.2

- **First-class LangServe detection** for `humanbound-test` — extend
  server detection to recognize `langserve` in `pyproject.toml` /
  `requirements.txt` and find `add_routes(app, agent, path="/...")`
  call sites for the entry-point hint. Highest-ROI framework miss —
  LangChain dominates the production AI-agent space. Files:
  `skills/tunneling-local-agent/scripts/detect-server.py`,
  `skills/tunneling-local-agent/scripts/providers/server/langserve.sh`.
  (Note: agent endpoints / payloads still live in user-authored
  `bot-config.json` — we don't auto-discover them.)
- **Runtime OpenAPI scrape** for `humanbound-test` — if a server is already
  running on the detected port, hit `/openapi.json` and parse it directly
  instead of (or in addition to) AST walking. Framework-independent;
  bullet-proof for anything that emits OpenAPI (FastAPI, LangServe,
  flask-smorest, etc.).
- **Confidence scores + prompt-on-ambiguous** for detection — return
  `{fastapi: 0.95, langserve: 0.40}` instead of first-match-wins, so the
  orchestrator can ask the user to confirm when multiple frameworks match.
- **Submit `humanbound-test` to the official Cursor marketplace**
  (`cursor.com/marketplace/publish`) so end users can install via the
  in-editor `/add-plugin` command instead of the clone+symlink flow.
- **Port `humanbound-tunnel`** (currently in the legacy
  `humanbound-tunnel` repo) — same Claude Code + Cursor dual support,
  add to this marketplace.

## Later — on the horizon, not committed

- **First-class Flask + Django detection** — same AST approach for Flask
  (`@app.route("/x", methods=["POST"])`); Django needs `manage.py show_urls`
  (django-extensions) or `urls.py` parsing.
- **Streamlit / Gradio adapter** — these expose a UI, not HTTP endpoints.
  Testing them requires simulating chat via Gradio's queue API or
  Streamlit's session-state protocol, not just HTTP detection. Different
  feature, not just detection.
- **TypeScript / Express / Next.js endpoint detection** — needs tree-sitter
  or node-based parsing. Diminishing returns vs Python coverage.
- **Native MCP tool gating** in Claude Code via `allowed-tools`
  extended to MCP server invocations.
- **Plugin templates** under `plugins/_template/` for community plugin
  authors.
- **CI-based smoke tests** for each plugin against a recorded MCP fixture.

## Not doing

- Not bundling third-party MCP servers other than Humanbound's
- Not shipping plugins that require the closed-source Humanbound Platform
  to function — every plugin must have a local-only mode

## Release cadence

Each plugin is versioned **independently** via tags of the shape
`v-<plugin-name>-<semver>`. See [CONTRIBUTING.md](./CONTRIBUTING.md) for
the release flow.
