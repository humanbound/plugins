#!/usr/bin/env bash
# ngrok.sh — ngrok tunnel provider.

ngrok_check_installed() {
  command -v ngrok >/dev/null 2>&1
}

ngrok_check_authed() {
  ngrok config check >/dev/null 2>&1
}

ngrok_install_token() {
  local token="$1"
  ngrok config add-authtoken "$token"
}

# ngrok_start <port> [basic_auth] [domain] [region]
# Exec's into ngrok so the caller's PID becomes the ngrok process.
ngrok_start() {
  local port="$1" basic_auth="${2:-}" domain="${3:-}" region="${4:-us}"
  local args=(http "$port" --log=stdout --region "$region")
  [ -n "$basic_auth" ] && args+=(--basic-auth "$basic_auth")
  [ -n "$domain" ] && args+=(--domain "$domain")
  exec ngrok "${args[@]}"
}

# ngrok_fetch_url: query the local ngrok agent on 4040 for the https public_url.
# Retries for ~10s, exits non-zero on timeout.
ngrok_fetch_url() {
  local resp url
  for _ in $(seq 1 20); do
    if resp=$(curl -sSf --max-time 1 http://127.0.0.1:4040/api/tunnels 2>/dev/null); then
      url=$(printf '%s' "$resp" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for t in data.get("tunnels", []):
    if t.get("proto") == "https" or t.get("public_url", "").startswith("https"):
        print(t["public_url"]); break
')
      if [ -n "$url" ]; then
        printf '%s\n' "$url"
        return 0
      fi
    fi
    sleep 0.5
  done
  return 1
}
