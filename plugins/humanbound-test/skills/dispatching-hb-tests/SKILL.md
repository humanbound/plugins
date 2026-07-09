---
name: dispatching-hb-tests
description: Internal phase skill for humanbound-test. Picks/creates the humanbound project, reads the user-authored ClientBotConfiguration from bot-config.json, dispatches the test via `hb_connect` or `hb_run_test`, then exits with a "grab a coffee" message and watch hint — results are delivered by email. Drives Step 6 of the orchestrator (the "Run test" phase: project picker + summary + confirm + dispatch + exit). On `intent=resume <id>`, polls until terminal and renders findings inline. Do NOT trigger on user phrasing.
---

# Dispatching humanbound tests

Step 6 of the orchestrator — the "Run test" phase. Picks the project, gathers test-run config (depth, fail-on, etc.), dispatches with the bot-config that was prepared in Step 5, then exits with a watch hint — results are delivered by email. Polling + findings render lives under the "Resume path" section below and is reached only from `intent=resume <id>`. MCP authentication is verified in Step 1 of the orchestrator; by the time this skill runs we can trust hb_whoami returns authenticated:true.

## Cross-cutting rules

1. **Never auto-launch a test.** Always show the summary block + ONE confirm prompt before `hb_connect` / `hb_run_test`.
2. **Use MCP tools, NEVER shell commands.** All `hb_*` calls in this skill (`hb_list_projects`, `hb_connect`, `hb_run_test`, `hb_get_experiment_status`, `hb_list_findings`, `hb_get_posture`, etc.) are MCP tools registered by the plugin. Do NOT shell out to `hb experiments`, `hb test`, `hb orgs`, etc. as a substitute. If an MCP tool isn't available in the current session, STOP and tell the user: "humanbound MCP server isn't loaded — reload your editor and try again." Do not improvise with shell commands.
3. **Never echo secrets back to chat.**
4. **Detected values are surfaced as plain text, never as a prompt.**
5. **`AskUserQuestion` always exposes "Other" automatically.**
6. **Surface every MCP tool's error verbatim. Stop on failure — never retry the same call unchanged.**
7. **No polling on the run path.** `intent=run` exits after dispatch with a coffee message + watch hint — do NOT call `hb_get_experiment_status`, `hb_list_findings`, or `hb_get_posture` from the run flow. Polling discipline applies on the resume path only (see "Resume path" section): wait ≥15s between `hb_get_experiment_status` calls, stop when status ∈ {succeeded, failed, terminated}, cap at 60 iterations (~15 min).
8. **Do not tear down the tunnel automatically.** Always remind the user to run `/humanbound-test:stop` when done.

---

## Step 6/6 — Run test

```
0. Print: "▸ Step 6/6  Running test"

1. Project picker:
     a. Call hb_list_projects.
     b. AFTER the call returns, print a compact readable digest directly
        below the JSON receipt — never skip this:
          "  ✓ <total> projects:"
          "      • <name>  ·  <id-short>  ·  updated <relative-time>"
          "      • …"
        Field rules:
          • <total>           — JSON `total` field
          • <name>            — JSON `data[i].name`; show "(archived)" suffix if `is_archived=true`
          • <id-short>        — first 8 chars of `data[i].id`
          • <relative-time>   — humanize `data[i].updated_at` ("5m ago", "1h ago",
                                "2d ago", or absolute date if older than 30 days)
        Cap the list at 8 entries; if more, end with "      … and <n> more".
     c. Try to match by asset URL (==public-url) or by name == cwd basename.
     d. AskUserQuestion (single-select, header="Project"):
          question: "Which project should the test run in?"
          options:
            "<detected-name> (existing)"     # if step c found a match
            "Create a new project"
            "Pick a different existing project"
     e. On "Pick different": AskUserQuestion listing project names from hb_list_projects.
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

10. Persist experiment to state.json via:
      PROJECT="<project>" bash -c "source $LIB/paths.sh; source $LIB/pidfile.sh; \
        write_experiment \"<project>\" \"<experiment_id>\" \"<project_id>\" \"running\""
    `write_experiment` is a merge operation — it adds the experiment block
    without touching the tunnel state (server_pid, tunnel_pid, public_url,
    etc.) that `start.sh` wrote in Step 4.

11. Print: "  ✓ experiment_id: <id>"

12. Exit with watch hint — DO NOT POLL.

    Pick one line at random from the list below. Lines are sourced verbatim from
    the CLI's `hb connect` / `hb test` exit message — keep the emoji prefix and
    the em-dash (U+2014). Do NOT rewrite, translate, or strip the emoji.

      "☕ Go grab a coffee — we've got it from here. Email incoming when done."
      "🍺 Red team deployed — treat yourself to a beer, email coming soon."
      "🌿 Our agents are on it — go touch grass, we'll email you the results."
      "🥊 The bots are fighting — grab a snack and check your inbox later."
      "🔓 Hacking in progress — no really, go do something fun. Email on the way."
      "🚀 We're poking your agent now — go stretch, results hit your inbox shortly."
      "🧘 Time for a break — we'll ping you by email once we're through."
      "🎯 Sit back and relax — we'll email you when results are ready."

    Then print the exit block. Single line per row (same vocabulary as Step 7),
    middle-dot `·` (U+00B7) separator where multiple fields share a row:

      ──────────────────────────────────────────────────────────────────
        <chosen coffee line>

        Experiment   <experiment_id>
        Watch        /humanbound-test:resume <experiment_id>
      ──────────────────────────────────────────────────────────────────

    Hard rules for Step 12:
      • Do NOT call `hb_get_experiment_status`, `hb_list_findings`, or
        `hb_get_posture` here. Results are delivered by email; the user opts
        in to in-band polling via `/humanbound-test:resume <id>`.
      • Do NOT loop, sleep, or "just check once" — exit immediately after
        printing the block.
      • The experiment block in state.json keeps `status="running"`
        (written by Step 10). It updates to a terminal status only when
        `/humanbound-test:resume <id>` is run.

13. Always remind:
     "  ⚠ Tunnel is still running at <public-url>"
     "    Run /humanbound-test:stop to tear it down."
```

---

## Resume path — polling + findings render

Entered from the orchestrator's `intent=resume <id>` (running-adversarial-tests).
Steps 1–11 of the run flow are skipped — the experiment already exists; we just
observe it and render results inline. This section owns the polling discipline
called out in cross-cutting rule #7.

```
1. Polling loop (max 60 iterations, 15s between):
     a. Call hb_get_experiment_status(experiment_id).
     b. AFTER each call returns, ALWAYS print one readable line directly below
        the JSON receipt — never skip this, even on the very first iteration:
          "  ⠋ status: <status>  ·  <log_count> logs  ·  (HH:MM:SS elapsed)"
        Field rules:
          • <status>     — JSON `status` field, lowercased (e.g. "running")
          • <log_count>  — JSON `log_count` field; omit the segment if missing
          • Rotate the spinner each iteration: ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ ⠋
     c. Terminal check uses lowercased status. If status ∈ {succeeded, failed,
        terminated}:
          • Print "  ✓ status: <status>".
          • Persist the terminal status to state.json so it doesn't stay
            stuck at "running":
              PROJECT="<project>" bash -c "source $LIB/paths.sh; source $LIB/pidfile.sh; \
                update_experiment_status \"<project>\" \"<status>\""
            (Merge-safe: tunnel block and the rest of the experiment block
            are preserved.)
          • Break the polling loop.

2. If still running at iteration 60:
     Print: "  ⚠ still running — experiment_id=<id>. Re-run /humanbound-test:resume <id>."
     Persist {experiment.status="running"} via:
       PROJECT="<project>" bash -c "source $LIB/paths.sh; source $LIB/pidfile.sh; \
         update_experiment_status \"<project>\" \"running\""
     This too is a merge — preserves tunnel state and the rest of the experiment block.
     Stop.

3. Render findings (see reference/findings-renderer.md):
     a. Call hb_get_experiment_logs(experiment_id). Print run summary.
     b. Call hb_list_findings(experiment_id). Print:
          - severity counts: "by severity:    critical=<n>   high=<n>   medium=<n>   low=<n>"
          - top 5 with bullets: "[<SEV>] <title>"
     c. Call hb_get_posture(project_id). Print "posture score: <s> / 100".
     d. Fail-on verdict (uses the `fail_on` value chosen at original dispatch
        — read from state.json if not in scope):
          if any finding.severity >= fail_on:
            print "✗ FAIL: <count> finding(s) at severity >= <fail_on>"
            verdict = "FAIL"
          else:
            print "✓ DONE"
            verdict = "DONE"

     e. Persist a results digest to state.json so `/humanbound-test:status`
        can render last-run info without re-querying MCP:
          PROJECT="<project>" bash -c "source $LIB/paths.sh; source $LIB/pidfile.sh; \
            write_experiment_summary \"<project>\" '<summary-json>'"
        Where <summary-json> is a single-line JSON object built from the
        data already in hand:
          {
            "findings": {"critical":<c>, "high":<h>, "medium":<m>, "low":<l>, "total":<t>},
            "posture":  {"score":<int>, "grade":"<G>"},
            "verdict":  "<DONE|FAIL>",
            "finished_at": "<iso8601-UTC, e.g. 2026-05-12T08:45:00Z>"
          }
        Merge-safe: tunnel state and `experiment.{id,project_id,status}` are
        preserved. Single-quote the JSON arg to avoid shell-escaping the
        inner double-quotes.

4. Always remind:
     "  ⚠ Tunnel is still running at <public-url>"
     "    Run /humanbound-test:stop to tear it down."
```

---

## See also

- `reference/required-data.md` — full ClientBotConfiguration / Project / Experiment schema.
- `reference/findings-renderer.md` — exact terminal layout for the findings block (rendered on the resume path).
