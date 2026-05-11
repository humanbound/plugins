---
description: Show running tunnels and active experiments for this project (or all)
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/tunneling-local-agent/scripts/status.sh:*), AskUserQuestion, Skill, Read
disable-model-invocation: false
argument-hint: "[--all]"
---

Invoke the `running-adversarial-tests` skill with `intent=status`. Pass `$ARGUMENTS` through.
