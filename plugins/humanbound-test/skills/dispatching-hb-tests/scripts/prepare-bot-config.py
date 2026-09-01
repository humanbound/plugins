#!/usr/bin/env python3
"""prepare-bot-config.py — manage <project>/.humanbound/test/bot-config.json.

The plugin doesn't auto-discover agent endpoints. Instead, the user authors
bot-config.json once, and this script keeps the ngrok URL portion fresh
across runs.

Usage:
    python3 prepare-bot-config.py prepare  <project-dir> <ngrok-public-url>
    python3 prepare-bot-config.py validate <project-dir>

`prepare` is idempotent:
  - If bot-config.json doesn't exist → write a template with the current
    ngrok URL pre-filled and `<your-...>` placeholders for fields only the
    user knows. Exit 0; print "template_created".
  - If bot-config.json exists → find ngrok-host URL portions in the agent
    endpoint fields (chat_completion / thread_init / thread_auth) and
    replace each with the current ngrok host. Paths preserved.
    Exit 0; print "ngrok_refreshed".

`validate` checks the file is ready for dispatch:
  - exists + parses as JSON
  - chat_completion.endpoint non-empty AND no `<your-` placeholders
  - chat_completion.payload contains the literal `$PROMPT` placeholder
  - no localhost / 127.0.0.1 in any endpoint
Exit 0 if ready, non-zero with a clear error message otherwise.

SPDX-License-Identifier: Apache-2.0
Copyright (c) 2024-2026 Humanbound
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

# Match the HOST portion of a ngrok URL — paths after the host are NOT matched.
NGROK_HOST_RE = re.compile(r"https?://[a-zA-Z0-9\-]+\.(?:ngrok-free\.app|ngrok\.app|ngrok\.io)")

LOCALHOST_PATTERNS = ("localhost", "127.0.0.1", "0.0.0.0", "::1")

DOCS_URL = "https://docs.humanbound.ai/getting-started/agent-config/"

AGENT_SECTIONS = ("chat_completion", "thread_init", "thread_auth")


# ── public API ──────────────────────────────────────────────────────────────


def config_path(project: Path) -> Path:
    return Path(project) / ".humanbound" / "test" / "bot-config.json"


def template(ngrok_url: str) -> dict[str, Any]:
    """Starter bot-config with the current ngrok host pre-filled."""
    match = NGROK_HOST_RE.match(ngrok_url)
    base = match.group(0) if match else ngrok_url.rstrip("/")
    return {
        "streaming": False,
        "chat_completion": {
            "endpoint": f"{base}/<your-chat-path>",
            "headers": {},
            "payload": {"<your-prompt-field>": "$PROMPT"},
        },
        "thread_init": {
            "endpoint": f"{base}/<your-thread-path>",
            "headers": {},
            "payload": {},
        },
        "thread_auth": {
            "endpoint": "",
            "headers": {},
            "payload": {},
        },
        "telemetry": {},
    }


def refresh_ngrok_urls(data: dict[str, Any], new_host: str) -> dict[str, Any]:
    """In-place: replace ngrok host portions in the agent endpoint fields."""
    for section in AGENT_SECTIONS:
        block = data.get(section)
        if not isinstance(block, dict):
            continue
        endpoint = block.get("endpoint", "")
        if isinstance(endpoint, str) and endpoint:
            block["endpoint"] = NGROK_HOST_RE.sub(new_host, endpoint)
    return data


def prepare(project: Path, ngrok_url: str) -> str:
    """Idempotent template-or-refresh. Returns a one-word status string."""
    path = config_path(project)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(template(ngrok_url), indent=2) + "\n")
        return "template_created"

    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError("bot-config.json is not a JSON object at the top level")

    host_match = NGROK_HOST_RE.match(ngrok_url)
    if not host_match:
        raise ValueError(f"ngrok-url does not match expected pattern: {ngrok_url!r}")
    new_host = host_match.group(0)

    refresh_ngrok_urls(data, new_host)
    path.write_text(json.dumps(data, indent=2) + "\n")
    return "ngrok_refreshed"


def validate(project: Path) -> tuple[bool, str]:
    """Check that bot-config.json is filled in enough to dispatch."""
    path = config_path(project)
    if not path.exists():
        return False, f"bot-config.json not found at {path}"

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        return False, f"bot-config.json is not valid JSON: {e}"

    chat = data.get("chat_completion") or {}
    endpoint = chat.get("endpoint", "")
    if not endpoint:
        return False, "chat_completion.endpoint is empty"
    if "<your-" in endpoint:
        return False, (
            f"chat_completion.endpoint still has a placeholder ({endpoint!r}); "
            "replace `<your-chat-path>` with your agent's actual chat path"
        )
    for host in LOCALHOST_PATTERNS:
        if host in endpoint.lower():
            return False, (
                f"chat_completion.endpoint contains localhost ({host}); the "
                "test harness needs the public ngrok URL, not a local URL"
            )

    payload = chat.get("payload")
    if not isinstance(payload, dict) or not payload:
        return False, (
            "chat_completion.payload is empty; the agent needs a request body "
            'shape (e.g., {"message": "$PROMPT"})'
        )
    if "$PROMPT" not in json.dumps(payload):
        return False, (
            "chat_completion.payload is missing the $PROMPT placeholder — the "
            "test harness substitutes each attack prompt at that token"
        )

    return True, "ready"


# ── CLI ─────────────────────────────────────────────────────────────────────


def _main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="mode", required=True)

    p_prepare = sub.add_parser("prepare", help="write template or refresh ngrok URLs")
    p_prepare.add_argument("project", type=Path)
    p_prepare.add_argument("ngrok_url")

    p_validate = sub.add_parser("validate", help="check bot-config.json is ready for dispatch")
    p_validate.add_argument("project", type=Path)

    args = parser.parse_args(argv)

    if args.mode == "prepare":
        try:
            status = prepare(args.project, args.ngrok_url)
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            return 2
        print(status)
        if status == "template_created":
            print(f"reference: {DOCS_URL}", file=sys.stderr)
        return 0

    if args.mode == "validate":
        ok, msg = validate(args.project)
        print(msg)
        return 0 if ok else 3

    return 1


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
