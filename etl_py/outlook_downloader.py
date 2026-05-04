"""
outlook_downloader.py — Downloads email attachments from Outlook into Downloads folder.
Scans Inbox + Attrib subfolder for allowed senders on the effdate from business_calendar.

To skip this step in main.py, comment out the 3 lines under STEP 0 (pre-download).
"""

import os

import win32com.client as win32

from logger import Logger
from oracle_db import fetch_effdate

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DOWNLOAD_FOLDER = r"C:\Users\sa_pim_windows\Downloads"

ALLOWED_SENDERS = [
    "secureinbox.autobahn@db.com",
    "feed@bilav.com",
    "indices@nse.co.in",
    "operation3@nam.co.jp",
    "arvind.kale@db.com",
    "archana.raghuraman@db.com"
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_folder_by_name(parent, name):
    try:
        for folder in parent.Folders:
            if folder.Name.lower() == name.lower():
                return folder
            found = _find_folder_by_name(folder, name)
            if found:
                return found
    except:
        pass
    return None


def _download_from_folder(outlook_folder, folder_label, target_yyyymmdd, log):
    count = 0
    try:
        messages = outlook_folder.Items
        messages.Sort("[ReceivedTime]", True)
        for msg in messages:
            try:
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

                received = msg.ReceivedTime
                received_date = received.strftime('%Y%m%d') if hasattr(received, 'strftime') else str(received)[:10].replace('-', '')
                if received_date != target_yyyymmdd:
                    continue

                for attachment in msg.Attachments:
                    att_name = attachment.FileName
                    dest_path = os.path.join(DOWNLOAD_FOLDER, att_name)
                    if not os.path.exists(dest_path):
                        attachment.SaveAsFile(dest_path)
                        log.info(f"  Downloaded: {att_name} (from {sender})")
                        count += 1
                    else:
                        log.info(f"  Already exists: {att_name}")
            except Exception:
                continue
    except Exception as e:
        log.warn(f"  Error scanning {folder_label}: {e}")
    return count


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def run(cfg: dict, log: Logger) -> bool:
    """
    Downloads Outlook attachments for the effdate into DOWNLOAD_FOLDER.
    Returns True on success, False on fatal failure.
    """
    target_date = fetch_effdate(cfg, log)
    if target_date is None:
        log.error("Could not fetch effdate from business_calendar.")
        return False

    target_yyyymmdd = target_date.strftime('%Y%m%d')
    target_ddmmyy   = target_date.strftime('%d%m%y')
    log.info(f"Processing date: {target_date.strftime('%d %b %Y')} ({target_yyyymmdd})")

    os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

    log.info("Connecting to Outlook...")
    try:
        outlook = win32.Dispatch("Outlook.Application").GetNamespace("MAPI")
    except Exception as e:
        log.error(f"Failed to connect to Outlook: {e}")
        return False

    downloaded_count = 0

    # Scan Inbox
    inbox = outlook.GetDefaultFolder(6)
    downloaded_count += _download_from_folder(inbox, "Inbox", target_yyyymmdd, log)

    # Scan Attrib subfolder
    attrib_folder = None
    try:
        attrib_folder = inbox.Folders["Attrib"]
    except:
        pass

    if attrib_folder is None:
        try:
            for store in outlook.Folders:
                attrib_folder = _find_folder_by_name(store, "Attrib")
                if attrib_folder:
                    break
        except:
            pass

    if attrib_folder:
        downloaded_count += _download_from_folder(attrib_folder, "Attrib", target_yyyymmdd, log)
    else:
        log.warn("  'Attrib' folder not found in Outlook — skipping")

    log.info(f"Total attachments downloaded: {downloaded_count}")

    if downloaded_count == 0:
        existing = [f for f in os.listdir(DOWNLOAD_FOLDER) if target_yyyymmdd in f or target_ddmmyy in f]
        if not existing:
            log.error(f"No attachments found for {target_yyyymmdd}. Check Outlook folders and sender list.")
            return False
        else:
            log.info(f"Using {len(existing)} pre-existing files in Downloads folder.")

    log.info(f"Done. Files saved to: {DOWNLOAD_FOLDER}")
    return True


if __name__ == "__main__":
    from config import load_config
    _cfg = load_config()
    _log = Logger("outlook_downloader.log")
    success = run(_cfg, _log)
    print("Result:", "SUCCESS" if success else "FAILED")
