"""
dion_checker.py — Validates DION files before deciding to run the VBS downloader.

Two tiers of checks:
  1. File existence + size (KB) range + filename date matches effdate
  2. Excel row-count check: count rows where date column == effdate,
     must be within [MinCount, MaxCount]
"""

import re
from datetime import date, datetime
from pathlib import Path

import openpyxl
from logger import Logger


# ---------------------------------------------------------------------------
# Tier 1 — File size + filename date
# ---------------------------------------------------------------------------

def _parse_date_from_filename(filename: str, prefix: str) -> date | None:
    """
    Extracts the date embedded right after the prefix.
    Expected format: {prefix}{ddMMyyyy}{anything}.{ext}
    Example: DION_AVGVOL_19022026062301.xlsx -> 2026-02-19
    """
    name = Path(filename).stem  # no extension
    if not name.upper().startswith(prefix.upper()):
        return None
    after = name[len(prefix):]
    if len(after) < 8:
        return None
    date_part = after[:8]
    try:
        return datetime.strptime(date_part, "%d%m%Y").date()
    except ValueError:
        return None


def check_dion_files_ready(effdate: date, cfg: dict, log: Logger) -> bool:
    """
    Returns True only if ALL size/date checks AND Excel row-count checks pass.
    Logs the reason for every failure so you know exactly why the downloader runs.
    """
    all_ready = True

    # --- Tier 1: size + filename date ---
    for check in cfg.get("DionFileChecks", []):
        directory = Path(check["Directory"])
        prefix = check["FilePrefix"]
        min_kb = check["MinKb"]
        max_kb = check["MaxKb"]

        if not directory.exists():
            log.warn(f"  DION pre-check: directory not found: {directory}")
            all_ready = False
            continue

        files = sorted(directory.glob(f"{prefix}*"), key=lambda f: f.stat().st_mtime, reverse=True)
        if not files:
            log.warn(f"  DION pre-check: no file found for '{prefix}*' in {directory}")
            all_ready = False
            continue

        latest = files[0]
        size_kb = latest.stat().st_size / 1024.0

        if not (min_kb <= size_kb <= max_kb):
            log.warn(f"  DION pre-check: '{latest.name}' size {size_kb:.1f} KB outside [{min_kb}–{max_kb} KB]")
            all_ready = False
            continue

        file_date = _parse_date_from_filename(latest.name, prefix)
        if file_date is None:
            log.warn(f"  DION pre-check: '{latest.name}' — could not parse ddMMyyyy date from filename after prefix")
            all_ready = False
            continue

        if file_date != effdate:
            log.warn(f"  DION pre-check: '{latest.name}' filename date {file_date} != effdate {effdate}")
            all_ready = False
            continue

        log.info(f"  DION pre-check OK: '{latest.name}' size {size_kb:.1f} KB, date matches effdate.")

    if not all_ready:
        return False

    # --- Tier 2: Excel row-count check ---
    for v in cfg.get("DionExcelValidations", []):
        directory = Path(v["Directory"])
        prefix = v["FilePrefix"]
        date_col_str = v["DateColumn"]
        min_count = v["MinCount"]
        max_count = v["MaxCount"]

        if not directory.exists():
            log.warn(f"  DION Excel pre-check: directory not found: {directory}")
            return False

        files = sorted(directory.glob(f"{prefix}*"), key=lambda f: f.stat().st_mtime, reverse=True)
        if not files:
            log.warn(f"  DION Excel pre-check: no file for '{prefix}*'")
            return False

        col_idx = _parse_col_index(date_col_str)
        if col_idx is None:
            log.warn(f"  DION Excel pre-check: invalid DateColumn '{date_col_str}' for '{prefix}'")
            return False

        try:
            count = _count_rows_with_date(files[0], col_idx, effdate, log)
        except Exception as e:
            log.warn(f"  DION Excel pre-check: failed to read '{files[0].name}': {e}")
            return False

        if not (min_count <= count <= max_count):
            log.warn(f"  DION Excel pre-check: '{files[0].name}' has {count} rows for effdate (expected {min_count}–{max_count})")
            return False

        log.info(f"  DION Excel pre-check OK: '{files[0].name}' row count {count} (expected {min_count}–{max_count})")

    return True


# ---------------------------------------------------------------------------
# Tier 2 — Standalone validation (called after downloader runs)
# ---------------------------------------------------------------------------

def validate_dion_excel_data(effdate: date, cfg: dict, log: Logger) -> bool:
    """
    Validates DION Excel row counts for effdate after downloader has run.
    Returns True if all pass, False otherwise.
    """
    log.info("Validating Dion Excel data (row counts for effdate)...")
    for v in cfg.get("DionExcelValidations", []):
        directory = Path(v["Directory"])
        prefix = v["FilePrefix"]
        date_col_str = v["DateColumn"]
        min_count = v["MinCount"]
        max_count = v["MaxCount"]

        if not directory.exists():
            log.error(f"Dion Excel validation — directory not found: {directory}")
            return False

        files = sorted(directory.glob(f"{prefix}*"), key=lambda f: f.stat().st_mtime, reverse=True)
        if not files:
            log.error(f"Dion Excel validation — no file for '{prefix}*' in {directory}")
            return False

        col_idx = _parse_col_index(date_col_str)
        if col_idx is None:
            log.error(f"Dion Excel validation — invalid DateColumn '{date_col_str}' for '{prefix}'")
            return False

        try:
            count = _count_rows_with_date(files[0], col_idx, effdate, log)
        except Exception as e:
            log.error(f"Dion Excel validation — failed to read '{files[0].name}': {e}")
            return False

        log.info(f"  {prefix}: file={files[0].name}, rows with effdate={count} (expected {min_count}–{max_count})")

        if not (min_count <= count <= max_count):
            log.error(f"Dion Excel validation FAILED for '{prefix}': {count} outside [{min_count}, {max_count}]")
            return False

        log.info(f"  OK: {prefix}")

    log.info("All Dion Excel validations passed.")
    return True


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_col_index(col_str: str) -> int | None:
    """
    Converts column letter(s) or 1-based number to 0-based index.
    "A" -> 0, "B" -> 1, "AA" -> 26, "1" -> 0
    """
    if not col_str:
        return None
    s = col_str.strip().upper()
    if s.isdigit():
        val = int(s)
        return val - 1 if val >= 1 else None
    col = 0
    for c in s:
        if not c.isalpha():
            return None
        col = col * 26 + (ord(c) - ord('A') + 1)
    return col - 1


def _count_rows_with_date(file_path: Path, col_idx: int, target_date: date, log: Logger) -> int:
    """
    Opens an Excel file (.xlsx or .xls via openpyxl read-only)
    and counts rows where the given column equals target_date.
    """
    wb = openpyxl.load_workbook(str(file_path), read_only=True, data_only=True)
    ws = wb.active
    count = 0
    for row in ws.iter_rows():
        if col_idx >= len(row):
            continue
        cell = row[col_idx]
        val = cell.value
        if val is None:
            continue
        cell_date = _extract_date(val)
        if cell_date is not None and cell_date == target_date:
            count += 1
    wb.close()
    return count


def _extract_date(val) -> date | None:
    if isinstance(val, datetime):
        return val.date()
    if isinstance(val, date):
        return val
    if isinstance(val, str):
        for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%m/%d/%Y", "%d-%b-%Y", "%d-%B-%Y"):
            try:
                return datetime.strptime(val.strip(), fmt).date()
            except ValueError:
                continue
    if isinstance(val, (int, float)):
        try:
            # Excel OADate serial
            return datetime.fromordinal(datetime(1899, 12, 30).toordinal() + int(val)).date()
        except Exception:
            pass
    return None
