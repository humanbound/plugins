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
