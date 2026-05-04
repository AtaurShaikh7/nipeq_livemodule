"""
file_movement.py — Daily file movement and extraction step.
Runs BEFORE the main ETL pipeline.

Steps:
  1. Extract date from filenames in source folder
  2. Create NSEDATA/{date}/ folder + 12 index sub-folders
  3. Move & extract index ZIPs into their sub-folders
  4. Extract NAV ZIP (password-protected AES) -> CustodianData
  5. Extract VALUEFY ZIP (password-protected AES) -> CustodianData
  6. (skipped)
  7. Extract FIN/FIE ZIPs -> OtherData (force-replace existing files)
  8. Clean VALUEFY Excel: delete zero-qty rows, patch PTC rows
"""

import os
import re
import shutil
from pathlib import Path
from zipfile import ZipFile

import pyzipper
import win32com.client as win32

from logger import Logger

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SOURCE_FOLDER   = Path(r"C:\Users\sa_pim_windows\Downloads")
NSEDATA_DIR     = Path(r"D:\Valuefy\DataLoadProcess\DailyData\IndexData\NSEDATA")
CUSTODIAN_DIR   = Path(r"D:\Valuefy\DataLoadProcess\DailyData\CustodianData")
OTHER_DIR       = Path(r"D:\Valuefy\DataLoadProcess\DailyData\OtherData")

ZIP_PASSWORD = b"Nimf#1126"

INDEX_MAP = {
    "nifty_100":                      "CNX 100",
    "nifty_500":                      "CNX NIFTY 500",
    "nifty_50":                       "CNX NIFTY",
    "nifty_bank":                     "CNX BANK NIFTY",
    "nifty_dividend_opportunities_50":"CNX DIVOPP",
    "nifty_india_consumption":        "CNX CONSUMPTION",
    "nifty_infrastructure":           "CNX INFRASTRUCTURE",
    "nifty_largemidcap_250":          "CNX LARGEMIDCAP 250",
    "nifty_midcap_150":               "CNX MIDCAP 150",
    "nifty_smallcap_250":             "CNX SMALLCAP 250",
    "nifty500_multicap_50_25_25":     "CNX NIFTY500_MULTICAP",
    "nifty_mnc":                      "NIFTY MNC",
}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def run(log: Logger) -> bool:
    """
    Runs all file movement steps.
    Returns True on success, False on any fatal failure.
    """
    log.separator("FILE MOVEMENT: Starting")

    # ------------------------------------------------------------------
    # STEP 1 — Extract date from filenames
    # ------------------------------------------------------------------
    log.separator("Step 1: Extract date from source folder filenames")

    if not SOURCE_FOLDER.exists():
        log.error(f"Source folder not found: {SOURCE_FOLDER}")
        return False

    extracted_date = None
    for fname in os.listdir(SOURCE_FOLDER):
        match = re.search(r"(\d{8})", fname)
        if match:
            extracted_date = match.group(1)
            log.info(f"  Date extracted from '{fname}': {extracted_date}")
            break

    if not extracted_date:
        log.error("No 8-digit date found in any filename in source folder. Cannot continue.")
        return False

    # ddmmyy derived from yyyymmdd (for naming)
    ddmmyy = extracted_date[6:8] + extracted_date[4:6] + extracted_date[2:4]

    # ------------------------------------------------------------------
    # STEP 2 — Create NSEDATA/{date}/ + 12 index sub-folders
    # ------------------------------------------------------------------
    log.separator("Step 2: Create NSEDATA output folder structure")

    final_folder = NSEDATA_DIR / extracted_date
    final_folder.mkdir(parents=True, exist_ok=True)
    log.info(f"  Output folder: {final_folder}")

    for sub in INDEX_MAP.values():
        sub_path = final_folder / sub
        sub_path.mkdir(parents=True, exist_ok=True)

    log.info(f"  Created {len(INDEX_MAP)} index sub-folders.")

    # ------------------------------------------------------------------
    # STEP 3 — Move & extract index ZIPs
    # ------------------------------------------------------------------
    log.separator("Step 3: Move and extract index ZIP files")

    for fname in os.listdir(SOURCE_FOLDER):
        fpath = SOURCE_FOLDER / fname
        flower = fname.lower()

        if not flower.endswith(".zip"):
            continue
        if "rlmf_rlmf_navcsv1" in flower or "rlmf_rlmf_valuefy" in flower:
            continue  # handled in steps 4 & 5

        for prefix, target_sub in INDEX_MAP.items():
            if flower.startswith(prefix):
                dest_folder = final_folder / target_sub
                dest_zip = dest_folder / fname

                shutil.move(str(fpath), str(dest_zip))
                log.info(f"  Moved: {fname} -> {target_sub}/")

                try:
                    with ZipFile(dest_zip, "r") as z:
                        z.extractall(dest_folder)
                    log.info(f"  Extracted: {fname}")
                except Exception as e:
                    log.warn(f"  Failed to extract {fname}: {e}")
                break

    # ------------------------------------------------------------------
    # STEP 4 — NAV ZIP (AES password-protected) -> CustodianData
    # ------------------------------------------------------------------
    log.separator("Step 4: NAV ZIP -> CustodianData")

    nav_zip_name = next(
        (f for f in os.listdir(SOURCE_FOLDER)
         if re.match(r"rlmf_rlmf_navcsv1_\d{6}\.zip", f.lower())),
        None,
    )

    if nav_zip_name:
        nav_zip_path = SOURCE_FOLDER / nav_zip_name
        ddmmyy_nav = re.search(r"(\d{6})", nav_zip_name).group(1)
        ddmmyyyy_nav = ddmmyy_nav[:4] + "20" + ddmmyy_nav[4:]

        CUSTODIAN_DIR.mkdir(parents=True, exist_ok=True)

        try:
            with pyzipper.AESZipFile(nav_zip_path) as zf:
                zf.pwd = ZIP_PASSWORD
                extracted_files = zf.namelist()
                zf.extractall(CUSTODIAN_DIR)
            log.info(f"  Extracted NAV ZIP to {CUSTODIAN_DIR}")

            # Rename first extracted file to NAV_{ddmmyyyy}.csv
            for f in extracted_files:
                name = os.path.basename(f)
                if name:
                    src = CUSTODIAN_DIR / name
                    dest = CUSTODIAN_DIR / f"NAV_{ddmmyyyy_nav}.csv"
                    if src.exists():
                        src.rename(dest)
                        log.info(f"  Renamed: {name} -> NAV_{ddmmyyyy_nav}.csv")
                    break
        except Exception as e:
            log.error(f"  Failed to extract NAV ZIP: {e}")
            return False
    else:
        log.warn("  NAV ZIP (rlmf_rlmf_navcsv1_*.zip) not found in source folder — skipping.")

    # ------------------------------------------------------------------
    # STEP 5 — VALUEFY ZIP (AES password-protected) -> CustodianData
    # ------------------------------------------------------------------
    log.separator("Step 5: VALUEFY ZIP -> CustodianData")

    valuefy_zip_name = next(
        (f for f in os.listdir(SOURCE_FOLDER)
         if re.match(r"rlmf_rlmf_valuefy_\d{6}\.zip", f.lower())),
        None,
    )

    if valuefy_zip_name:
        valuefy_zip_path = SOURCE_FOLDER / valuefy_zip_name
        ddmmyy_vfy = re.search(r"(\d{6})", valuefy_zip_name).group(1)

        dest_folder = CUSTODIAN_DIR / f"VALUEFY{ddmmyy_vfy}" / "RLMF_RLMF_VALUEFY"
        dest_folder.mkdir(parents=True, exist_ok=True)

        try:
            with pyzipper.AESZipFile(valuefy_zip_path) as zf:
                zf.pwd = ZIP_PASSWORD
                extracted_files = zf.namelist()
                # Extract to a temp location (CustodianData root) then move
                zf.extractall(CUSTODIAN_DIR)
            log.info(f"  Extracted VALUEFY ZIP")

            for f in extracted_files:
                name = os.path.basename(f)
                if name:
                    src = CUSTODIAN_DIR / name
                    dest = dest_folder / name
                    if src.exists():
                        shutil.move(str(src), str(dest))

            log.info(f"  Files moved to: {dest_folder}")
        except Exception as e:
            log.error(f"  Failed to extract VALUEFY ZIP: {e}")
            return False
    else:
        log.warn("  VALUEFY ZIP (rlmf_rlmf_valuefy_*.zip) not found in source folder — skipping.")

    # Step 6 — SKIPPED (NAV & HoldingList XLSX)

    # ------------------------------------------------------------------
    # STEP 7 — FIN / FIE ZIPs -> OtherData (force-replace)
    # ------------------------------------------------------------------
    log.separator("Step 7: FIN/FIE ZIPs -> OtherData (force replace)")

    OTHER_DIR.mkdir(parents=True, exist_ok=True)

    for prefix in ["fin", "fie"]:
        zip_name = next(
            (f for f in os.listdir(SOURCE_FOLDER)
             if f.lower().startswith(prefix) and f.lower().endswith(".zip")),
            None,
        )
        if zip_name:
            zip_path = SOURCE_FOLDER / zip_name
            try:
                with ZipFile(zip_path, "r") as z:
                    for member in z.infolist():
                        dest_file = OTHER_DIR / member.filename
                        # Force replace: remove existing file first
                        if dest_file.exists():
                            dest_file.unlink()
                            log.info(f"  Replaced existing: {member.filename}")
                        z.extract(member, OTHER_DIR)
                log.info(f"  Extracted {zip_name} -> {OTHER_DIR}")
            except Exception as e:
                log.error(f"  Failed to extract {zip_name}: {e}")
                return False
        else:
            log.warn(f"  No ZIP starting with '{prefix}' found — skipping.")

    # ------------------------------------------------------------------
    # STEP 8 — Clean VALUEFY Excel (IN_MF_TRADE_DUMP_REPORT.xls)
    # ------------------------------------------------------------------
    log.separator("Step 8: VALUEFY Excel cleanup")

    excel_path = CUSTODIAN_DIR / f"VALUEFY{ddmmyy}" / "RLMF_RLMF_VALUEFY" / "IN_MF_TRADE_DUMP_REPORT.xls"

    if not excel_path.exists():
        log.warn(f"  VALUEFY Excel not found: {excel_path} — skipping cleanup.")
    else:
        log.info(f"  Opening: {excel_path}")
        excel = None
        wb = None
        try:
            excel = win32.gencache.EnsureDispatch("Excel.Application")
            excel.Visible = False
            excel.DisplayAlerts = False
            wb = excel.Workbooks.Open(str(excel_path))
            ws = wb.Sheets(1)

            # Find Quantity and Asset Type columns by header
            headers = ws.UsedRange.Rows(1)
            qty_col = asset_col = None
            for i in range(1, headers.Columns.Count + 1):
                h = str(headers.Cells(1, i).Value or "").strip().lower()
                if h == "quantity":
                    qty_col = i
                elif h == "asset type":
                    asset_col = i

            if qty_col is None or asset_col is None:
                log.warn(f"  Could not find 'Quantity' or 'Asset Type' columns — skipping row cleanup.")
                log.warn(f"  qty_col={qty_col}, asset_col={asset_col}")
            else:
                deleted = 0
                patched = 0
                for r in range(ws.UsedRange.Rows.Count, 1, -1):  # bottom-up
                    qty = ws.Cells(r, qty_col).Value
                    asset = str(ws.Cells(r, asset_col).Value or "").strip().upper()
                    if qty == 0 and asset != "PTC":
                        ws.Rows(r).Delete()
                        deleted += 1
                    elif qty == 0 and asset == "PTC":
                        ws.Cells(r, qty_col).Value = 0.01
                        patched += 1

                log.info(f"  Rows deleted (qty=0, non-PTC): {deleted}")
                log.info(f"  Rows patched (qty=0, PTC -> 0.01): {patched}")

            wb.Save()
            log.info("  VALUEFY Excel saved.")
        except Exception as e:
            log.error(f"  VALUEFY Excel cleanup failed: {e}")
            return False
        finally:
            try:
                if wb:
                    wb.Close(False)
                if excel:
                    excel.Quit()
            except Exception:
                pass

    log.separator("FILE MOVEMENT: Completed successfully")
    log.info(f"  NSEDATA output: {final_folder}")
    log.info(f"  Custodian data: {CUSTODIAN_DIR}")
    log.info(f"  Other data:     {OTHER_DIR}")
    return True


if __name__ == "__main__":
    _log = Logger("file_movement.log")
    success = run(_log)
    print("Result:", "SUCCESS" if success else "FAILED")
