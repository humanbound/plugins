---
description: Stop the tunnel for this project (idempotent)
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/stop.sh:*), AskUserQuestion, Skill
disable-model-invocation: false
argument-hint: "[--all]"
---

Invoke the `running-adversarial-tests` skill with `intent=stop`. Pass `$ARGUMENTS` through.
