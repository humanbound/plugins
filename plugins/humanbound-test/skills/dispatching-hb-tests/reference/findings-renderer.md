# Findings render — exact terminal layout

Print this block after polling completes:

```
━━━ Findings ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  by severity:    critical=<C>   high=<H>   medium=<M>   low=<L>

  top findings:
  • [HIGH] <finding 1 title>
  • [HIGH] <finding 2 title>
  • [MED]  <finding 3 title>
  • [MED]  <finding 4 title>
  • [LOW]  <finding 5 title>

  posture score:  <score> / 100   (was: <previous-score> | n/a — first run)

  ✗ FAIL: <n> finding(s) at severity ≥ <fail-on>     # if fail
  or
  ✓ DONE                                              # if pass

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ⚠ Tunnel is still running at <public-url>
    Run /humanbound-test:stop to tear it down.
```

## Spec details

- Severity tag in brackets is right-padded to 4 chars: `[HIGH]`, `[MED] `, `[LOW] ` (note the trailing space for MED/LOW so titles align).
- Top findings: at most 5; sort severity desc then by occurrence order in `hb_list_findings`.
- Posture score: integer 0–100. "Previous-score" comes from a prior run on the same project (call `hb_get_posture` before the new test runs and stash; if no prior data, print "n/a — first run").
- Fail-on threshold ranks: none < low < medium < high < critical. A finding "meets" the threshold if its severity >= the chosen level. If `fail_on = "none"`, never fail.
