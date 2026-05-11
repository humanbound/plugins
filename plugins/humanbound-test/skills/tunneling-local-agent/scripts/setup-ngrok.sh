#!/usr/bin/env bash
# setup-ngrok.sh (humanbound-test) — interactive (model-relayed) install + auth flow for ngrok.
#
# Modes:
#   --status            Print install/auth state. Exit 0 only if fully ready.
#   --install           Run the OS install (brew install ngrok, etc.). Requires confirmation upstream.
#   --auth <token>      Save the auth token via `ngrok config add-authtoken`.
#
# The `tunneling-local-agent` skill is responsible for the user-facing dialog —
# this script just exposes the verbs.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../../../scripts/lib"
# shellcheck disable=SC1091
source "$LIB/log.sh"
# shellcheck disable=SC1091
source "$LIB/paths.sh"

mode="${1:---status}"

case "$mode" in
  --status)
    if ! command -v ngrok >/dev/null 2>&1; then
      echo "ngrok: not installed"
      echo "authtoken: unknown (ngrok missing)"
      echo
      if command -v brew >/dev/null 2>&1; then
        echo "Suggested install: brew install ngrok"
      elif command -v apt-get >/dev/null 2>&1; then
        echo "Suggested install: see https://ngrok.com/download (apt repo)"
      else
        echo "Suggested install: download from https://ngrok.com/download"
      fi
      exit 1
    fi
    echo "ngrok: installed ($(ngrok version 2>/dev/null | head -1))"
    if ngrok config check >/dev/null 2>&1; then
      echo "authtoken: configured"
      echo "ready"
      exit 0
    else
      echo "authtoken: missing"
      echo
      echo "Visit https://dashboard.ngrok.com/get-started/your-authtoken to copy your token,"
      echo "then re-run with: /humanbound-test:setup and paste the token when prompted."
      exit 1
    fi
    ;;

  --install)
    if command -v ngrok >/dev/null 2>&1; then
      echo "ngrok already installed; skipping"
      exit 0
    fi
    if command -v brew >/dev/null 2>&1; then
      brew install ngrok
    elif command -v apt-get >/dev/null 2>&1; then
      log_error "automated apt install not implemented — see https://ngrok.com/download"
      exit 1
    else
      log_error "no supported package manager. Install manually from https://ngrok.com/download"
      exit 1
    fi
    ;;

  --auth)
    token="${2:-}"
    if [ -z "$token" ]; then
      log_error "missing token. Usage: setup-ngrok.sh --auth <token>"
      exit 1
    fi
    ngrok config add-authtoken "$token"
    echo "ngrok ready"
    ;;

  *)
    log_error "unknown mode: $mode"
    echo "Usage: setup-ngrok.sh [--status | --install | --auth <token>]"
    exit 2
    ;;
esac
