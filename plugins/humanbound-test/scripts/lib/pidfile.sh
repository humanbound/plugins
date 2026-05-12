#!/usr/bin/env bash
# pidfile.sh — project state file management.
#
# state.json is a SINGLE merged document holding both tunnel state (server_pid,
# tunnel_pid, public_url, ...) and experiment state ({id, project_id, status}).
# All write helpers below MERGE into the existing file so concurrent concerns
# never clobber each other — a regression we hit in v0.1.0 where the dispatch
# step was overwriting the tunnel block.
#
# Requires HB_TEST_STATE_DIR (exported by paths.sh).
# Requires Python 3.11+ (stdlib `json`) — already a hard plugin dep.

# state_path <abs-project-path>: print the absolute path to the state JSON file.
state_path() {
  printf '%s' "$HB_TEST_STATE_DIR/state.json"
}

# write_state <abs-project-path> <server_pid> <tunnel_pid> <url> <provider>
# Merges the tunnel fields into state.json. Any existing `experiment` block is
# preserved untouched. Local port is NOT stored here — read config.toml for that.
write_state() {
  local path="$1" sp="$2" tp="$3" url="$4" provider="$5" out now
  out=$(state_path "$path")
  mkdir -p "$(dirname "$out")"
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 - "$out" "$path" "$now" "$sp" "$tp" "$url" "$provider" <<'PY'
import json, os, sys
out, project, now, sp, tp, url, provider = sys.argv[1:8]
data = {}
if os.path.exists(out):
    try:
        with open(out) as f:
            data = json.load(f)
    except Exception:
        data = {}
data.update({
    "project_path": project,
    "started_at":   now,
    "server_pid":   int(sp),
    "tunnel_pid":   int(tp),
    "public_url":   url,
    "tunnel_provider": provider,
})
with open(out, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# write_experiment <abs-project-path> <experiment_id> <project_id> <status>
# Merges the `experiment` block into state.json. Tunnel fields are preserved.
write_experiment() {
  local path="$1" exp_id="$2" proj_id="$3" status="$4" out
  out=$(state_path "$path")
  mkdir -p "$(dirname "$out")"
  python3 - "$out" "$exp_id" "$proj_id" "$status" <<'PY'
import json, os, sys
out, exp_id, proj_id, status = sys.argv[1:5]
data = {}
if os.path.exists(out):
    try:
        with open(out) as f:
            data = json.load(f)
    except Exception:
        data = {}
data["experiment"] = {
    "id":         exp_id,
    "project_id": proj_id,
    "status":     status,
}
with open(out, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# update_experiment_status <abs-project-path> <status>
# Updates only `experiment.status`. Everything else preserved. No-op if there
# is no state.json or no existing experiment block.
update_experiment_status() {
  local path="$1" status="$2" out
  out=$(state_path "$path")
  [ -f "$out" ] || return 0
  python3 - "$out" "$status" <<'PY'
import json, sys
out, status = sys.argv[1], sys.argv[2]
with open(out) as f:
    data = json.load(f)
if "experiment" not in data:
    data["experiment"] = {}
data["experiment"]["status"] = status
with open(out, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# write_experiment_summary <abs-project-path> <summary-json>
# Merges a results digest into experiment.summary. <summary-json> is a JSON
# object string, typically:
#   {"findings":{"critical":N,"high":N,"medium":N,"low":N,"total":N},
#    "posture":{"score":N,"grade":"X"},"verdict":"DONE|FAIL",
#    "finished_at":"<iso8601>"}
# Tunnel state and the rest of the experiment block are preserved. Returns 1
# if state.json doesn't exist yet (caller should write_experiment first).
write_experiment_summary() {
  local path="$1" summary_json="$2" out
  out=$(state_path "$path")
  [ -f "$out" ] || return 1
  python3 - "$out" "$summary_json" <<'PY'
import json, sys
out, summary_json = sys.argv[1], sys.argv[2]
summary = json.loads(summary_json)
with open(out) as f:
    data = json.load(f)
data.setdefault("experiment", {})["summary"] = summary
with open(out, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# read_state <abs-project-path>: print state.json contents; exit 1 if missing.
read_state() {
  local f
  f=$(state_path "$1")
  [ -f "$f" ] || return 1
  cat "$f"
}

# clear_state <abs-project-path>: delete the entire state file.
clear_state() {
  local f
  f=$(state_path "$1")
  rm -f "$f"
}

# is_running <pid>: exit 0 if the process is alive, 1 otherwise.
is_running() {
  kill -0 "$1" 2>/dev/null
}
