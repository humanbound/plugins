# Contributing to humanbound/plugins

Thanks for considering a contribution. This document covers the essentials —
for extended guidance, see [docs.humanbound.ai/community/contributing](https://docs.humanbound.ai/community/).

## Quick start

```bash
git clone https://github.com/humanbound/plugins.git
cd plugins
pre-commit install                                  # wire up the local hooks

# To dev a plugin in Claude Code: symlink into local plugins dir
mkdir -p ~/.claude/plugins/local
ln -s "$PWD/plugins/humanbound-test" ~/.claude/plugins/local/humanbound-test
```

Open Claude Code; the `/humanbound-test:*` commands load from your working copy.

For cross-cutting conventions that apply to every public Humanbound repo
(README skeleton, CHANGELOG format, governance files, CI scaffolding, tone),
see [`humanbound/.github` REPO_STANDARDS](https://github.com/humanbound/.github/blob/main/REPO_STANDARDS.md).

## Repo layout

This is a **Claude Code plugin marketplace** with each plugin under
`plugins/<name>/`. The umbrella manifest lives at
`.claude-plugin/marketplace.json`. Each plugin ships **two manifests** to
support both Claude Code and Cursor:

| Path | Read by |
|---|---|
| `plugins/<name>/.claude-plugin/plugin.json` | Claude Code |
| `plugins/<name>/.cursor-plugin/plugin.json` | Cursor |
| `plugins/<name>/mcp.json` | Cursor (top-level MCP autoload) |
| `plugins/<name>/hooks/hooks.json` | Claude Code (PascalCase events) |
| `plugins/<name>/hooks/hooks-cursor.json` | Cursor (camelCase events) |

Keep the two manifests structurally similar but **not identical** —
Cursor uses different event names and does not expand
`${CLAUDE_PLUGIN_ROOT}`. See `plugins/humanbound-test/hooks/hooks-cursor.json`
for the canonical Cursor hooks shape.

## Filing issues

Bugs, feature requests, and questions all live in
[GitHub Issues](https://github.com/humanbound/plugins/issues).

**Do not file security issues publicly.** See [SECURITY.md](./SECURITY.md).

## Developer Certificate of Origin (DCO) — required

This project does **not** use a CLA. Contributions are accepted under the
[Developer Certificate of Origin](./DCO.md) — the same lightweight mechanism
used by the Linux kernel, CNCF projects, and GitLab. You keep the copyright
to your work; it is licensed inbound = outbound under
[Apache-2.0](./LICENSE), exactly like the rest of the codebase.

There is nothing to sign — just add the `-s` flag when committing:

```bash
git commit -s -m "your message"
```

CI checks that every commit in a pull request carries the resulting
`Signed-off-by` trailer. Forgot one? `git commit --amend -s` (or
`git rebase --signoff main` for a whole branch) and force-push.

## Third-party code and licenses

To keep the repository safely redistributable under Apache-2.0:

- **Code copied or vendored into this repository** (scripts, snippets,
  assets) must be under a permissive license: Apache-2.0, MIT, BSD (2- or
  3-clause), or ISC. Include the upstream copyright notice and license
  text, and mention the origin in your PR description.
- **New dependencies a plugin pulls in at runtime** must be permissively
  licensed as above; weak-copyleft dependencies (MPL-2.0, LGPL) are
  acceptable only unmodified and need maintainer sign-off.
- **GPL, AGPL, SSPL, or BSL-licensed code cannot be accepted** in any form
  (vendored, copied, or as a dependency).

If you're unsure about a license, ask in the PR before writing code.

## Change workflow

1. Fork the repository and create a branch off `main`
2. Make your changes — keep them focused (one concern per PR)
3. Add or update plugin tests under `plugins/<name>/tests/`
4. Test the plugin in **both Claude Code and Cursor** (see Quick start)
5. Update [CHANGELOG.md](./CHANGELOG.md) under the `[Unreleased]` section
6. Open a pull request

### Code style

- Shell scripts: `bash`, `set -euo pipefail` at top, `shellcheck` clean.
  Document deliberate exceptions inline — for instance, scripts that may
  run under sandboxed harnesses with `HOME` unset drop `-u` and explain why
  in a comment (see `scripts/start-mcp.sh`, `installing-humanbound-mcp/scripts/check-mcp.sh`).
- Python helper scripts: stdlib only where possible, ruff-compatible
- JSON / YAML / TOML: 2-space indent, trailing newline
- SPDX header on every new shell or Python file:
  ```
  # SPDX-License-Identifier: Apache-2.0
  # Copyright (c) 2024-2026 Humanbound
  ```
- `.pre-commit-config.yaml` enforces the above; run `pre-commit install`
  after cloning

### Tests

- Bash scripts get a smoke test under `tests/bash/` (bats — assertion on
  stdout/exit code)
- Python helpers get pytest coverage under `tests/python/`
- CI runs both suites on every PR across Python 3.11 + 3.12 (see
  `.github/workflows/ci.yml`)
- Interactive flows (slash commands) are tested manually; document the
  manual test plan in the PR description

## How changes ship

Maintainers cut releases on a rolling basis.

| Step | Who | What |
|---|---|---|
| PR review | Maintainer | Reviews code, tests, CHANGELOG |
| Merge to `main` | Maintainer | Squash merge |
| Tag `v-<plugin>-<version>` | Maintainer | e.g. `v-humanbound-test-0.1.0` |
| GitHub Release | Maintainer | Created from `CHANGELOG.md` entry |

Versioning follows [semver](https://semver.org) **per plugin**. The umbrella
repo itself is not versioned.

## Community

- **Discord** — [discord.gg/QFTD6tr9zu](https://discord.gg/QFTD6tr9zu)
- **Discussions** — on the GitHub repo
- **Docs** — [docs.humanbound.ai](https://docs.humanbound.ai)

## Code of Conduct

Participation is governed by our [Code of Conduct](./CODE_OF_CONDUCT.md).
Violations can be reported privately to
[conduct@humanbound.ai](mailto:conduct@humanbound.ai).
