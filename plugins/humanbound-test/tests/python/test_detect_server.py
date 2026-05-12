"""Tests for skills/tunneling-local-agent/scripts/detect-server.py."""
from __future__ import annotations

from pathlib import Path

import pytest

from detect_server import detect, detect_json


# ---------- fixtures ----------

@pytest.fixture
def fastapi_project(tmp_path: Path) -> Path:
    """A minimal uv-managed FastAPI project."""
    (tmp_path / "pyproject.toml").write_text(
        '[project]\nname = "demo"\nversion = "0.1.0"\n'
        'dependencies = ["fastapi[standard]>=0.110"]\n'
    )
    (tmp_path / "uv.lock").write_text("# fake lock\n")
    (tmp_path / "main.py").write_text(
        "from fastapi import FastAPI\napp = FastAPI()\n"
    )
    return tmp_path


@pytest.fixture
def empty_project(tmp_path: Path) -> Path:
    """No recognizable framework markers."""
    return tmp_path


# ---------- detect_json shape ----------

def test_detect_json_fastapi(fastapi_project: Path):
    result = detect_json(fastapi_project)
    assert result["framework"] == "fastapi"
    assert result["detected"]["server.provider"] == "fastapi"
    assert result["detected"]["server.entry_point"] == "main:app"
    assert result["detected"]["server.port"] == 8000
    assert result["detected"]["server.package_mgr"] == "uv"
    assert result["detected"]["tunnel.provider"] == "ngrok"
    assert result["detected"]["tunnel.ngrok.region"] == "us"
    assert "tunnel.ngrok.domain" in result["unknown"]
    assert "tunnel.ngrok.basic_auth" in result["unknown"]


def test_detect_json_unknown(empty_project: Path):
    """No recovery path for non-FastAPI projects.

    `unknown` must be empty (the orchestrator surfaces an actionable
    error instead of prompting through a long form). `detected` carries
    only the schema marker — there's nothing else to emit without a
    framework.
    """
    result = detect_json(empty_project)
    assert result["framework"] is None
    assert result["unknown"] == []
    assert result["detected"] == {"schema": 1}


# ---------- legacy detect() compat (used by --write) ----------

def test_detect_legacy_fastapi_returns_full_dict(fastapi_project: Path):
    """The pre-existing detect() API must keep working for --write."""
    spec = detect(fastapi_project)
    assert spec is not None
    assert spec["server"]["provider"] == "fastapi"
    assert spec["server"]["port"] == 8000
    assert spec["tunnel"]["ngrok"]["basic_auth"] == ""  # legacy default


def test_detect_legacy_unknown_returns_none(empty_project: Path):
    assert detect(empty_project) is None


# ---------- CLI: --json ----------

def test_cli_json_fastapi(fastapi_project: Path, capsys: pytest.CaptureFixture):
    import json
    from detect_server import _main
    rc = _main([str(fastapi_project), "--json"])
    assert rc == 0
    out = capsys.readouterr().out
    payload = json.loads(out)
    assert payload["framework"] == "fastapi"
    assert payload["detected"]["server.entry_point"] == "main:app"
    assert "tunnel.ngrok.basic_auth" in payload["unknown"]


def test_cli_json_unknown(empty_project: Path, capsys: pytest.CaptureFixture):
    import json
    from detect_server import _main
    rc = _main([str(empty_project), "--json"])
    assert rc == 0  # unknown is not an error in --json mode
    payload = json.loads(capsys.readouterr().out)
    assert payload["framework"] is None
    assert payload["unknown"] == []


# ---------- CLI: --write-from-json ----------

EXHAUSTIVE_PAYLOAD = {
    "schema": 1,
    "server.provider": "fastapi",
    "server.entry_point": "app:app",
    "server.host": "127.0.0.1",
    "server.port": 9000,
    "server.package_mgr": "uv",
    "server.health_path": "/healthz",
    "tunnel.provider": "ngrok",
    "tunnel.ngrok.region": "eu",
    "tunnel.ngrok.domain": "demo.ngrok.app",
    "tunnel.ngrok.basic_auth": "alice:secret",
}


def test_write_from_json_str_round_trip(tmp_path: Path):
    import json
    import tomllib
    from detect_server import write_from_json_str  # added in Task 3
    write_from_json_str(tmp_path, json.dumps(EXHAUSTIVE_PAYLOAD))
    out = tmp_path / ".humanbound" / "test" / "config.toml"
    assert out.exists()
    parsed = tomllib.loads(out.read_text())
    assert parsed["schema"] == 1
    assert parsed["server"]["provider"] == "fastapi"
    assert parsed["server"]["entry_point"] == "app:app"
    assert parsed["server"]["port"] == 9000
    assert parsed["server"]["health_path"] == "/healthz"
    assert parsed["tunnel"]["ngrok"]["region"] == "eu"
    assert parsed["tunnel"]["ngrok"]["domain"] == "demo.ngrok.app"
    assert parsed["tunnel"]["ngrok"]["basic_auth"] == "alice:secret"


def test_cli_write_from_json_via_stdin(tmp_path: Path, monkeypatch, capsys):
    """The CLI reads JSON from stdin (so the skill can pipe it via shell)."""
    import io
    import json
    import tomllib
    from detect_server import _main
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(EXHAUSTIVE_PAYLOAD)))
    rc = _main([str(tmp_path), "--write-from-json"])
    assert rc == 0
    out_path = tmp_path / ".humanbound" / "test" / "config.toml"
    assert out_path.exists()
    parsed = tomllib.loads(out_path.read_text())
    assert parsed["server"]["port"] == 9000


def test_cli_write_from_json_invalid_json_returns_error(
    tmp_path: Path, monkeypatch, capsys
):
    import io
    from detect_server import _main
    monkeypatch.setattr("sys.stdin", io.StringIO("not json"))
    rc = _main([str(tmp_path), "--write-from-json"])
    assert rc == 4  # JSONDecodeError → exit 4
    err = capsys.readouterr().err
    assert "json" in err.lower() or "decode" in err.lower()


def test_cli_write_from_json_non_dict_top_level_returns_5(
    tmp_path: Path, monkeypatch, capsys
):
    """A JSON list (not a dict) should hit the explicit isinstance check → rc 5."""
    import io
    import json
    from detect_server import _main
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps([1, 2, 3])))
    rc = _main([str(tmp_path), "--write-from-json"])
    assert rc == 5  # ValueError ("expected a JSON object at the top level") → exit 5
    err = capsys.readouterr().err
    assert "invalid payload" in err.lower()


# ── New tests for the extended schema (humanbound-test additions) ─────────────

def test_fastapi_does_not_emit_agent_section(tmp_path: Path):
    """Agent endpoint configuration was moved to bot-config.json (user-authored).
    detect-server.py must NOT write any [agent.*] placeholder fields anymore."""
    (tmp_path / "pyproject.toml").write_text('[project]\nname="x"\ndependencies=["fastapi"]\n')
    (tmp_path / "main.py").write_text("from fastapi import FastAPI\napp = FastAPI()\n")
    spec = detect(tmp_path)
    assert "agent" not in spec
    # Confirm none of the old agent.* fields leaked
    flat_keys = " ".join(str(k) for k in spec.keys())
    assert "agent" not in flat_keys


def test_fastapi_does_not_emit_test_section(tmp_path: Path):
    """Test-run config (category, testing_level, fail_on) is collected
    per-run by the dispatching skill via AskUserQuestion — not persisted
    in config.toml. detect-server.py must NOT write a [test] block."""
    (tmp_path / "pyproject.toml").write_text('[project]\nname="x"\ndependencies=["fastapi"]\n')
    (tmp_path / "main.py").write_text("from fastapi import FastAPI\napp = FastAPI()\n")
    spec = detect(tmp_path)
    assert "test" not in spec


def test_fastapi_does_not_emit_runtime_section(tmp_path: Path):
    """Runtime config was removed — state is always project-local."""
    (tmp_path / "pyproject.toml").write_text('[project]\nname="x"\ndependencies=["fastapi"]\n')
    (tmp_path / "main.py").write_text("from fastapi import FastAPI\napp = FastAPI()\n")
    spec = detect(tmp_path)
    assert "runtime" not in spec


def test_unknown_framework_emits_only_schema(tmp_path: Path):
    (tmp_path / "Makefile").write_text("all:\n\techo hi\n")
    j = detect_json(tmp_path)
    # Without a framework: just the schema marker.
    assert j["detected"] == {"schema": 1}
    assert "runtime.state_location" not in j["detected"]
    assert "runtime.secret_location" not in j["detected"]
