# ETL Pipeline — Logic Document
> Source: `_archive/Server side/NET` (C# / .NET)  
> Target: Convert to Python

---

## Overview

A daily ETL pipeline that:
1. Downloads market data files (DION + BSE + VBS macro)
2. Loads data into Oracle via stored procedures
3. Runs transformation & attribution stored procs
4. Exports a Holdings Excel report
5. Marks the day as complete in Oracle

---

## Configuration (`appsettings.json`)

All paths, credentials, and thresholds are externalized:

| Section | Purpose |
|---|---|
| `Scripts` | Paths to VBS/PS1 scripts |
| `LogFiles` | App log path, copy log path |
| `OutputFiles` | ETL output XLS path, macro log directory |
| `Oracle` | Connection string + steps file path |
| `DionFileChecks` | File size checks (KB range per prefix) |
| `DionExcelValidations` | Row count checks per Dion file (date column + count range) |
| `HoldingsReport` | Template path, output dir, SQL file, data start row |

---

## Entry Point — `Main()`

### CLI Modes

| Argument | Action |
|---|---|
| `--write-effdate` | Fetch effdate from Oracle, write to `effdate.txt`, exit |
| `--test-holdings` | Fetch effdate, run Holdings report only, exit |
| *(no args)* | Full pipeline run |

---

## Full Pipeline — Step by Step

### PRE-STEP: Fetch Effective Date (effdate)

**SQL:**
```sql
SELECT MIN(effective_date)
FROM Business_Calendar
WHERE dataload_status = 0
  AND Businessday_flag = 1
  AND effective_date > (
    SELECT MAX(effective_date)
    FROM business_calendar
    WHERE dataload_status = 1
  )
```
- Returns the **next unprocessed business day**
- If `NULL` → abort with error
- Used as `:effdate` parameter throughout all subsequent steps

---

### STEP 0 — DION Downloader (VBS)

**Logic:**
1. For each `DionFileCheck` entry:
   - Check directory exists
   - Find latest file matching `{FilePrefix}*` by modified time
   - Check file size is within `[MinKb, MaxKb]`
   - Parse date from filename: format is `{prefix}{ddMMyyyy}{rest}.xlsx`
   - Confirm parsed date == effdate
2. For each `DionExcelValidation` entry (if all size checks pass):
   - Open the Excel file
   - Count rows in Sheet 1 where column `DateColumn` == effdate
   - Confirm count is within `[MinCount, MaxCount]`

**Decision:**
- If **ALL checks pass** → skip DION Downloader (files already ready)
- Otherwise → run `wscript.exe DionDownloader_latest.vbs`
  - On non-zero exit → abort with exit code 10/11

**DION Files Tracked:**

| Prefix | Dir | Size (KB) | Row Count Range | Date Column |
|---|---|---|---|---|
| `DION_AVGVOL_` | DionEODPrices | 410–500 | 7000–9999 | A |
| `DION_INDEX_RETURNS_` | DionEODPrices | 12–20 | 15–999 | A |
| `DION_NAV_RETURNS_` | DionEODPrices | 700–1400 | 5000–9999 | A |
| `DION_EOD_PRICES_` | DionEODPrices | 500–600 | 4000–9999 | A |

---

### STEP 1 — BSE Downloader (PowerShell)

- Run `powershell.exe -ExecutionPolicy Bypass -File bse.ps1`
- Capture stdout/stderr
- On non-zero exit → abort with exit code 1/2
- After success → read and log the **last line** of `copy_log.txt`

---

### STEP 2 — Read copy_log.txt

- Open `copy_log.txt` (shared read)
- Log the last line as a status indicator
- No pass/fail check — informational only

---

### STEP 3 — VBS Macro (ETL Data XLS generation)

- Run `wscript.exe Test.vbs`
- On non-zero exit → abort with exit code 1/2
- On success:
  - Check output file `ETLDATA.xls`:
    - Log size (MB), last modified time
    - **Alert** if file was not modified within 7 minutes of module start
  - Find latest `log_*` file in `MacroLogDirectory` → log its name and modified time

---

### STEP 4 — Oracle ETL (Stored Procedures + Validations)

This is the core ETL stage, driven by `oracle_steps.json`.

#### 4a. Connect to Oracle

#### 4b. Update `daily_process_stats` (pre-ETL reset)

```sql
UPDATE daily_process_stats 
SET currdatadate = (SELECT currdatadate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
    lastdatadate = (SELECT lastdatadate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
    rundate      = (SELECT rundate      FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
    dataready    = 0,
    status       = NULL
WHERE process_name IN ('ETL STAGE 1', 'ETL STAGE 2')
```

#### 4c. Execute Oracle Steps (from `oracle_steps.json`)

Each step has:
- `Name` — label for logging
- `Enabled` — if false, skip
- `ProcedureBlock` — raw SQL/PL-SQL block (`BEGIN proc; END;` or `UPDATE ...`)
- `Validations[]` — list of scalar SQL checks with a type

**Validation Types:**

| Type | Rule |
|---|---|
| `NonZeroCount` | `COUNT(*)` result must be > 0 |
| `MustBeNull` | scalar result must be `NULL` |
| *(unknown)* | Log result, no pass/fail |

**If validation fails → abort with exit code 23 / 24**

#### Full Step Sequence:

| # | Step Name | Procedure | Validation |
|---|---|---|---|
| 1 | FUTURE OPTIONS MASTER | `SP_LDG_FUT_OPTSMASTER_XLS` | `future_options_master_src` count > 0; ETL STAGE 1 status = NULL |
| 2 | CORPORATE ACTIONS EXC | `SP_LDG_CORPACTEXC_XLS` | `CORPORATE_ACTIONS_EXC_SRC` count for effdate > 0; stage 1 = NULL |
| 3 | CORPORATE ACTIONS | `SP_LDG_CORPACTIONS_XLS` | *(no validation)* |
| 4 | DAILY EOD PRICES | `SP_LDG_DAILY_EOD_PRICES_XLS` | `DAILY_SECURITY_PRICES_SRC` count for effdate > 0; stage 1 = NULL |
| 5 | INDEX RETURNS | `SP_LDG_INDEX_RETURNS_XLS` | `INDEX_RETURNS_SRC` count for effdate > 0; stage 1 = NULL |
| 6 | NAV RETURNS | `SP_LDG_NAV_RETURNS_XLS` | `NAV_RETURNS_SRC` count for effdate > 0; stage 1 = NULL |
| 7 | FUND HOLDINGS | `SP_LDG_FUNDHOLDINGS_XLS` | `FUND_HOLDINGS_SRC` count for effdate > 0; stage 1 = NULL |
| 8 | DAILY PRICES | `SP_LDG_DAILYPRICES_XLS` | *(no validation)* |
| 9 | TRANSACTION DATA | `SP_LDG_TXNDATA_XLS` | `TRANSACTION_DATA_SRC` count for effdate > 0; stage 1 = NULL |
| 10 | FUND NAV | `SP_LDG_FUNDNAV_XLS` | `Fund_NAV_Src` count for effdate > 0; stage 1 = NULL |
| 11 | INDEX DATA | `SP_LDG_INDEXDATA_XLS` | `Index_Data_Src` count for effdate > 0; stage 1 = NULL |
| 12 | INDEX DATA TRI | `SP_LDG_INDEXDATATRI_XLS` | `Index_Data_Src` TRI rows count for effdate > 0; stage 1 = NULL |
| 13 | INDEX PRICES | `SP_LDG_INDEXPRICES_XLS` | `Index_Prices_Src` count for effdate > 0; stage 1 = NULL |
| 14 | AVERAGE VOLUME | `SP_LDG_AVG_VOL_XLS` | `AVERAGE_VOLUME_SRC` count for effdate > 0; stage 1 = NULL |
| 15 | MODEL DATA | `SP_LDG_INDEXDATA_MODEL_XLS` | *(no validation)* |
| 16 | MODEL PORTFOLIO | `SP_LDG_MODELPORTFOLIO_XLS` | *(no validation)* |
| 17 | DION FNO MASTER | `SP_LDG_DION_FNO_MASTER_XLS` | `DION_FNO_MASTER_SRC` count > 0; stage 1 = NULL |
| 18 | FINAL STATUS CHECK | *(no proc)* | ETL STAGE 1 status = NULL |
| 19 | SET ETL STAGE 1 DATAREADY | `UPDATE daily_process_stats SET dataready=1 WHERE process_name='ETL STAGE 1'` | *(none)* |
| 20 | TRANSFORMATION | `sp_transform_main` | ETL STAGE 2 status = NULL |
| 21 | UPDATE DAILY ATTRIB | `UPDATE daily_process_stats ... WHERE process_name='DAILY ATTRIB'` | *(none)* |
| 22 | ATTRIBUTION | `sp_valat_main` | *(none)* |
| 23 | SET DAILY ATTRIB DATAREADY | `UPDATE daily_process_stats SET dataready=1 WHERE process_name='DAILY ATTRIB'` | *(none)* |
| 24 | UPDATE BUSINESS_CALENDAR | `UPDATE business_calendar SET dataload_status=1 WHERE ...` | *(none)* |
| 25 | COMMIT | `COMMIT` | *(none)* |

---

### STEP 5 — Holdings Report Export

**Trigger:** Runs after Oracle steps succeed, if `HoldingsReport` config is present.

**Logic:**
1. Call Oracle stored procedure:
   ```sql
   BEGIN FINAL_HOLDINGS_REPORT(:effdate, :out_cursor); END;
   ```
   - Returns a `REF CURSOR` → load into a `DataTable`
   - If 0 rows → log warning but continue

2. Open `Holdings_Template.xls` (NPOI/openpyxl)

3. Set cell `B3` = effdate (formatted `dd-mmm-yy`)

4. Write data rows starting from row `DataStartRow` (default row 6):
   - Column A (index 0) = date → apply date format
   - Numeric columns → write as float
   - Null → write empty string

5. **Validation — Script Weight per Scheme:**
   - Column C (index 2) = Scheme Name
   - Column M (index 12) = Script Weight in Fund
   - Sum weights per scheme across all rows
   - Each scheme total must be within `[99.99, 100.02]`
   - Schemes outside range → log WARNING (file still saved)

6. Save output as `Holdings_{dd-MMM-yy}.xls` in `OutputDirectory`

---

## Logging

- Append-only log file (UTF-8)
- Initialized fresh on each run with a header line
- Every step logs: start, result, elapsed time
- Structured as plain text lines (not JSON like `Logger.cs`)
- Log path: configurable via `LogFiles.AppLog`, defaults to `MacroTest.log`

---

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | PowerShell / VBS macro failed |
| 2 | PowerShell / VBS exception |
| 10 | DION Downloader non-zero exit |
| 11 | DION Downloader exception |
| 12 | Config load failure |
| 20 | Oracle connection/query error (OracleException) |
| 21 | Oracle general error |
| 22 | Could not retrieve effdate |
| 23 | NonZeroCount validation failed |
| 24 | MustBeNull validation failed |
| 25 | oracle_steps.json not found |
| 26 | oracle_steps.json parse error |
| 27 | oracle_steps.json has no steps |
| 28 | Dion Excel row-count validation failed |
| 29 | Holdings export failed |
| 99 | Unhandled outer exception |

---

## Key Design Decisions to Preserve in Python

1. **Effdate is fetched once early** and reused everywhere (avoid re-querying)
2. **DION file skip logic** — if files are already valid, skip the VBS downloader entirely
3. **Oracle steps are data-driven** (`oracle_steps.json`) — not hardcoded; each step can be enabled/disabled
4. **Validation is per-step** — failure stops the pipeline immediately (fail-fast)
5. **`:effdate` binding** — check if SQL contains `:effdate` before adding the parameter
6. **Holdings weight validation** is a soft check (warning, not abort)
7. **All steps log elapsed time** — important for monitoring
8. **Config path resolution**: paths can be absolute or relative to exe/script directory
