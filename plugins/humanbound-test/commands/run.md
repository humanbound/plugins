---
description: Run an adversarial test against the local agent (full flow)
allowed-tools: Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/detect-server.py:*), Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/dispatching-hb-tests/scripts/prepare-bot-config.py:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/start.sh:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/start.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/setup-ngrok.sh:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/setup-ngrok.sh:*), Bash, AskUserQuestion, Skill, Read, Write
disable-model-invocation: false
argument-hint: "[--unit | --system | --full]"
---

Invoke the `running-adversarial-tests` skill with `intent=run`. Pass `$ARGUMENTS` so the user can override the testing level.

If the user typed `--system` or `--full` (or `--deep`), use that as the default testing_level when the dispatching skill asks in Step 4 — nothing is persisted.
