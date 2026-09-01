"""pytest conftest — make detect-server.py importable as `detect_server`."""

import importlib.util
import sys
from pathlib import Path

# Locate detect-server.py
SCRIPT_DIR = (
    Path(__file__).resolve().parents[1].parent / "skills" / "tunneling-local-agent" / "scripts"
)
sys.path.insert(0, str(SCRIPT_DIR))

# Hyphenated filename — alias as detect_server module.
_spec = importlib.util.spec_from_file_location("detect_server", SCRIPT_DIR / "detect-server.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
sys.modules["detect_server"] = _mod
