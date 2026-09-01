# Required data — projects + experiments

Lifted verbatim from `plugins/humanbound-tunnel/skills/running-hb-agent-tests/SKILL.md`. Authoritative source: the humanbound backend schemas (`schemas/Project.py`, `schemas/Experiment.py`) plus https://docs.humanbound.ai/getting-started/agent-config/.

## Required data — projects + experiments

Authoritative source: the local backend schemas (`schemas/Project.py`, `schemas/Experiment.py`) plus https://docs.humanbound.ai/getting-started/agent-config/. The docs and the backend agree.

### Agent-config (`ClientBotConfiguration`) — the MUST-have block

This is the integration that the judge uses to talk to the agent. It is required at one of two layers: **on the project** (as `default_integration`, then inherited by every experiment) or **on the experiment** (one-off override).

| Field | Required | Type | Notes |
|---|---|---|---|
| `chat_completion.endpoint` | ✅ | URL | Public URL (no localhost). `wss://` required if `streaming=true`. |
| `chat_completion.headers` | optional | dict | Auth / content-type. Pass-through. |
| `chat_completion.payload` | ✅ | dict | Request body template. **Must contain `$PROMPT` literal** — backend substitutes per turn. |
| `thread_init.endpoint` | ✅ | URL | Called once per conversation to create a session. Public URL. |
| `thread_init.headers` | optional | dict | |
| `thread_init.payload` | optional | dict | Can be `{}`. |
| `thread_auth.endpoint` | optional | URL | OAuth pre-flight; if set, `headers` + `payload` describe the token-exchange call. |
| `streaming` | optional | bool | Default `false`. If `true`, `chat_completion.endpoint` MUST be `wss://`. |
| `telemetry` | optional | object | Whitebox testing — only if the agent emits traces (LangFuse/LangSmith/W&B/Helicone/AgentOps/custom). |

Critical guards (from `validate_endpoint`):
- **No localhost / `http://127.0.0.1`** — endpoint validator rejects them. The tunnel public URL is mandatory.
- **`https://` only** for non-streaming. **`wss://` only** when `streaming=true`.
- If `thread_auth.endpoint` is empty, its `headers` and `payload` MUST also be empty.

### Project fields (`POST /projects` — `Projects` schema)

| Field | Required | Default | Notes |
|---|---|---|---|
| `organisation_id` | ✅ | — | Set by auth context (`hb_set_organisation`). |
| `name` | optional | `DEFAULT_PROJECT_NAME` | Use the cwd basename for clarity. |
| `description` | optional | `""` | |
| `scope.overall_business_scope` | ✅ | — | **20–5000 chars.** What the agent IS supposed to do. Drives the judge's threat model. |
| `scope.intents.permitted` / `scope.intents.restricted` | ✅ (lists, can be empty) | — | Populated by the platform after analysis if you let `hb_connect` scan. |
| `scope.more_info` | optional | `""` | ≤200 chars. |
| `scope.capabilities` | optional | all `false` | `{tools, memory, inter_agent, reasoning_model}` — drives ASCAM coverage (e.g. `tools=true` enables ASI02–05). |
| `default_integration` | optional, but recommended | `null` | The `ClientBotConfiguration` above. If unset, every experiment must supply its own. |
| `few_shot_framework_enabled` | optional | `false` | |
| `policy_recommendation_enabled` | optional | `true` | |

### Experiment fields (`POST /projects/{id}/experiments` — `Experiments` schema)

| Field | Required | Default | Inherits from project? |
|---|---|---|---|
| `project_id` | ✅ | — | URL path. |
| `configuration.integration` | ✅ (or `auditor`) | — | **Yes — falls back to `project.default_integration` if omitted.** Hard 400 if neither is set. |
| `configuration.scope` | ignored | — | **ALWAYS overwritten from `project.scope`** (incl. recommended restrictions merged in). Don't bother sending it. |
| `configuration.context` | optional | `""` | No. Free-form judge context — anything you'd put in `-c`. |
| `configuration.auditor.parent` | required for `logs_auditor` | — | No. Mutually exclusive with `integration` for audit-mode runs. |
| `test_category` | optional | `humanbound/adversarial/owasp_agentic` | No. Validated against installed orchestrators — unknown values 400. |
| `testing_level` | optional | `unit` | No. `unit` / `system` / `acceptance` / `production`. |
| `lang` | optional | `en` | No. Validated against `SUPPORTED_LANGUAGES`. |
| `name` | optional | `DEFAULT_EXPERIMENT_NAME` | No. |
| `description` | optional | `""` | No. |
| `provider_id` | optional | resolved per-org | **Yes — falls back to org default LLM provider.** 400 if no provider configured. |
| `auto_start` | optional | `true` | No. `false` = create row only, don't run yet. |

**Inheritance summary (what to NOT collect twice):**

- ✅ Always inherited unless overridden: `integration` (from `project.default_integration`), `provider_id` (from org default).
- ✅ Always inherited, **cannot be overridden**: `scope` (from `project.scope`).
- ❌ Never inherited — collect every run if not default-acceptable: `test_category`, `testing_level`, `lang`, `name`, `description`, `context`.

**Conflict detector (409):** if an experiment with the same `project_id + test_category + lang` is already running (status ∈ Created/Generating/Generated/Running/Completed/Analysing), the backend returns 409. Surface the existing experiment id and offer to resume polling instead of creating a duplicate.
