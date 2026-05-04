"""
main.py — ETL Pipeline Entry Point (Python conversion of MacroTest .NET)

Usage:
    python main.py                  Full pipeline
    python main.py --write-effdate  Fetch effdate, write to effdate.txt, exit
    python main.py --test-holdings  Run Holdings report only, exit

Exit codes:
    0   Success
    1   PowerShell / VBS macro failed
    2   PowerShell / VBS exception
    10  DION Downloader non-zero exit
    11  DION Downloader exception
    12  Config load failure
    20  Oracle error (OracleException)
    21  Oracle general error
    22  Could not retrieve effdate
    23  NonZeroCount validation failed
    24  MustBeNull validation failed
    25  oracle_steps.json not found
    26  oracle_steps.json parse error
    27  oracle_steps.json has no steps
    28  Dion Excel row-count validation failed
    29  Holdings export failed
    30  File movement step failed
    99  Unhandled exception
"""

import subprocess
import sys
from datetime import datetime
from pathlib import Path

import oracledb

# ---------------------------------------------------------------------------
# Local imports
# ---------------------------------------------------------------------------
from config import load_config, resolve_path, SCRIPT_DIR
from logger import Logger
from oracle_db import get_connection, fetch_effdate
from dion_checker import check_dion_files_ready, validate_dion_excel_data
from oracle_steps import run_oracle_steps
from holdings import export_holdings_report
from file_movement import run as run_file_movement
from outlook_downloader import run as run_outlook_downloader

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_subprocess(cmd: list[str], log: Logger, label: str) -> int:
    """Runs a subprocess, logs stdout/stderr live, returns exit code."""
    log.info(f"Running {label}: {' '.join(cmd)}")
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        stdout, stderr = proc.communicate()
        if stdout.strip():
            for line in stdout.strip().splitlines():
                log.info(f"  [{label}] {line}")
        if stderr.strip():
            for line in stderr.strip().splitlines():
                log.warn(f"  [{label} STDERR] {line}")
        return proc.returncode
    except FileNotFoundError as e:
        log.error(f"  Could not start {label}: {e}")
        return -1
    except Exception as e:
        log.error(f"  Exception running {label}: {e}")
        return -1


def read_last_line(file_path: Path, log: Logger) -> str | None:
    try:
        if not file_path.exists():
            log.warn(f"File not found: {file_path}")
            return None
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        return lines[-1].strip() if lines else None
    except Exception as e:
        log.warn(f"Could not read {file_path}: {e}")
        return None


def find_latest_macro_log(directory: Path, log: Logger) -> Path | None:
    try:
        if not directory.exists():
            return None
        files = sorted(directory.glob("log_*"), key=lambda f: f.stat().st_mtime, reverse=True)
        return files[0] if files else None
    except Exception as e:
        log.warn(f"Error scanning macro log directory: {e}")
        return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    module_start = datetime.now()

    # ------------------------------------------------------------------
    # Load config
    # ------------------------------------------------------------------
    cfg = load_config()

    log_file_setting = cfg["LogFiles"].get("AppLog", "MacroTest.log")
    log_path = resolve_path(log_file_setting)
    log = Logger(str(log_path))

    log.separator("ETL Pipeline Starting")
    log.info(f"Module started at: {module_start:%Y-%m-%d %H:%M:%S}")
    log.info(f"Log file: {log_path}")
    log.info(f"Python: {sys.version}")

    args = sys.argv[1:]

    # ------------------------------------------------------------------
    # Mode: --write-effdate
    # ------------------------------------------------------------------
    if args and args[0].lower() == "--write-effdate":
        eff = fetch_effdate(cfg, log)
        if eff is None:
            log.error("Could not get effdate from Oracle.")
            return 22
        effdate_file = SCRIPT_DIR / "effdate.txt"
        effdate_file.write_text(eff.strftime("%Y%m%d"), encoding="utf-8")
        log.info(f"Effdate written: {eff} -> {effdate_file}")
        return 0

    # ------------------------------------------------------------------
    # Mode: --test-holdings
    # ------------------------------------------------------------------
    if args and args[0].lower() == "--test-holdings":
        eff = fetch_effdate(cfg, log)
        if eff is None:
            log.error("Could not get effdate.")
            return 22
        log.info(f"Test mode: Holdings report only. Effdate: {eff}")
        conn = get_connection(cfg)
        result = export_holdings_report(cfg, conn, eff, SCRIPT_DIR, log)
        conn.close()
        return result

    # ------------------------------------------------------------------
    # Full pipeline
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # STEP 0 (pre-download) — Outlook Attachment Downloader
    # Comment out the next 3 lines to skip downloading from Outlook
    # ------------------------------------------------------------------
    # log.separator("STEP 0: Outlook Downloader")
    # if not run_outlook_downloader(cfg, log):
    #     log.error("Outlook download step failed. ETL stopping.")
    #     return 31

    # ------------------------------------------------------------------
    # STEP 0 (pre) — File Movement
    # ------------------------------------------------------------------
    log.separator("STEP 0: File Movement")
    if not run_file_movement(log):
        log.error("File movement step failed. ETL stopping.")
        return 30

    # PRE-STEP: Fetch effdate early (used to decide DION skip)
    log.separator("PRE-STEP: Fetch Effdate")
    early_effdate = fetch_effdate(cfg, log)
    if early_effdate is None:
        log.warn("Could not pre-fetch effdate — DION Downloader will run unconditionally.")

    # ------------------------------------------------------------------
    # STEP 0 — DION Downloader (VBS)
    # ------------------------------------------------------------------
    log.separator("STEP 0: DION Downloader")
    dion_vbs = cfg["Scripts"]["DionDownloaderVbs"]

    if early_effdate and check_dion_files_ready(early_effdate, cfg, log):
        log.info(f"All DION files already ready for {early_effdate}. Skipping DION Downloader.")
    else:
        if early_effdate:
            log.info("DION files not ready — running DION Downloader...")
        else:
            log.info("Running DION Downloader (effdate unknown)...")

        exit_code = run_subprocess(["wscript.exe", dion_vbs], log, "DionDownloader")
        if exit_code != 0:
            log.error(f"DION Downloader failed with exit code {exit_code}.")
            return 10 if exit_code > 0 else 11

        log.info("DION Downloader completed successfully.")

        # Validate DION Excel data after download
        if early_effdate:
            if not validate_dion_excel_data(early_effdate, cfg, log):
                log.error("DION Excel validation failed after downloader run.")
                return 28

    # ------------------------------------------------------------------
    # STEP 1 — BSE PowerShell Downloader
    # ------------------------------------------------------------------
    log.separator("STEP 1: BSE PowerShell Downloader")
    ps1_path = cfg["Scripts"]["PowerShellScript"]
    exit_code = run_subprocess(
        ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", ps1_path],
        log, "BSE PowerShell"
    )
    if exit_code != 0:
        log.error(f"PowerShell script failed with exit code {exit_code}.")
        return 1

    log.info("PowerShell script completed successfully.")

    # STEP 2 — Read copy_log.txt
    log.separator("STEP 2: Read copy_log.txt")
    copy_log_path = resolve_path(cfg["LogFiles"]["CopyLog"])
    last_line = read_last_line(copy_log_path, log)
    if last_line:
        log.info(f"Latest copy_log entry: {last_line}")
    else:
        log.warn("copy_log.txt is empty or missing.")

    # ------------------------------------------------------------------
    # STEP 3 — VBS Macro (generates ETLDATA.xls)
    # ------------------------------------------------------------------
    log.separator("STEP 3: VBS Macro")
    vbs_path = cfg["Scripts"]["TestVbs"]
    exit_code = run_subprocess(["wscript.exe", vbs_path], log, "VBS Macro")
    if exit_code != 0:
        log.error(f"VBS Macro failed with exit code {exit_code}.")
        return 1

    log.info("VBS Macro executed successfully.")

    # Check output XLS file
    etl_xls = resolve_path(cfg["OutputFiles"]["EtlDataXls"])
    if etl_xls.exists():
        stat = etl_xls.stat()
        size_mb = stat.st_size / (1024 * 1024)
        modified = datetime.fromtimestamp(stat.st_mtime)
        minutes_old = (module_start - modified).total_seconds() / 60
        log.info(f"Output file: {etl_xls.name}")
        log.info(f"  Size: {size_mb:.2f} MB")
        log.info(f"  Last modified: {modified:%Y-%m-%d %H:%M:%S}")
        log.info(f"  Minutes since modification: {minutes_old:.1f}")
        if minutes_old > 7:
            log.warn(f"  ALERT: File is {minutes_old:.1f} minutes old (expected within 7 min of module start).")
        else:
            log.info("  File modification time is recent (within 7 min). OK.")
    else:
        log.warn(f"  Output file not found: {etl_xls}")

    # Check macro runtime log
    macro_log_dir_str = cfg["OutputFiles"].get("MacroLogDirectory", "")
    if macro_log_dir_str:
        macro_log_dir = resolve_path(macro_log_dir_str)
        latest_log = find_latest_macro_log(macro_log_dir, log)
        if latest_log:
            log.info(f"Latest macro log: {latest_log.name}  (modified {datetime.fromtimestamp(latest_log.stat().st_mtime):%Y-%m-%d %H:%M:%S})")
        else:
            log.warn(f"No macro log files (log_*) found in {macro_log_dir}")

    # ------------------------------------------------------------------
    # STEP 4 — Oracle ETL (stored procs + validations)
    # ------------------------------------------------------------------
    log.separator("STEP 4: Oracle ETL")

    if not cfg.get("Oracle"):
        log.warn("Oracle config not found — skipping Oracle ETL step.")
    else:
        log.info("Connecting to Oracle...")
        try:
            conn = get_connection(cfg)
            log.info(f"  Oracle connected. Server version: {conn.version}")
        except oracledb.Error as e:
            log.error(f"Oracle connection failed: {e}")
            return 20
        except Exception as e:
            log.error(f"Unexpected error connecting to Oracle: {e}")
            return 21

        # Check daily_process_stats status before running SPs
        log.separator("PRE-STEP 4: Check daily_process_stats status")
        try:
            cur = conn.cursor()
            cur.execute("SELECT status FROM daily_process_stats WHERE process_name = 'ETL STAGE 1'")
            row = cur.fetchone()
            cur.close()
            status = row[0] if row else None
            if status is not None:
                log.error(f"daily_process_stats status is '{status}' (expected NULL). ETL Stage 1 may not be reset. Stopping.")
                # Show SRC DATA COLLATION status for diagnosis
                try:
                    cur2 = conn.cursor()
                    cur2.execute("SELECT status FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'")
                    row2 = cur2.fetchone()
                    cur2.close()
                    src_status = row2[0] if row2 else None
                    log.error(f"  SRC DATA COLLATION status: {src_status}")
                except Exception:
                    pass
                conn.close()
                return 24
            log.info("  daily_process_stats status is NULL — OK to proceed with stored procedures.")
        except oracledb.Error as e:
            log.error(f"  Failed to check daily_process_stats: {e}")
            conn.close()
            return 20

        # Use pre-fetched effdate or re-fetch
        effdate = early_effdate
        if effdate is None:
            log.info("Re-fetching effdate from Oracle...")
            effdate = fetch_effdate(cfg, log)
            if effdate is None:
                log.error("Could not retrieve effdate. ETL stopping.")
                conn.close()
                return 22

        log.info(f"Using effdate: {effdate}")

        # 4a. Update daily_process_stats (pre-ETL reset)
        log.separator("4a: Reset daily_process_stats")
        RESET_SQL = """
            UPDATE daily_process_stats
            SET currdatadate = (SELECT currdatadate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
                lastdatadate = (SELECT lastdatadate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
                rundate      = (SELECT rundate      FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
                dataready    = 0,
                status       = NULL
            WHERE process_name IN ('ETL STAGE 1', 'ETL STAGE 2')
        """
        try:
            cur = conn.cursor()
            cur.execute(RESET_SQL)
            rows = cur.rowcount
            cur.close()
            log.info(f"  Updated {rows} row(s) in daily_process_stats (reset for ETL STAGE 1 & 2).")
        except oracledb.Error as e:
            log.error(f"  Failed to reset daily_process_stats: {e}")
            conn.close()
            return 20

        # 4b. Run steps from oracle_steps.json
        steps_file_setting = cfg["Oracle"].get("StepsFile", "oracle_steps.json")
        steps_file = resolve_path(steps_file_setting)
        log.info(f"Oracle steps file: {steps_file}")

        success, exit_code = run_oracle_steps(conn, steps_file, effdate, log)
        if not success:
            log.error(f"Oracle ETL failed at a step. Exit code: {exit_code}")
            conn.close()
            return exit_code

        # 4c. Holdings report
        log.separator("STEP 5: Holdings Report Export")
        hr_result = export_holdings_report(cfg, conn, effdate, SCRIPT_DIR, log)
        if hr_result != 0:
            log.error(f"Holdings export failed. Exit code: {hr_result}")
            conn.close()
            return hr_result

        conn.close()

    # ------------------------------------------------------------------
    # Done
    # ------------------------------------------------------------------
    elapsed = (datetime.now() - module_start).total_seconds()
    log.separator()
    log.info(f"ETL Pipeline completed successfully. Total elapsed: {elapsed:.1f}s")
    log.info(f"Finished at: {datetime.now():%Y-%m-%d %H:%M:%S}")
    return 0


if __name__ == "__main__":
    try:
        code = main()
    except Exception as e:
        print(f"[FATAL] Unhandled exception: {e}", flush=True)
        import traceback
        traceback.print_exc()
        code = 99
    sys.exit(code)
