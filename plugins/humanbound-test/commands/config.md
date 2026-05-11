---
description: View or edit the project's .humanbound/test/config.toml interactively
allowed-tools: Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/detect-server.py:*), Bash, AskUserQuestion, Skill, Read, Write
disable-model-invocation: false
---

Invoke the `running-adversarial-tests` skill with `intent=config`. Edits the server + tunnel + test sections of `.humanbound/test/config.toml` interactively, without launching a test. (Agent endpoints / payloads / auth / telemetry live in user-authored `bot-config.json`, not here — see https://docs.humanbound.ai/getting-started/agent-config/)
