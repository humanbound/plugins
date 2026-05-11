---
name: dispatching-hb-tests
description: Internal phase skill for humanbound-test. Picks/creates the humanbound project, reads the user-authored ClientBotConfiguration from bot-config.json, dispatches the test via `hb_connect` or `hb_run_test`, polls until terminal, and renders findings. Drives Step 6 of the orchestrator (the "Run test" phase: project picker + summary + confirm + dispatch + poll + render). Do NOT trigger on user phrasing.
---

# Dispatching humanbound tests

Step 6 of the orchestrator — the "Run test" phase. Picks the project, gathers test-run config (depth, fail-on, etc.), dispatches with the bot-config that was prepared in Step 5, polls, renders findings. MCP authentication is verified in Step 1 of the orchestrator; by the time this skill runs we can trust hb_whoami returns authenticated:true.

## Cross-cutting rules

1. **Never auto-launch a test.** Always show the summary block + ONE confirm prompt before `hb_connect` / `hb_run_test`.
2. **Use MCP tools, NEVER shell commands.** All `hb_*` calls in this skill (`hb_list_projects`, `hb_connect`, `hb_run_test`, `hb_get_experiment_status`, `hb_list_findings`, `hb_get_posture`, etc.) are MCP tools registered by the plugin. Do NOT shell out to `hb experiments`, `hb test`, `hb orgs`, etc. as a substitute. If an MCP tool isn't available in the current session, STOP and tell the user: "humanbound MCP server isn't loaded — reload your editor and try again." Do not improvise with shell commands.
3. **Never echo secrets back to chat.**
4. **Detected values are surfaced as plain text, never as a prompt.**
5. **`AskUserQuestion` always exposes "Other" automatically.**
6. **Surface every MCP tool's error verbatim. Stop on failure — never retry the same call unchanged.**
7. **Polling discipline:** wait ≥15s between `hb_get_experiment_status` calls. Stop when status ∈ {succeeded, failed, terminated}. Cap at 60 iterations (~15 min).
8. **Do not tear down the tunnel automatically.** Always remind the user to run `/humanbound-test:stop` when done.

---

## Step 6/6 — Run test

```
0. Print: "▸ Step 6/6  Running test"

1. Project picker:
     a. Call hb_list_projects.
     b. Try to match by asset URL (==public-url) or by name == cwd basename.
     c. AskUserQuestion (single-select, header="Project"):
          question: "Which project should the test run in?"
          options:
            "<detected-name> (existing)"     # if step b found a match
            "Create a new project"
            "Pick a different existing project"
     d. On "Pick different": AskUserQuestion listing project names from hb_list_projects.
     Set path = A (new) or B (existing).

2. (Path B only) If chosen project has a default_integration AND the user wants to
   override for this run:
     AskUserQuestion (single-select, header="Override agent-config?"):
       question: "Project has an agent-config. Override with this run's bot-config.json?"
       options:  "No, inherit from project (Recommended)" | "Yes, override (one-off)"
   The bot-config.json is already filled in by Step 4 (Prepare bot-config) — we just
   decide whether to use it here or inherit the project's saved default.

3. (Path A only) Gather project fields:
     a. AskUserQuestion (single-select, header="Project name"):
          question: "Project name?"
          options:  "<cwd-basename>" | "Other"

     b. Scope — single-line input (no wizard, no file/README options):
          AskUserQuestion (single-select, header="Scope"):
            question: "Describe your agent in 1-2 sentences (drives the judge's threat model):"
            options:
              "Type a description"     — opens free-text input; validate length 20–500 chars
              "Skip — use placeholder" — fall back to auto-default below
          On "Type":
            Collect the free-text body verbatim as `overall_business_scope`.
            If length < 20: print "  ⚠ too short (need ≥20 chars). Falling back to placeholder."
              and use the auto-default.
          On "Skip" or fallback:
            Set `overall_business_scope` = "Adversarial test target — <project-name>. Placeholder; edit at app.humanbound.ai for higher-fidelity findings."

     c. Capabilities — multi-select (drives ASCAM coverage; tools=true enables ASI02–05, etc.):
          AskUserQuestion (multi-select, header="Capabilities"):
            question: "Which capabilities does the agent have?"
            options:  "Tools (function calls)" | "Memory (persisted across turns)" | "Multi-agent (delegates to other agents)" | "Reasoning model (chain-of-thought)"
          Map selected options to the schema:
            "Tools (function calls)"           → tools = true
            "Memory (persisted across turns)"  → memory = true
            "Multi-agent (delegates to other agents)" → inter_agent = true
            "Reasoning model (chain-of-thought)"      → reasoning_model = true
          Unselected options default to `false`. If user selects nothing, omit
          the `capabilities` object — backend defaults to all-false.

4. Test config (ONE batched AskUserQuestion with 4 questions):
     a. header="Test depth"  — "unit (fast)" | "system (--deep)" | "acceptance (--full)"
     b. header="Category"    — "owasp_agentic (default)" | "Other"
     c. header="Fail-on"     — "none (report only)" | "high" | "critical"
     d. header="Run name"    — "<project>-<timestamp> (auto)" | "Other"

5. Judge context:
     AskUserQuestion (single-select, header="Judge context"):
       question: "Add extra context for the judge?"
       options:  "No" | "Yes — type it now" | "Yes — read from a .txt file"
     Collect if any.

6. Read the user's bot-config from <project>/.humanbound/test/bot-config.json.
   It was prepared (template-or-ngrok-refresh + validate) in the orchestrator's
   Step 4 — at this point the file is guaranteed to exist and pass validation.
   Parse it into memory for the summary block and dispatch.

7. Print summary block. **Single-line-per-row** — do NOT use sub-blocks with
   continuation indentation (the agent loses alignment on those). Use the
   middle-dot `·` separator (U+00B7) to compress multi-field rows:

     ──────────────────────────────────────────────────────────────────
       Project      <A | B> · <name><suffix>
       Scope        "<first 80 chars>…" (<n> chars)               # Path A only — skip on Path B
       Capabilities <comma-separated list, e.g. "tools, memory">  # Path A only — skip if none selected
       Public URL   <public-url>
       Agent        <chat-path> · <thread-path> · streaming <on|off> · auth <type>
       Test         <category-short> · <unit|system|acceptance> · fail-on <severity>
       Run name     <run-name>
       Judge        <n> chars
       Bot config   .humanbound/test/bot-config.json
     ──────────────────────────────────────────────────────────────────

   Field-rendering rules:
   - `<suffix>` is " (new)" on Path A, " (override)" on Path B-with-override,
     or empty on Path B-inherit.
   - **Scope row** — Path A only. If the user used the auto-default placeholder
     (because they typed nothing valid), skip the row entirely (it's not useful
     to display the placeholder back to them). Otherwise show first 80 chars +
     ellipsis + total char count.
   - **Capabilities row** — Path A only. Show a comma-separated list of
     selected capabilities (e.g. `tools, memory`). If nothing was selected,
     skip the row entirely.
   - `<chat-path>` / `<thread-path>` show ONLY the path portion of the
     bot-config endpoints (e.g. `/chat`), not the full URL — the public
     URL is already shown above. If `thread_init.endpoint` is empty, omit
     the `· <thread-path>` segment entirely.
   - `streaming <on|off>` — render booleans as `on` / `off`, not `true` / `false`.
   - `auth <type>` — read from bot-config (`auth_type` field if present, else
     infer from `chat_completion.headers`: `header` if any header is set,
     `none` otherwise). Omit the entire `· auth ...` segment if you can't infer.
   - `<category-short>` — strip the `humanbound/adversarial/` prefix from
     the test category for display (e.g. `owasp_agentic`, not
     `humanbound/adversarial/owasp_agentic`).
   - Bot-config path is always rendered relative to the project (drop the
     leading `<project>/`).

8. AskUserQuestion (single-select, header="Confirm"):
     question: "Run hb_connect on <public-url>?" (Path A)
            or "Run hb_run_test on project '<name>' against <public-url>?" (Path B)
     options:  "Yes, run it" | "No, cancel"
     On No: stop. Remind tunnel still running.

9. Dispatch:
     Before the MCP call, re-read bot-config.json from disk one more time so any
     last-second edits the user made (between summary and confirm) are picked up.

     Path A: call hb_connect with public_url, project name, test_category, testing_level, name,
             description, context, fail_on. Capture experiment_id + project_id.
             (Path A re-discovers the agent shape itself; bot-config.json is informational.)
     Path B: call hb_set_project(project_id), then hb_run_test with the loaded
             bot-config + test_category, testing_level, name, description, context,
             fail_on. Capture experiment_id.

   On 409 (duplicate experiment running): surface the existing experiment_id and offer
   "Resume polling that experiment?"

10. Persist experiment to state.json (via pidfile.sh write_experiment).

11. Print: "  ✓ experiment_id: <id>"

12. Polling loop (max 60 iterations, 15s between):
     a. Call hb_get_experiment_status(experiment_id).
     b. Print one line: "  ⠋ status: <status>  <progress-info>  (HH:MM:SS elapsed)"
        (Use a spinner glyph that rotates each iteration: ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ ⠋)
     c. If status ∈ {succeeded, failed, terminated}: print "  ✓ status: <status>" and break.

13. If still running at iteration 60:
     Print: "  ⚠ still running — experiment_id=<id>. Re-run /humanbound-test:resume <id>."
     Persist {experiment.status="running"} to state.json. Stop.

14. Render findings (see reference/findings-renderer.md):
     a. Call hb_get_experiment_logs(experiment_id). Print run summary.
     b. Call hb_list_findings(experiment_id). Print:
          - severity counts: "by severity:    critical=<n>   high=<n>   medium=<n>   low=<n>"
          - top 5 with bullets: "[<SEV>] <title>"
     c. Call hb_get_posture(project_id). Print "posture score: <s> / 100".
     d. Fail-on verdict:
          if any finding.severity >= test.fail_on:
            print "✗ FAIL: <count> finding(s) at severity >= <fail_on>"
          else:
            print "✓ DONE"

15. Always remind:
     "  ⚠ Tunnel is still running at <public-url>"
     "    Run /humanbound-test:stop to tear it down."
```

---

## See also

- `reference/required-data.md` — full ClientBotConfiguration / Project / Experiment schema.
- `reference/findings-renderer.md` — exact terminal layout for the findings block.
