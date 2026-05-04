"""
config.py — Loads appsettings.json from the same directory as this script.
All paths in appsettings.json can be absolute or relative to the script dir.
"""

import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()


def load_config(config_path: Path = None) -> dict:
    if config_path is None:
        config_path = SCRIPT_DIR / "appsettings.json"

    if not config_path.exists():
        print(f"[FATAL] appsettings.json not found at: {config_path}")
        sys.exit(12)

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"[FATAL] Invalid JSON in appsettings.json: {e}")
        sys.exit(12)
    except Exception as e:
        print(f"[FATAL] Could not read appsettings.json: {e}")
        sys.exit(12)

    required_sections = ["Scripts", "LogFiles", "OutputFiles", "DionFileChecks", "Oracle"]
    for section in required_sections:
        if section not in config:
            print(f"[FATAL] Missing required section '{section}' in appsettings.json")
            sys.exit(12)

    return config


def resolve_path(path_str: str) -> Path:
    """Resolve a path: absolute stays as-is, relative is resolved from script dir."""
    p = Path(path_str)
    if p.is_absolute():
        return p
    return SCRIPT_DIR / p
