"""
holdings.py — Exports the Holdings report.

Steps:
  1. Call Oracle stored proc FINAL_HOLDINGS_REPORT(:effdate, :out_cursor) -> REF CURSOR
  2. Copy Holdings_Template.xls to output path
  3. Open copy in Excel via COM (preserves image, colors, formatting)
  4. Set cell B3 = effdate
  5. Write data rows from DataStartRow onward
  6. Validate per-scheme Script Weight in Fund sums to 99.99–100.02
  7. Save and close

Uses win32com so that images and header formatting in the template are fully preserved.
"""

import shutil
from datetime import date, datetime
from pathlib import Path

import oracledb
import win32com.client as win32

from logger import Logger


EXIT_CODE_HOLDINGS = 29

# Column indexes in the query result (0-based)
COL_SCHEME_NAME   = 2   # Column C
COL_SCRIPT_WEIGHT = 12  # Column M


def export_holdings_report(
    cfg: dict,
    conn: oracledb.Connection,
    effdate: date,
    script_dir: Path,
    log: Logger,
) -> int:
    """
    Returns 0 on success, EXIT_CODE_HOLDINGS on failure.
    """
    hr_cfg = cfg.get("HoldingsReport")
    if not hr_cfg:
        log.warn("HoldingsReport not configured in appsettings.json — skipping.")
        return 0

    # Resolve template path
    template_str = hr_cfg.get("TemplatePath", "")
    template_path = Path(template_str) if Path(template_str).is_absolute() else script_dir / template_str
    if not template_path.exists():
        log.error(f"Holdings template not found: {template_path}")
        return EXIT_CODE_HOLDINGS

    output_dir = Path(hr_cfg["OutputDirectory"])
    data_start_row = int(hr_cfg.get("DataStartRow", 6))  # 1-based for Excel COM

    if isinstance(effdate, datetime):
        effdate = effdate.date()

    date_label = effdate.strftime("%d-%b-%y")         # e.g. 20-Feb-26
    output_filename = f"Holdings_{date_label}.xls"
    output_path = output_dir / output_filename

    try:
        output_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        log.error(f"Cannot create output directory {output_dir}: {e}")
        return EXIT_CODE_HOLDINGS

    # ------------------------------------------------------------------
    # Step 1: Call Oracle procedure and fetch data
    # ------------------------------------------------------------------
    log.info("Calling FINAL_HOLDINGS_REPORT stored procedure...")
    try:
        cur = conn.cursor()
        out_cursor = conn.cursor()
        cur.callproc("FINAL_HOLDINGS_REPORT", [effdate, out_cursor])
        columns = [col[0] for col in out_cursor.description]
        rows = out_cursor.fetchall()
        out_cursor.close()
        cur.close()
    except oracledb.Error as e:
        log.error(f"Oracle error calling FINAL_HOLDINGS_REPORT: {e}")
        return EXIT_CODE_HOLDINGS
    except Exception as e:
        log.error(f"Unexpected error calling FINAL_HOLDINGS_REPORT: {e}")
        return EXIT_CODE_HOLDINGS

    log.info(f"  Query returned {len(rows)} rows, {len(columns)} columns.")
    if not rows:
        log.warn("  WARNING: FINAL_HOLDINGS_REPORT returned 0 rows — file will be empty.")

    # ------------------------------------------------------------------
    # Step 2: Copy template to output path (preserves image + formatting)
    # ------------------------------------------------------------------
    log.info(f"Copying template to: {output_path}")
    try:
        shutil.copy2(str(template_path), str(output_path))
    except Exception as e:
        log.error(f"Failed to copy template: {e}")
        return EXIT_CODE_HOLDINGS

    # ------------------------------------------------------------------
    # Step 3: Open copy in Excel via COM and write data
    # ------------------------------------------------------------------
    log.info("Opening output file in Excel...")
    excel = None
    wb = None
    try:
        excel = win32.gencache.EnsureDispatch("Excel.Application")
        excel.Visible = False
        excel.DisplayAlerts = False
        excel.AskToUpdateLinks = False
        excel.AutomationSecurity = 3  # msoAutomationSecurityForceDisable — disables all macros
        wb = excel.Workbooks.Open(
            str(output_path.resolve()),
            UpdateLinks=0,       # don't update external links
            ReadOnly=False,
            IgnoreReadOnlyRecommended=True,
            Notify=False,
            CorruptLoad=1,       # xlNormalLoad
        )
        ws = wb.Sheets(1)

        # Step 4: Set B3 = effdate (row=3, col=2 in 1-based)
        ws.Cells(3, 2).Value = effdate.strftime("%d-%b-%y")

        # Step 5: Write data rows
        scheme_weights: dict[str, float] = {}

        for r_idx, row_data in enumerate(rows):
            xl_row = data_start_row + r_idx  # 1-based
            for c_idx, val in enumerate(row_data, start=1):  # 1-based col
                if val is None:
                    ws.Cells(xl_row, c_idx).Value = ""
                elif isinstance(val, datetime):
                    ws.Cells(xl_row, c_idx).Value = val.strftime("%d-%b-%y")
                elif isinstance(val, date):
                    ws.Cells(xl_row, c_idx).Value = val.strftime("%d-%b-%y")
                elif isinstance(val, (int, float)):
                    ws.Cells(xl_row, c_idx).Value = float(val)
                else:
                    ws.Cells(xl_row, c_idx).Value = str(val)

            # Accumulate scheme weights for validation
            try:
                scheme = row_data[COL_SCHEME_NAME]
                weight = row_data[COL_SCRIPT_WEIGHT]
                if scheme is not None and weight is not None:
                    scheme_str = str(scheme).strip()
                    wt_val = float(weight)
                    if scheme_str and not (wt_val != wt_val):  # skip NaN
                        scheme_weights[scheme_str] = scheme_weights.get(scheme_str, 0.0) + wt_val
            except Exception:
                pass

        # Step 6: Validate per-scheme weights
        if scheme_weights:
            failed = {s: w for s, w in scheme_weights.items() if not (99.99 <= w <= 100.02)}
            if failed:
                log.warn("Holdings validation — schemes NOT summing to ~100% (99.99–100.02):")
                for scheme, total in sorted(failed.items()):
                    log.warn(f"  Scheme '{scheme}' total Script Weight = {total:.6f}")
                log.warn("File will still be saved.")
            else:
                log.info(f"Holdings weight validation: all {len(scheme_weights)} schemes sum to ~100%. OK.")

        # Step 7: Save
        wb.Save()
        log.info(f"Holdings report saved: {output_path}")
        return 0

    except Exception as e:
        log.error(f"Failed to write Holdings report: {e}")
        return EXIT_CODE_HOLDINGS
    finally:
        try:
            if wb:
                wb.Close(False)
            if excel:
                excel.Quit()
        except Exception:
            pass


if __name__ == "__main__":
    from config import load_config, SCRIPT_DIR
    from oracle_db import get_connection, fetch_effdate

    _cfg = load_config()
    _log = Logger("holdings.log")
    _conn = get_connection(_cfg)
    _effdate = fetch_effdate(_cfg, _log)
    if _effdate is None:
        print("Could not fetch effdate. Exiting.")
    else:
        result = export_holdings_report(_cfg, _conn, _effdate, SCRIPT_DIR, _log)
        print("Result:", "SUCCESS" if result == 0 else f"FAILED (exit code {result})")
    _conn.close()
