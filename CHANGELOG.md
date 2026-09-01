# Changelog

All notable changes to plugins in this repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and each plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
**independently**. Plugin-scoped entries are prefixed with the plugin name.

## [Unreleased]

### Changed
- **humanbound-test:** `/humanbound-test:run` no longer polls the experiment
  and renders findings inline. After dispatch it prints a randomly-chosen
  "grab a coffee" message (sourced verbatim from the `hb connect` exit
  message in `humanbound-cli`), the experiment ID, and a one-line watch
  hint pointing at `/humanbound-test:resume <id>`, then exits. Results are
  delivered by email; in-band polling + findings render is now reached
  only via `/humanbound-test:resume <id>` (the polling logic moved into a
  dedicated "Resume path" section in `dispatching-hb-tests/SKILL.md` — no
  behavior change for resume itself).
- **Contribution policy: CLA replaced by DCO** (repo-wide). External
  contributions no longer require signing the Humanbound Contributor
  License Agreement. Contributions are now accepted under the Developer
  Certificate of Origin v1.1 (see `DCO.md`) — sign commits with
  `git commit -s`. Contributors keep their copyright; contributions are
  licensed inbound = outbound under Apache-2.0. `CLA.md` is removed and a
  `dco.yml` workflow now checks `Signed-off-by` trailers on every pull
  request.
- `CONTRIBUTING.md` gains an explicit third-party license policy: vendored
  code must be permissively licensed (Apache-2.0/MIT/BSD/ISC); GPL, AGPL,
  SSPL, and BSL code cannot be accepted.
- `LICENSE` restored to the verbatim Apache-2.0 text (repo-wide). Sections 6
  and 9 had diverged from the canonical wording and the appendix was
  missing; the file now matches apache.org/licenses/LICENSE-2.0 exactly,
  apart from the appendix copyright line. The license grant is unchanged —
  the repository was and remains Apache-2.0 — but GitHub now detects the
  license, where it previously reported the repository as "Other".

### Added
- `NOTICE` file per Apache-2.0 section 4(d).

## [humanbound-test 0.1.0] — 2026-05-12

### Added
- Initial public release of `humanbound-test`.
- End-to-end adversarial testing flow against a local AI agent:
  verify humanbound MCP → verify ngrok → detect local server → start tunnel →
  prepare bot-config → run test.
- Native dual support for **Claude Code** and **Cursor** from a single source
  tree, with per-host manifests, per-host hook event names (PascalCase /
  camelCase), and per-host tool-gating models.
- FastAPI server auto-detection (entry point, package manager, port).
  Non-FastAPI projects exit early with a pointer to the roadmap.
- User-authored `bot-config.json` workflow — the plugin writes a starter
  template on first run and refreshes the ngrok host on subsequent runs.
  The user fills in endpoints, headers, payload, and (optional) telemetry.
- Project-local state model under `<project>/.humanbound/test/` — auto-gitignored,
  no user-home fallback.
- Cursor `beforeShellExecution` shell-guard that audits every plugin shell
  invocation and blocks `humanbound-test/` paths from outside the installed
  plugin root.
- In-flow `hb login` recovery for the case where the CLI is not yet
  authenticated when a test run is requested.
- `bats` smoke suite + `pytest` suite, run on every PR by CI
  (shellcheck + JSON manifest validation + matrix Python 3.11 / 3.12).
- Six slash commands: `/humanbound-test:run`, `:setup`, `:status`, `:resume`,
  `:stop`, `:config`. Natural-language triggers route to the orchestrator
  skill.

### Known limitations
- Cursor install is via clone + symlink to `~/.cursor/plugins/local/`.
  Cursor 2.5 does not yet support installing community plugins from a public
  Git URL.
- FastAPI is the only server framework auto-detected today. See
  [ROADMAP](./ROADMAP.md) for the prioritised expansion plan.

[Unreleased]: https://github.com/humanbound/plugins/compare/v-humanbound-test-0.1.0...HEAD
[humanbound-test 0.1.0]: https://github.com/humanbound/plugins/releases/tag/v-humanbound-test-0.1.0
