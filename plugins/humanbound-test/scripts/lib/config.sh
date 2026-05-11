#!/usr/bin/env bash
# config.sh — read/write the project's .humanbound/test/config.toml.
# Uses python3 -c "import tomllib" for parsing (Python 3.11+).

config_path() {
  local project="$1"
  printf '%s' "$project/.humanbound/test/config.toml"
}

config_exists() {
  local project="$1"
  [ -f "$(config_path "$project")" ]
}

# config_get <project> <dotted.key>
# Reads .humanbound/test/config.toml and prints the value at the dotted key.
# Empty output if missing.
config_get() {
  local project="$1" key="$2" file
  file=$(config_path "$project")
  [ -f "$file" ] || return 0
  python3 - "$file" "$key" <<'PY'
import sys, tomllib
path, key = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = tomllib.load(f)
node = data
for part in key.split("."):
    if isinstance(node, dict) and part in node:
        node = node[part]
    else:
        sys.exit(0)
if isinstance(node, (str, int, float, bool)):
    print(node)
elif isinstance(node, list):
    print(",".join(str(x) for x in node))
PY
}

# config_get_runtime <project> <key>: read a [runtime].<key> value from config.toml.
# Prints empty string if missing.
config_get_runtime() {
  local project="$1" key="$2" toml
  toml=$(config_path "$project")
  [ -f "$toml" ] || { printf ''; return 0; }
  python3 - "$toml" "$key" <<'PY'
import sys, tomllib, pathlib
toml_path, key = sys.argv[1], sys.argv[2]
data = tomllib.loads(pathlib.Path(toml_path).read_text())
print((data.get("runtime") or {}).get(key, ""))
PY
}

# config_get_agent_path <project> <endpoint>: read [agent.<endpoint>].path
# <endpoint> is "chat_completion" | "thread_init" | "thread_auth"
config_get_agent_path() {
  local project="$1" endpoint="$2" toml
  toml=$(config_path "$project")
  [ -f "$toml" ] || { printf ''; return 0; }
  python3 - "$toml" "$endpoint" <<'PY'
import sys, tomllib, pathlib
toml_path, endpoint = sys.argv[1], sys.argv[2]
data = tomllib.loads(pathlib.Path(toml_path).read_text())
agent = data.get("agent") or {}
print((agent.get(endpoint) or {}).get("path", ""))
PY
}

# config_has_section <project> <section>: returns 0 if section exists, 1 otherwise.
# <section> can be dotted: "agent.chat_completion"
config_has_section() {
  local project="$1" section="$2" toml
  toml=$(config_path "$project")
  [ -f "$toml" ] || return 1
  python3 - "$toml" "$section" <<'PY'
import sys, tomllib, pathlib
toml_path, section = sys.argv[1], sys.argv[2]
data = tomllib.loads(pathlib.Path(toml_path).read_text())
node = data
for part in section.split("."):
    if not isinstance(node, dict) or part not in node:
        sys.exit(1)
    node = node[part]
sys.exit(0)
PY
}
