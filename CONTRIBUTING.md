# Contributing to humanbound/plugins

Thanks for considering a contribution. This document covers the essentials —
for extended guidance, see [docs.humanbound.ai/community/contributing](https://docs.humanbound.ai/community/).

## Quick start

```bash
git clone https://github.com/humanbound/plugins.git
cd plugins

# To dev a plugin in Claude Code: symlink into local plugins dir
mkdir -p ~/.claude/plugins/local
ln -s "$PWD/plugins/humanbound-test" ~/.claude/plugins/local/humanbound-test
```

Open Claude Code; the `/humanbound-test:*` commands load from your working copy.

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

## Contributor License Agreement (CLA) — required

Every external contribution must be covered by the
[Humanbound Contributor License Agreement](./CLA.md). The first time you
open a pull request, the CLAAssistant bot will comment with a one-line
instruction to sign.

## Change workflow

1. Fork the repository and create a branch off `main`
2. Make your changes — keep them focused (one concern per PR)
3. Add or update plugin tests under `plugins/<name>/tests/`
4. Test the plugin in **both Claude Code and Cursor** (see Quick start)
5. Update [CHANGELOG.md](./CHANGELOG.md) under the `[Unreleased]` section
6. Open a pull request

### Code style

- Shell scripts: `bash`, `set -euo pipefail` at top, `shellcheck` clean
- Python helper scripts: stdlib only where possible, ruff-compatible
- JSON / YAML: 2-space indent, trailing newline
- SPDX header on every new shell or Python file:
  ```
  # SPDX-License-Identifier: Apache-2.0
  # Copyright (c) 2024-2026 Humanbound
  ```

### Tests

- Bash scripts get a `tests/bats/` smoke test (assertion on stdout/exit code)
- Python helpers get pytest coverage under `tests/python/`
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

- **Discord** — [discord.gg/gQyXjVBF](https://discord.gg/gQyXjVBF)
- **Discussions** — on the GitHub repo
- **Docs** — [docs.humanbound.ai](https://docs.humanbound.ai)

## Code of Conduct

Participation is governed by our [Code of Conduct](./CODE_OF_CONDUCT.md).
Violations can be reported privately to
[conduct@humanbound.ai](mailto:conduct@humanbound.ai).
