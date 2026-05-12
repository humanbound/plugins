#!/usr/bin/env python3
"""detect-server.py — humanbound-test: detect the project shape and emit a config dict / TOML.

Usage (CLI):
    python3 detect-server.py <project-dir>                    # print detected TOML
    python3 detect-server.py <project-dir> --write            # write to <project>/.humanbound/test/config.toml
    python3 detect-server.py <project-dir> --json             # emit {framework, detected, unknown} JSON
    python3 detect-server.py <project-dir> --write-from-json  # read flat-dotted JSON dict from stdin, write TOML
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any


# --- public API -------------------------------------------------------------

def detect(project: Path) -> dict[str, Any] | None:
    """Legacy: full nested dict (with hardcoded defaults for unknowns), or None.

    Used by `--write` mode and existing tests. The `--json` mode uses
    `detect_json` instead.
    """
    result = detect_json(project)
    # framework=None is the only branch that legacy callers want as None;
    # `detected` is always at least {"schema": 1} so checking emptiness is moot.
    if result["framework"] is None:
        return None
    return _to_legacy_dict(result["detected"], result["unknown"])


def detect_json(project: Path) -> dict[str, Any]:
    """Return {framework, detected, unknown}.

    `detected` is a flat dict of dotted-key -> value (only fields we could
    confidently infer). `unknown` is a list of dotted-key paths the caller
    must collect from the user. `framework` is "fastapi" | None.

    Currently supports FastAPI first-class only. Other frameworks return
    `framework=None` and the orchestrator surfaces an actionable error.
    """
    project = Path(project).resolve()
    if _is_fastapi(project):
        det, unk = _build_fastapi_parts(project)
        return {"framework": "fastapi", "detected": det, "unknown": unk}
    det, unk = _build_unknown_parts()
    return {"framework": None, "detected": det, "unknown": unk}


def write_toml(path: Path, spec: dict[str, Any]) -> None:
    """Write spec as TOML to path, creating parents as needed."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(_render_toml(spec))


def write_from_json_str(project: Path, json_str: str) -> Path:
    """Parse a flat-dotted JSON dict and write it as TOML to <project>/.humanbound/test/config.toml.

    Returns the path written. Raises json.JSONDecodeError on bad input,
    ValueError if dotted paths collide.
    """
    flat = json.loads(json_str)
    if not isinstance(flat, dict):
        raise ValueError("expected a JSON object at the top level")
    nested = _expand_dotted(flat)
    out = Path(project) / ".humanbound" / "test" / "config.toml"
    write_toml(out, nested)
    return out


# --- builders ---------------------------------------------------------------

# Tunnel fields the user must always supply (regardless of detected framework).
_TUNNEL_UNKNOWNS: list[str] = ["tunnel.ngrok.domain", "tunnel.ngrok.basic_auth"]


def _build_fastapi_parts(project: Path) -> tuple[dict[str, Any], list[str]]:
    """Detected fields for a FastAPI project. Server + tunnel only.

    Agent endpoints (chat path, payload, auth, etc.) are not detected by
    this script — the user authors `bot-config.json` directly. See
    `prepare-bot-config.py`. Test-run config (category, testing_level,
    fail_on) is collected per-run by the dispatching skill, not persisted
    here.
    """
    entry = _find_fastapi_entry_point(project) or "main:app"
    detected: dict[str, Any] = {
        "schema": 1,
        "server.provider": "fastapi",
        "server.entry_point": entry,
        "server.host": "127.0.0.1",
        "server.port": 8000,
        "server.package_mgr": _detect_package_mgr(project),
        "server.health_path": "/",
        "tunnel.provider": "ngrok",
        "tunnel.ngrok.region": "us",
    }
    return detected, list(_TUNNEL_UNKNOWNS)


def _build_unknown_parts() -> tuple[dict[str, Any], list[str]]:
    """No FastAPI detected — emit schema only, no `unknown` fields.
    There is no recovery path for non-FastAPI projects. The orchestrator
    must error out with an actionable message pointing users at the ROADMAP."""
    return {"schema": 1}, []


# --- conversion helpers -----------------------------------------------------

def _to_legacy_dict(detected: dict[str, Any], unknown: list[str]) -> dict[str, Any]:
    """Reconstruct the nested dict shape the old detect() returned.

    Detected paths get their inferred values; unknown paths get "" (legacy
    default). `schema` becomes a top-level int.
    """
    full: dict[str, Any] = dict(detected)
    for path in unknown:
        full[path] = ""
    return _expand_dotted(full)


def _expand_dotted(flat: dict[str, Any]) -> dict[str, Any]:
    """Expand {"server.port": 8000, "schema": 1} into nested dicts."""
    out: dict[str, Any] = {}
    for key, value in flat.items():
        if "." not in key:
            out[key] = value
            continue
        parts = key.split(".")
        node = out
        for part in parts[:-1]:
            node = node.setdefault(part, {})
            if not isinstance(node, dict):
                raise ValueError(f"path {key!r} collides with non-dict at {part!r}")
        node[parts[-1]] = value
    return out


# --- detection helpers ------------------------------------------------------

def _is_fastapi(project: Path) -> bool:
    pyproject = project / "pyproject.toml"
    if pyproject.exists():
        try:
            data = tomllib.loads(pyproject.read_text())
        except Exception:
            data = {}
        deps = []
        deps += data.get("project", {}).get("dependencies", []) or []
        # poetry-style
        deps += list((data.get("tool", {}).get("poetry", {}).get("dependencies") or {}).keys())
        for d in deps:
            if isinstance(d, str) and d.lower().startswith("fastapi"):
                return True
    req = project / "requirements.txt"
    if req.exists() and re.search(r"(?im)^\s*fastapi\b", req.read_text()):
        return True
    return False


def _find_fastapi_entry_point(project: Path) -> str | None:
    candidates = [
        ("main.py",        "main:app"),
        ("app.py",         "app:app"),
        ("app/main.py",    "app.main:app"),
        ("src/main.py",    "src.main:app"),
        ("src/app.py",     "src.app:app"),
    ]
    for rel, dotted in candidates:
        f = project / rel
        if f.exists() and re.search(r"app\s*=\s*FastAPI\s*\(", f.read_text()):
            return dotted
    return None


def _detect_package_mgr(project: Path) -> str:
    if (project / "uv.lock").exists():
        return "uv"
    if (project / "poetry.lock").exists():
        return "poetry"
    if (project / "Pipfile.lock").exists():
        return "pipenv"
    if (project / "requirements.txt").exists():
        return "pip"
    return "none"


# --- TOML rendering --------------------------------------------------------

def _render_toml(spec: dict[str, Any]) -> str:
    """Tiny hand-rolled writer (Python stdlib has no tomllib writer)."""
    lines: list[str] = []
    if "schema" in spec:
        lines.append(f"schema = {spec['schema']}")
        lines.append("")

    def fmt(v: Any) -> str:
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return str(v)
        return f"\"{v}\""

    def emit_table(name: str, table: dict[str, Any]):
        lines.append(f"[{name}]")
        nested: list[tuple[str, dict[str, Any]]] = []
        for k, v in table.items():
            if isinstance(v, dict):
                nested.append((f"{name}.{k}", v))
            else:
                lines.append(f"{k} = {fmt(v)}")
        lines.append("")
        for sub_name, sub in nested:
            emit_table(sub_name, sub)

    for k, v in spec.items():
        if k == "schema":
            continue
        if isinstance(v, dict):
            emit_table(k, v)
    return "\n".join(lines).rstrip() + "\n"


# --- CLI -------------------------------------------------------------------

def _main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true",
                       help="write detected config to <project>/.humanbound/test/config.toml")
    group.add_argument("--json", dest="emit_json", action="store_true",
                       help="emit {framework, detected, unknown} JSON to stdout")
    group.add_argument("--write-from-json", action="store_true",
                       help="read flat-dotted JSON dict from stdin and write TOML")
    args = parser.parse_args(argv)

    if args.emit_json:
        payload = detect_json(args.project)
        print(json.dumps(payload, indent=2))
        return 0

    if args.write_from_json:
        return _write_from_json_cli(args.project)

    # --write or plain TOML print (legacy)
    spec = detect(args.project)
    if spec is None:
        print("no recognized framework", file=sys.stderr)
        return 2
    if args.write:
        write_toml(args.project / ".humanbound" / "test" / "config.toml", spec)
        print(f"wrote {args.project}/.humanbound/test/config.toml")
    else:
        print(_render_toml(spec))
    return 0


def _write_from_json_cli(project: Path) -> int:
    raw = sys.stdin.read()
    try:
        out = write_from_json_str(project, raw)
    except json.JSONDecodeError as e:
        print(f"invalid JSON on stdin: {e}", file=sys.stderr)
        return 4
    except ValueError as e:
        print(f"invalid payload: {e}", file=sys.stderr)
        return 5
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
