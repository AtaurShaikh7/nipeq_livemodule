"""
logger.py — Append-only, UTF-8, timestamped log to file + console.
Every line is flushed immediately so the log is live on the server.
"""

import sys
from datetime import datetime
from pathlib import Path


class Logger:
    def __init__(self, log_path: str):
        self.log_path = Path(log_path)
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        # Overwrite / create fresh on each run
        with open(self.log_path, "w", encoding="utf-8") as f:
            f.write(f"=== ETL Log Started at {datetime.now():%Y-%m-%d %H:%M:%S} ===\n")

    def _write(self, level: str, message: str):
        line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] [{level}] {message}"
        print(line, flush=True)
        try:
            with open(self.log_path, "a", encoding="utf-8") as f:
                f.write(line + "\n")
                f.flush()
        except Exception as e:
            print(f"[WARNING] Could not write to log file: {e}", flush=True)

    def info(self, message: str):
        self._write("INFO ", message)

    def warn(self, message: str):
        self._write("WARN ", message)

    def error(self, message: str):
        self._write("ERROR", message)

    def separator(self, label: str = ""):
        line = f"---------- {label} ----------" if label else "-" * 50
        self._write("INFO ", line)
