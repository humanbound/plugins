# Runtime summary template

The canonical summary block format lives in `dispatching-hb-tests/SKILL.md` Step 7
(the source of truth). This file exists for cross-reference only — when the format
there changes, this file should be deleted or re-synced.

Current format (single-line-per-row, middle-dot separators, no sub-blocks):

```
──────────────────────────────────────────────────────────────────
  Project      {A | B} · {project_name}{suffix}
  Public URL   {public_url}
  Agent        {chat_path} · {thread_path} · streaming {on|off} · auth {type}
  Test         {category_short} · {testing_level} · fail-on {fail_on}
  Run name     {run_name}
  Judge        {n} chars
  Bot config   .humanbound/test/bot-config.json
──────────────────────────────────────────────────────────────────
```

Field-rendering rules: see `dispatching-hb-tests/SKILL.md` Step 7 for the
authoritative list. Highlights:
- `{suffix}` is " (new)" on Path A, " (override)" on Path B-with-override, empty otherwise
- `{chat_path}` / `{thread_path}` are path-only — the public URL is already shown above
- `streaming` and `auth` segments may be omitted if not inferrable
- `{category_short}` drops the `humanbound/adversarial/` prefix
- Bot-config path is relative to the project

Scope and capabilities are NOT shown — they're auto-defaulted in the dispatch
call (see Step 9 in `dispatching-hb-tests/SKILL.md`) rather than prompted.
