#!/usr/bin/env bash
# fastapi.sh — start a FastAPI app via uvicorn, health-check it.

# _fastapi_pick_python <project>: prefer a project-local venv over system python3.
# Looks in this order: .venv/bin/python, venv/bin/python, .venv/Scripts/python.exe (cross-plat),
# else falls back to python3 on PATH. Prints the resolved interpreter to stdout.
_fastapi_pick_python() {
  local project="$1"
  for candidate in "$project/.venv/bin/python" "$project/venv/bin/python" "$project/.venv/Scripts/python.exe" "$project/venv/Scripts/python.exe"; do
    if [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf 'python3'
}

# fastapi_start <project> <entry_point> <host> <port> <package_mgr>
# Exec's into the runner so the calling process IS the server (use & in caller).
fastapi_start() {
  local project="$1" entry="$2" host="$3" port="$4" mgr="$5"
  cd "$project" || return 1
  case "$mgr" in
    uv)     exec uv     run uvicorn "$entry" --host "$host" --port "$port" ;;
    poetry) exec poetry run uvicorn "$entry" --host "$host" --port "$port" ;;
    pipenv) exec pipenv run uvicorn "$entry" --host "$host" --port "$port" ;;
    pip|none|*)
      local py
      py="$(_fastapi_pick_python "$project")"
      exec "$py" -m uvicorn "$entry" --host "$host" --port "$port"
      ;;
  esac
}

# fastapi_health <host> <port> <path>: exit 0 if reachable with 2xx/3xx within ~10s.
fastapi_health() {
  local host="$1" port="$2" path="$3"
  local url="http://$host:$port$path"
  for _ in $(seq 1 20); do
    if curl -sSf -o /dev/null --max-time 1 "$url"; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}
