"""Tests for prepare-bot-config.py."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1].parent
SCRIPT = ROOT / "skills" / "dispatching-hb-tests" / "scripts" / "prepare-bot-config.py"

spec = importlib.util.spec_from_file_location("prepare_bot_config", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


# ── prepare: template branch ────────────────────────────────────────────────


def test_prepare_writes_template_when_missing(tmp_path: Path):
    status = mod.prepare(tmp_path, "https://abc-123.ngrok-free.app")
    assert status == "template_created"

    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    assert out.exists()
    data = json.loads(out.read_text())

    assert data["streaming"] is False
    assert data["chat_completion"]["endpoint"].startswith("https://abc-123.ngrok-free.app/")
    assert "<your-chat-path>" in data["chat_completion"]["endpoint"]
    assert data["chat_completion"]["payload"] == {"<your-prompt-field>": "$PROMPT"}
    assert data["thread_init"]["endpoint"].startswith("https://abc-123.ngrok-free.app/")
    assert "<your-thread-path>" in data["thread_init"]["endpoint"]
    assert data["thread_auth"]["endpoint"] == ""  # empty by default (only fill for OAuth)
    assert data["telemetry"] == {}  # empty by default (only fill for whitebox)


# ── prepare: refresh branch ─────────────────────────────────────────────────


def test_prepare_refreshes_ngrok_url_when_file_exists(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "streaming": False,
                "chat_completion": {
                    "endpoint": "https://OLD-host.ngrok-free.app/chat",
                    "headers": {"x-api-key": "sk-test-token"},
                    "payload": {"message": "$PROMPT"},
                },
                "thread_init": {
                    "endpoint": "https://OLD-host.ngrok-free.app/sessions",
                    "headers": {},
                    "payload": {"customer_id": "CUST-001"},
                },
            }
        )
    )

    status = mod.prepare(tmp_path, "https://new-host.ngrok-free.app")
    assert status == "ngrok_refreshed"

    data = json.loads(out.read_text())
    # Endpoints now point at the new host; paths preserved.
    assert data["chat_completion"]["endpoint"] == "https://new-host.ngrok-free.app/chat"
    assert data["thread_init"]["endpoint"] == "https://new-host.ngrok-free.app/sessions"
    # Non-URL fields untouched.
    assert data["chat_completion"]["headers"] == {"x-api-key": "sk-test-token"}
    assert data["chat_completion"]["payload"] == {"message": "$PROMPT"}
    assert data["thread_init"]["payload"] == {"customer_id": "CUST-001"}


def test_prepare_handles_all_three_ngrok_tlds(tmp_path: Path):
    """ngrok-free.app, ngrok.app, ngrok.io should all be replaced."""
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "chat_completion": {"endpoint": "https://old.ngrok.io/chat"},
                "thread_init": {"endpoint": "https://old.ngrok.app/sessions"},
                "thread_auth": {"endpoint": "https://old.ngrok-free.app/oauth/token"},
            }
        )
    )
    mod.prepare(tmp_path, "https://new.ngrok-free.app")
    data = json.loads(out.read_text())
    assert data["chat_completion"]["endpoint"] == "https://new.ngrok-free.app/chat"
    assert data["thread_init"]["endpoint"] == "https://new.ngrok-free.app/sessions"
    assert data["thread_auth"]["endpoint"] == "https://new.ngrok-free.app/oauth/token"


def test_prepare_rejects_non_ngrok_url(tmp_path: Path):
    """If the caller passes a non-ngrok URL during refresh, fail loudly."""
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(json.dumps({"chat_completion": {"endpoint": "https://x.ngrok.app/chat"}}))
    with pytest.raises(ValueError, match="does not match"):
        mod.prepare(tmp_path, "http://localhost:8000")


# ── validate: happy path ────────────────────────────────────────────────────


def test_validate_passes_on_well_formed_config(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "streaming": False,
                "chat_completion": {
                    "endpoint": "https://abc.ngrok-free.app/chat",
                    "headers": {"x-api-key": "sk-test"},
                    "payload": {"message": "$PROMPT"},
                },
            }
        )
    )
    ok, msg = mod.validate(tmp_path)
    assert ok, msg
    assert msg == "ready"


# ── validate: failure cases ─────────────────────────────────────────────────


def test_validate_fails_on_missing_file(tmp_path: Path):
    ok, msg = mod.validate(tmp_path)
    assert not ok
    assert "not found" in msg


def test_validate_fails_on_invalid_json(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text("not valid json {{{")
    ok, msg = mod.validate(tmp_path)
    assert not ok
    assert "json" in msg.lower()


def test_validate_fails_on_placeholder_path(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "chat_completion": {
                    "endpoint": "https://abc.ngrok-free.app/<your-chat-path>",
                    "payload": {"message": "$PROMPT"},
                },
            }
        )
    )
    ok, msg = mod.validate(tmp_path)
    assert not ok
    assert "placeholder" in msg.lower()


def test_validate_fails_on_missing_prompt_placeholder(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "chat_completion": {
                    "endpoint": "https://abc.ngrok-free.app/chat",
                    "payload": {"message": "hello"},  # no $PROMPT
                },
            }
        )
    )
    ok, msg = mod.validate(tmp_path)
    assert not ok
    assert "$PROMPT" in msg


def test_validate_fails_on_localhost_endpoint(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "chat_completion": {
                    "endpoint": "http://localhost:8000/chat",
                    "payload": {"message": "$PROMPT"},
                },
            }
        )
    )
    ok, msg = mod.validate(tmp_path)
    assert not ok
    assert "localhost" in msg.lower()


def test_validate_fails_on_empty_payload(tmp_path: Path):
    out = tmp_path / ".humanbound" / "test" / "bot-config.json"
    out.parent.mkdir(parents=True)
    out.write_text(
        json.dumps(
            {
                "chat_completion": {
                    "endpoint": "https://abc.ngrok-free.app/chat",
                    "payload": {},
                },
            }
        )
    )
    ok, msg = mod.validate(tmp_path)
    assert not ok
    assert "payload" in msg.lower()
