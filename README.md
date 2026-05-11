<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-light.svg"/>
    <source media="(prefers-color-scheme: light)" srcset="assets/logo-dark.svg"/>
    <img src="assets/logo-dark.svg" alt="Humanbound" width="280"/>
  </picture>
</p>

<h3 align="center">humanbound/plugins</h3>

<p align="center">
  Plugins for AI coding agents — Claude Code and Cursor.
  <br/>
  Bring Humanbound's adversarial-AI tooling into your IDE workflow.
</p>

<p align="center">
  <a href="#install-in-claude-code">Claude Code</a> &middot;
  <a href="#install-in-cursor">Cursor</a> &middot;
  <a href="#available-plugins">Plugins</a> &middot;
  <a href="https://docs.humanbound.ai/">Documentation</a> &middot;
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-FD9506?style=flat-square" alt="License"/></a>
  <a href="https://discord.gg/gQyXjVBF"><img src="https://img.shields.io/badge/discord-community-FD9506?style=flat-square" alt="Discord"/></a>
  <a href="https://docs.humanbound.ai/"><img src="https://img.shields.io/badge/docs-humanbound.ai-FD9506?style=flat-square" alt="Docs"/></a>
</p>

---

> 📖 **Full documentation** for the plugins lives in each plugin's `README.md`.
> The core Humanbound platform is documented at [**docs.humanbound.ai**](https://docs.humanbound.ai/).

## Available plugins

| Plugin | Purpose | Status |
|---|---|---|
| [`humanbound-test`](plugins/humanbound-test/) | Run adversarial / security tests against a local AI agent end-to-end — currently FastAPI-only, exposes via ngrok, dispatches via the Humanbound MCP, renders findings. | `v0.1.0` |

## Install in Claude Code

Claude Code can install directly from this Git URL via its plugin marketplace.

```text
/plugin marketplace add https://github.com/humanbound/plugins.git
/plugin install humanbound-test@humanbound-plugins
```

Restart your Claude Code session — six `/humanbound-test:*` slash commands appear.

## Install in Cursor

> Cursor 2.5 does not yet support installing community plugins directly from a Git URL ([Cursor 2.5: Plugins thread](https://forum.cursor.com/t/cursor-2-5-plugins/152124)). Until it does, sideload via symlink:

```bash
# 1. Clone the repo somewhere stable on disk
git clone https://github.com/humanbound/plugins.git ~/src/humanbound-plugins

# 2. Symlink the plugin into Cursor's local plugins directory
mkdir -p ~/.cursor/plugins/local
ln -s ~/src/humanbound-plugins/plugins/humanbound-test ~/.cursor/plugins/local/humanbound-test

# 3. Restart Cursor
```

Verify in **Cursor → Settings → Plugins → Local plugins** that `humanbound-test` is listed and enabled. The six `/humanbound-test:*` commands appear in the slash-command palette.

### Tool gating under Cursor

Claude Code enforces per-slash-command Bash gating via the `allowed-tools` frontmatter. Cursor's plugin schema doesn't recognize that key ([Plugins Reference](https://cursor.com/docs/plugins/building)), so the plugin uses Cursor's [`beforeShellExecution`](https://cursor.com/docs/hooks) hook to provide equivalent visibility: every shell exec is audited to `~/.humanbound/test/logs/cursor-shell-audit.log`, and any attempt to invoke a `humanbound-test` script from outside the actual plugin root is blocked. Different hook models, equivalent posture.

## Contributing

Contributions are welcome — both bug fixes for the existing plugin and proposals for new plugins. See [CONTRIBUTING.md](./CONTRIBUTING.md) for the dev loop, plugin layout conventions, and the CLA requirement (see [CLA.md](./CLA.md)).

- 🐛 [Report a bug or request a feature](https://github.com/humanbound/plugins/issues/new)
- 🔒 [Report a security issue](./SECURITY.md) — **not via public Issues**
- 💬 [Join Discord](https://discord.gg/gQyXjVBF)

## License

[Apache-2.0](./LICENSE). Free to use in any context — commercial or open-source — with attribution. See [TRADEMARK.md](./TRADEMARK.md) for the trademark policy. The code is open; the name is not.

The sibling projects [`humanbound`](https://github.com/humanbound/humanbound) and [`humanbound-firewall`](https://github.com/humanbound/humanbound-firewall) are also Apache-2.0.
