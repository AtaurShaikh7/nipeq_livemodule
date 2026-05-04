import os
import shutil
import re
import pyzipper  # For password-protected ZIPs
from zipfile import ZipFile
import win32com.client as win32

# ================= CONFIGURATION =================
source_folder = r"D:\Ataur\Ataur\Nippon\python\download"
password = b'Nimf#1126'   # ✅ UPDATED PASSWORD

file_to_folder_map = {
    'nifty_100': 'CNX 100',
    'nifty_500': 'CNX NIFTY 500',
    'nifty_50': 'CNX NIFTY',
    'nifty_bank': 'CNX BANK NIFTY',
    'nifty_dividend_opportunities_50': 'CNX DIVOPP',
    'nifty_india_consumption': 'CNX CONSUMPTION',
    'nifty_infrastructure': 'CNX INFRASTRUCTURE',
    'nifty_largemidcap_250': 'CNX LARGEMIDCAP 250',
    'nifty_midcap_150': 'CNX MIDCAP 150',
    'nifty_smallcap_250': 'CNX SMALLCAP 250',
    'nifty500_multicap_50_25_25': 'CNX NIFTY500_MULTICAP',
    'nifty_mnc': 'NIFTY MNC'
}

# ================= STEP 1: GET DATE =================
extracted_date = None
for filename in os.listdir(source_folder):
    match = re.search(r'(\d{8})', filename)
    if match:
        extracted_date = match.group(1)
        break

if not extracted_date:
    raise SystemExit("❌ No 8-digit date found in file names")

# ================= STEP 2: FOLDER STRUCTURE =================
base_output = os.path.dirname(source_folder)
final_folder = os.path.join(base_output, extracted_date)
os.makedirs(final_folder, exist_ok=True)

for folder in file_to_folder_map.values():
    os.makedirs(os.path.join(final_folder, folder), exist_ok=True)

# ================= STEP 3: INDEX ZIP FILES =================
for filename in os.listdir(source_folder):
    file_path = os.path.join(source_folder, filename)
    fname = filename.lower()

    if not fname.endswith('.zip'):
        continue
    if 'rlmf_rlmf_navcsv1' in fname or 'rlmf_rlmf_valuefy' in fname:
        continue

    for prefix, target_folder in file_to_folder_map.items():
        if fname.startswith(prefix):
            dest_folder = os.path.join(final_folder, target_folder)
            dest_zip = os.path.join(dest_folder, filename)

            shutil.move(file_path, dest_zip)
            print(f"Moved: {filename} → {target_folder}")

            try:
                with ZipFile(dest_zip, 'r') as z:
                    z.extractall(dest_folder)
                print(f"✅ Extracted: {filename}")
            except Exception as e:
                print(f"⚠️ Failed to extract {filename}: {e}")
            break

# ================= STEP 4: NAV ZIP =================
nav_zip = next(
    (f for f in os.listdir(source_folder)
     if re.match(r'rlmf_rlmf_navcsv1_\d{6}\.zip', f.lower())),
    None
)

if nav_zip:
    ddmmyy = re.search(r'(\d{6})', nav_zip).group(1)
    ddmmyyyy = ddmmyy[:4] + "20" + ddmmyy[4:]
    nav_zip_path = os.path.join(source_folder, nav_zip)

    with pyzipper.AESZipFile(nav_zip_path) as zf:
        zf.pwd = password
        extracted_files = zf.namelist()
        zf.extractall(source_folder)
        print(f"✅ Extracted NAV ZIP")

    for f in extracted_files:
        name = os.path.basename(f)
        if name:
            src = os.path.join(source_folder, name)
            dest = os.path.join(final_folder, f"NAV_{ddmmyyyy}.csv")
            if os.path.exists(src):
                os.rename(src, dest)
            break

# ================= STEP 5: VALUEFY ZIP =================
valuefy_zip = next(
    (f for f in os.listdir(source_folder)
     if re.match(r'rlmf_rlmf_valuefy_\d{6}\.zip', f.lower())),
    None
)

if valuefy_zip:
    ddmmyy = re.search(r'(\d{6})', valuefy_zip).group(1)
    zip_path = os.path.join(source_folder, valuefy_zip)

    with pyzipper.AESZipFile(zip_path) as zf:
        zf.pwd = password
        extracted_files = zf.namelist()
        zf.extractall(source_folder)
        print(f"✅ Extracted VALUEFY ZIP")

    parent = os.path.join(final_folder, f"VALUEFY{ddmmyy}")
    dest_folder = os.path.join(parent, "RLMF_RLMF_VALUEFY")
    os.makedirs(dest_folder, exist_ok=True)

    for f in extracted_files:
        name = os.path.basename(f)
        if name:
            src = os.path.join(source_folder, name)
            dest = os.path.join(dest_folder, name)
            if os.path.exists(src):
                shutil.move(src, dest)

# ================= STEP 6: NAV & HOLDING XLSX =================
nav_equity = next((f for f in os.listdir(source_folder)
                   if f.lower().startswith("nav_equity") and f.lower().endswith(".xlsx")), None)

holdinglist = next((f for f in os.listdir(source_folder)
                    if f.lower().startswith("holdinglist_equity") and f.lower().endswith(".xlsx")), None)

ddmmyy = extracted_date[6:8] + extracted_date[4:6] + extracted_date[2:4]

if nav_equity:
    shutil.move(
        os.path.join(source_folder, nav_equity),
        os.path.join(final_folder, f"NAV_Equity{ddmmyy}.xlsx")
    )

if holdinglist:
    shutil.move(
        os.path.join(source_folder, holdinglist),
        os.path.join(final_folder, f"Holdinglist_Equity{ddmmyy}.xlsx")
    )

# ================= STEP 7: FIN / FIE =================
for prefix in ['fin', 'fie']:
    zip_file = next(
        (f for f in os.listdir(source_folder)
         if f.lower().startswith(prefix) and f.lower().endswith('.zip')),
        None
    )
    if zip_file:
        with ZipFile(os.path.join(source_folder, zip_file), 'r') as z:
            z.extractall(final_folder)

print(f"\n🎯 Files ready at: {final_folder}")

# ================= STEP 8: VALUEFY EXCEL CLEAN =================
valuefy_dir = next((d for d in os.listdir(final_folder) if d.startswith("VALUEFY")), None)

if valuefy_dir:
    excel_path = os.path.join(
        final_folder, valuefy_dir,
        "RLMF_RLMF_VALUEFY", "IN_MF_TRADE_DUMP_REPORT.xls"
    )

    if os.path.exists(excel_path):
        excel = win32.gencache.EnsureDispatch('Excel.Application')
        wb = excel.Workbooks.Open(excel_path)
        ws = wb.Sheets(1)

        headers = ws.UsedRange.Rows(1)
        qty_col = asset_col = None

        for i in range(1, headers.Columns.Count + 1):
            h = str(headers.Cells(1, i).Value).lower()
            if h == "quantity":
                qty_col = i
            elif h == "asset type":
                asset_col = i

        for r in range(ws.UsedRange.Rows.Count, 1, -1):
            qty = ws.Cells(r, qty_col).Value
            asset = str(ws.Cells(r, asset_col).Value).upper()
            if qty == 0 and asset != "PTC":
                ws.Rows(r).Delete()
            elif qty == 0:
                ws.Cells(r, qty_col).Value = 0.01

        wb.Save()
        wb.Close()
        excel.Quit()
        print("✅ VALUEFY Excel updated")
