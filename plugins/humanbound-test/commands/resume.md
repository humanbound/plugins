---
description: Resume polling a previously-started experiment by ID
allowed-tools: AskUserQuestion, Skill, Read
disable-model-invocation: false
argument-hint: "<experiment-id>"
---

Invoke the `running-adversarial-tests` skill with `intent=resume <experiment-id>`.

If the user did not provide an ID: read `<project>/.humanbound/test/state.json`. If `experiment.id` is set, use it. Otherwise: ask the user to provide one.
