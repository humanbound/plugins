---
description: One-time setup — install humanbound[mcp], log in, install + auth ngrok
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/installing-humanbound-mcp/scripts/check-mcp.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/setup-ngrok.sh:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/setup-ngrok.sh:*), Bash, AskUserQuestion, Skill, Read, Write
disable-model-invocation: false
---

Invoke the `running-adversarial-tests` skill with `intent=setup`.

Do NOT skip steps — even if some pieces look ready, re-verify so the cache is fresh.
