"""
oracle_db.py — Oracle connection and effdate fetch.
Uses python-oracledb in THIN mode (no Oracle Instant Client needed on server).
"""

import oracledb
from datetime import datetime, date
from logger import Logger

# Enable thick mode for Native Network Encryption support
oracledb.init_oracle_client(lib_dir=r"C:\app\client\product\19.0.0\client_1\bin")


def get_connection(cfg: dict) -> oracledb.Connection:
    """
    Opens and returns an Oracle connection using thin mode.
    cfg keys: Host, Port, ServiceName, User, Password
    """
    oracle_cfg = cfg["Oracle"]
    dsn = oracledb.makedsn(
        host=oracle_cfg["Host"],
        port=int(oracle_cfg["Port"]),
        service_name=oracle_cfg["ServiceName"],
    )
    conn = oracledb.connect(
        user=oracle_cfg["User"],
        password=oracle_cfg["Password"],
        dsn=dsn,
    )
    return conn


EFFDATE_SQL = """
    SELECT MIN(effective_date)
    FROM Business_Calendar
    WHERE dataload_status = 0
      AND Businessday_flag = 1
      AND effective_date > (
          SELECT MAX(effective_date)
          FROM business_calendar
          WHERE dataload_status = 1
      )
"""


def fetch_effdate(cfg: dict, log: Logger) -> date | None:
    """
    Fetches the next unprocessed business date from Business_Calendar.
    Returns a date object, or None on failure.
    """
    try:
        log.info("Connecting to Oracle to fetch effdate...")
        conn = get_connection(cfg)
        cur = conn.cursor()
        cur.execute(EFFDATE_SQL)
        row = cur.fetchone()
        cur.close()
        conn.close()

        if row is None or row[0] is None:
            log.error("effdate query returned NULL — no unprocessed business day found.")
            return None

        result = row[0]
        if isinstance(result, datetime):
            result = result.date()
        elif isinstance(result, date):
            pass
        else:
            result = datetime.strptime(str(result), "%Y-%m-%d").date()

        log.info(f"Fetched effdate: {result:%Y-%m-%d}")
        return result

    except oracledb.Error as e:
        log.error(f"Oracle error fetching effdate: {e}")
        return None
    except Exception as e:
        log.error(f"Unexpected error fetching effdate: {e}")
        return None
