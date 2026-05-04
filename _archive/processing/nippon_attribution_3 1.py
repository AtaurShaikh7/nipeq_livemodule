import os
import shutil
import re
import pyzipper
from zipfile import ZipFile
from datetime import datetime, timedelta
import win32com.client as win32

# ================= CONFIGURATION =================
source_folder = r"C:\Users\Mansi Bhonde\Downloads\nipp"
password = b'Nimf#1126'

# Senders whose attachments should be downloaded
ALLOWED_SENDERS = [
    "secureinbox.autobahn@db.com",
    "feed@bilav.com",
    "indices@nse.co.in",
    "operation3@nam.co.jp",
    "arvind.kale@db.com",
    "archana.raghuraman@db.com"
]

# Outlook folder names to scan (Inbox + Attrib subfolder)
OUTLOOK_FOLDERS = ["Inbox", "Attrib"]

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

# ================= STEP 0: CALCULATE TARGET DATE =================
# Logic:
#   Saturday → process Friday's data
#   Tuesday to Friday → process previous day's data
#   Monday → no work (but script exits gracefully)
#   Sunday → no work

today = datetime.today()
weekday = today.weekday()  # 0=Mon, 1=Tue, ..., 5=Sat, 6=Sun

if weekday == 6:  # Sunday
    raise SystemExit("ℹ️ No processing on Sundays. Exiting.")
elif weekday == 0:  # Monday
    raise SystemExit("ℹ️ No processing on Mondays. Exiting.")
elif weekday == 5:  # Saturday → process Friday
    target_date = today - timedelta(days=1)
else:  # Tue–Fri → process previous day
    target_date = today - timedelta(days=1)

target_yyyymmdd = target_date.strftime('%Y%m%d')   # e.g. 20260309
target_ddmmyy   = target_date.strftime('%d%m%y')    # e.g. 090326
target_ddmmyyyy = target_date.strftime('%d%m%Y')    # e.g. 09032026

print(f"📅 Processing date: {target_date.strftime('%d %b %Y')} ({target_yyyymmdd})")

# ================= STEP 0.5: CLEAN NIPP FOLDER =================
print("\n🧹 Cleaning nipp folder before fresh download...")

if os.path.exists(source_folder):
    deleted_files = 0
    deleted_dirs = 0
    for item in os.listdir(source_folder):
        item_path = os.path.join(source_folder, item)
        try:
            if os.path.isfile(item_path):
                os.remove(item_path)
                deleted_files += 1
            elif os.path.isdir(item_path):
                shutil.rmtree(item_path)
                deleted_dirs += 1
        except Exception as e:
            print(f"  ⚠️ Could not delete {item}: {e}")
    print(f"  ✅ Cleared: {deleted_files} files, {deleted_dirs} folders removed from nipp")
else:
    os.makedirs(source_folder, exist_ok=True)
    print(f"  ✅ nipp folder created fresh")

# ================= STEP 1: AUTO-DOWNLOAD FROM OUTLOOK =================
print("\n📬 Connecting to Outlook...")
outlook = win32.Dispatch("Outlook.Application").GetNamespace("MAPI")

downloaded_count = 0

def download_attachments_from_folder(outlook_folder):
    """Download attachments from emails sent by allowed senders on target date."""
    global downloaded_count
    try:
        messages = outlook_folder.Items
        messages.Sort("[ReceivedTime]", True)  # Latest first
        for msg in messages:
            try:
                # Check sender
                sender = ""
                try:
                    sender = msg.SenderEmailAddress.lower()
                except:
                    try:
                        sender = msg.Sender.GetExchangeUser().PrimarySmtpAddress.lower()
                    except:
                        pass

                if not any(s.lower() in sender for s in ALLOWED_SENDERS):
                    continue

                # Check received date matches target date
                received = msg.ReceivedTime
                received_date = received.strftime('%Y%m%d') if hasattr(received, 'strftime') else str(received)[:10].replace('-','')
                if received_date != target_yyyymmdd:
                    continue

                # Download all attachments
                for attachment in msg.Attachments:
                    att_name = attachment.FileName
                    dest_path = os.path.join(source_folder, att_name)
                    if not os.path.exists(dest_path):
                        attachment.SaveAsFile(dest_path)
                        print(f"  ✅ Downloaded: {att_name} (from {sender})")
                        downloaded_count += 1
                    else:
                        print(f"  ⏭️ Already exists: {att_name}")

            except Exception as e:
                continue
    except Exception as e:
        print(f"  ⚠️ Error scanning folder: {e}")


# Scan default Inbox
inbox = outlook.GetDefaultFolder(6)  # 6 = olFolderInbox
print(f"  🔍 Scanning: Inbox")
download_attachments_from_folder(inbox)

# Scan Attrib subfolder — search all mail folders, not just Inbox children
def find_folder_by_name(parent, name):
    """Recursively search for a folder by name."""
    try:
        for folder in parent.Folders:
            if folder.Name.lower() == name.lower():
                return folder
            found = find_folder_by_name(folder, name)
            if found:
                return found
    except:
        pass
    return None

# Try finding Attrib under Inbox first, then root
attrib_folder = None
try:
    attrib_folder = inbox.Folders["Attrib"]
except:
    pass

if attrib_folder is None:
    try:
        root = outlook.Folders
        for store in root:
            attrib_folder = find_folder_by_name(store, "Attrib")
            if attrib_folder:
                break
    except:
        pass

if attrib_folder:
    print(f"  🔍 Scanning: Attrib subfolder")
    download_attachments_from_folder(attrib_folder)
else:
    print(f"  ⚠️ 'Attrib' folder not found anywhere in Outlook — skipping")

print(f"\n📥 Total attachments downloaded: {downloaded_count}")

if downloaded_count == 0:
    # Check if files already exist from a previous run
    existing = [f for f in os.listdir(source_folder) if target_yyyymmdd in f or target_ddmmyy in f]
    if not existing:
        raise SystemExit(f"❌ No attachments found for {target_yyyymmdd}. Check Outlook folders and sender list.")
    else:
        print(f"ℹ️ Using {len(existing)} pre-existing files in source folder.")

# ================= STEP 2: FOLDER STRUCTURE =================
base_output = os.path.dirname(source_folder)
final_folder = os.path.join(base_output, target_yyyymmdd)
os.makedirs(final_folder, exist_ok=True)

for folder in file_to_folder_map.values():
    os.makedirs(os.path.join(final_folder, folder), exist_ok=True)

print(f"\n📁 Output folder: {final_folder}")

# ================= STEP 3: INDEX ZIP FILES =================
print("\n📦 Processing index ZIP files...")
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
            print(f"  Moved: {filename} → {target_folder}")

            try:
                with ZipFile(dest_zip, 'r') as z:
                    z.extractall(dest_folder)
                print(f"  ✅ Extracted: {filename}")
            except Exception as e:
                print(f"  ⚠️ Failed to extract {filename}: {e}")
            break

# ================= STEP 4: NAV ZIP =================
print("\n💰 Processing NAV ZIP...")
nav_zip = next(
    (f for f in os.listdir(source_folder)
     if re.match(r'rlmf_rlmf_navcsv1_\d{6}\.zip', f.lower())),
    None
)

if nav_zip:
    # Always use T-1 target date for naming (ignore date inside ZIP filename)
    nav_zip_path = os.path.join(source_folder, nav_zip)

    try:
        with pyzipper.AESZipFile(nav_zip_path) as zf:
            zf.pwd = password
            extracted_files = zf.namelist()
            zf.extractall(source_folder)
            print(f"  ✅ Extracted NAV ZIP")

        for f in extracted_files:
            name = os.path.basename(f)
            if name:
                src = os.path.join(source_folder, name)
                dest = os.path.join(final_folder, f"NAV_{target_ddmmyyyy}.csv")
                if os.path.exists(src):
                    if os.path.exists(dest):
                        os.remove(dest)  # Remove existing file before rename
                    os.rename(src, dest)
                    print(f"  ✅ Saved: NAV_{target_ddmmyyyy}.csv")
                break
    except Exception as e:
        print(f"  ⚠️ NAV ZIP error: {e}")
else:
    print("  ℹ️ NAV ZIP not found — skipping")

# ================= STEP 5: VALUEFY ZIP =================
print("\n📊 Processing VALUEFY ZIP...")
valuefy_zip = next(
    (f for f in os.listdir(source_folder)
     if re.match(r'rlmf_rlmf_valuefy_\d{6}\.zip', f.lower())),
    None
)

if valuefy_zip:
    ddmmyy_vf = re.search(r'(\d{6})', valuefy_zip).group(1)
    zip_path = os.path.join(source_folder, valuefy_zip)

    try:
        with pyzipper.AESZipFile(zip_path) as zf:
            zf.pwd = password
            extracted_files = zf.namelist()
            zf.extractall(source_folder)
            print(f"  ✅ Extracted VALUEFY ZIP")

        parent = os.path.join(final_folder, f"VALUEFY{ddmmyy_vf}")
        dest_folder_vf = os.path.join(parent, "RLMF_RLMF_VALUEFY")
        os.makedirs(dest_folder_vf, exist_ok=True)

        for f in extracted_files:
            name = os.path.basename(f)
            if name:
                src = os.path.join(source_folder, name)
                dest = os.path.join(dest_folder_vf, name)
                if os.path.exists(src):
                    shutil.move(src, dest)
        print(f"  ✅ VALUEFY files organized")
    except Exception as e:
        print(f"  ⚠️ VALUEFY ZIP error: {e}")
else:
    print("  ℹ️ VALUEFY ZIP not found — skipping")

# ================= STEP 6: NAV & HOLDING XLSX =================
print("\n📋 Processing XLSX files...")
nav_equity = next((f for f in os.listdir(source_folder)
                   if f.lower().startswith("nav_equity") and f.lower().endswith(".xlsx")), None)

holdinglist = next((f for f in os.listdir(source_folder)
                    if f.lower().startswith("holdinglist_equity") and f.lower().endswith(".xlsx")), None)

if nav_equity:
    dest = os.path.join(final_folder, f"NAV_Equity{target_ddmmyy}.xlsx")
    shutil.move(os.path.join(source_folder, nav_equity), dest)
    print(f"  ✅ Saved: NAV_Equity{target_ddmmyy}.xlsx")

if holdinglist:
    dest = os.path.join(final_folder, f"Holdinglist_Equity{target_ddmmyy}.xlsx")
    shutil.move(os.path.join(source_folder, holdinglist), dest)
    print(f"  ✅ Saved: Holdinglist_Equity{target_ddmmyy}.xlsx")

# ================= STEP 7: FIN / FIE =================
print("\n📂 Processing FIN/FIE ZIPs...")
for prefix in ['fin', 'fie']:
    zip_file = next(
        (f for f in os.listdir(source_folder)
         if f.lower().startswith(prefix) and f.lower().endswith('.zip')),
        None
    )
    if zip_file:
        try:
            with ZipFile(os.path.join(source_folder, zip_file), 'r') as z:
                z.extractall(final_folder)
            print(f"  ✅ Extracted: {zip_file}")
        except Exception as e:
            print(f"  ⚠️ Failed to extract {zip_file}: {e}")

print(f"\n🎯 Files ready at: {final_folder}")

# ================= STEP 8: VALUEFY EXCEL CLEAN =================
print("\n🧹 Cleaning VALUEFY Excel...")
valuefy_dir = next((d for d in os.listdir(final_folder) if d.startswith("VALUEFY")), None)

if valuefy_dir:
    excel_path = os.path.join(
        final_folder, valuefy_dir,
        "RLMF_RLMF_VALUEFY", "IN_MF_TRADE_DUMP_REPORT.xls"
    )

    if os.path.exists(excel_path):
        excel = win32.gencache.EnsureDispatch('Excel.Application')
        excel.Visible = False
        excel.DisplayAlerts = False
        wb = excel.Workbooks.Open(excel_path)
        ws = wb.Sheets(1)

        # Find columns safely
        used_range = ws.UsedRange
        total_rows = used_range.Rows.Count
        total_cols = used_range.Columns.Count
        qty_col = asset_col = None

        for i in range(1, total_cols + 1):
            cell_val = ws.Cells.Item(1, i).Value
            if cell_val is None:
                continue
            h = str(cell_val).strip().lower()
            if h == "quantity":
                qty_col = i
            elif h == "asset type":
                asset_col = i

        # Debug: print headers if columns not found
        if qty_col is None or asset_col is None:
            print("  ⚠️ Column headers found in file:")
            for i in range(1, total_cols + 1):
                val = ws.Cells.Item(1, i).Value
                print(f"    Col {i}: '{val}'")
            wb.Close(False)
            excel.Quit()
            print("  ❌ Could not find 'Quantity' or 'Asset Type' columns — skipping clean step")
        else:
            print(f"  ✅ Found: Quantity=Col{qty_col}, Asset Type=Col{asset_col}")
            deleted = 0
            modified = 0
            for r in range(total_rows, 1, -1):
                qty = ws.Cells.Item(r, qty_col).Value
                asset_val = ws.Cells.Item(r, asset_col).Value
                asset = str(asset_val).strip().upper() if asset_val is not None else ""

                if qty == 0 and asset != "PTC":
                    ws.Rows(r).Delete()
                    deleted += 1
                elif qty == 0 and asset == "PTC":
                    ws.Cells.Item(r, qty_col).Value = 0.01
                    modified += 1

            wb.Save()
            wb.Close()
            excel.Quit()
            print(f"  ✅ VALUEFY Excel updated — {deleted} rows deleted, {modified} rows modified")
    else:
        print(f"  ℹ️ IN_MF_TRADE_DUMP_REPORT.xls not found — skipping")
else:
    print("  ℹ️ No VALUEFY folder found — skipping")

# ================= STEP 9: CREATE FINAL ZIP =================
print("\n🗜️ Creating final ZIP...")

zip_output_path = os.path.join(base_output, f"{target_yyyymmdd}_output.zip")

# Remove existing zip if re-running
if os.path.exists(zip_output_path):
    os.remove(zip_output_path)

with ZipFile(zip_output_path, 'w') as zipf:
    for root, dirs, files in os.walk(final_folder):
        for file in files:
            file_full_path = os.path.join(root, file)
            arcname = os.path.relpath(file_full_path, base_output)
            zipf.write(file_full_path, arcname)

zip_size_mb = os.path.getsize(zip_output_path) / (1024 * 1024)
print(f"  ✅ ZIP created: {target_yyyymmdd}_output.zip ({zip_size_mb:.1f} MB)")
print(f"  📍 Location: {zip_output_path}")

# ================= DONE =================
print(f"\n{'='*50}")
print(f"✅ NIPPON ATTRIBUTION COMPLETE")
print(f"📅 Date processed : {target_date.strftime('%d %b %Y')}")
print(f"📁 Output folder  : {final_folder}")
print(f"🗜️  Output ZIP     : {zip_output_path}")
print(f"{'='*50}")
