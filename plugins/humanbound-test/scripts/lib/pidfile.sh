#!/usr/bin/env bash
# pidfile.sh — project state file management.
# Requires HB_TEST_STATE_DIR (exported by paths.sh).

# state_path <abs-path>: print the absolute path to the state JSON file.
# The state directory is resolved by paths.sh and exported as HB_TEST_STATE_DIR.
# The state filename is always "state.json" because paths.sh handles the
# project-local vs. user-global disambiguation via directory structure.
state_path() {
  printf '%s' "$HB_TEST_STATE_DIR/state.json"
}

# write_state <abs-path> <server_pid> <tunnel_pid> <url> <port> <provider>
write_state() {
  local path="$1" sp="$2" tp="$3" url="$4" port="$5" provider="$6"
  local out
  out=$(state_path "$path")
  mkdir -p "$(dirname "$out")"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$out" <<EOF
{
  "project_path": "$path",
  "started_at": "$now",
  "server_pid": $sp,
  "tunnel_pid": $tp,
  "public_url": "$url",
  "port": $port,
  "tunnel_provider": "$provider"
}
EOF
}

# read_state <abs-path>: print the state JSON, or exit non-zero if missing.
read_state() {
  local f
  f=$(state_path "$1")
  [ -f "$f" ] || return 1
  cat "$f"
}

# clear_state <abs-path>
clear_state() {
  local f
  f=$(state_path "$1")
  rm -f "$f"
}

# is_running <pid>: exit 0 if the process is alive, 1 otherwise.
is_running() {
  kill -0 "$1" 2>/dev/null
}
