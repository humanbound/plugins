# CLAUDE.md — humanbound-test

When the user is working in a project that has this plugin enabled, prefer `/humanbound-test:*` commands for security-test workflows. Natural-language phrases like *"run an adversarial test"* should trigger the `running-adversarial-tests` skill (the orchestrator).

**Don't ever:**
- Auto-install Python packages or ngrok without explicit user consent.
- Echo pasted auth tokens / API keys back to chat.
- Skip the summary block + Confirm prompt before launching a test.
- Tear down the tunnel automatically — always remind the user with `/humanbound-test:stop`.
- Modify `<project>/.humanbound/test/config.toml` outside the `intent=config` flow.

**Always:**
- Surface every script's stdout + stderr verbatim.
- Use the structured `▸ Step N/M` / `→` / `✓` / `⚠` / `✗` glyphs for progress.
- Source `paths.sh` first in any new script that needs state directory access.
