# Live Portfolio — Reference Files Index

This folder contains the **original .NET / Oracle source files** from the legacy ValueAT system.
Use these as reference when building or extending the new Node.js / MS SQL implementation.

---

## Files in `old docs/`

| File | Type | Purpose |
|---|---|---|
| `FundReportVF.aspx.cs` | .NET C# code-behind | All backend WebMethods for the Live Portfolio page |
| `fe_live.txt` | Oracle PL/SQL | Main stored procedure `SP_FE_LIVE` — portfolio data fetch |
| `LIVE PORTFOLIO.docx` | Word document | UI/feature specification document |

---

## FundReportVF.aspx.cs — Method-by-Method Map

Each method from the old .NET system, what Oracle SP it called, and migration status in the new system.

| # | Old .NET Method | Old Oracle SP | New Node.js API | New MSSQL SP | Status |
|---|---|---|---|---|---|
| 1 | `Page_Load` | — | Angular `ngOnInit()` | — | ✅ Done |
| 2 | `SetFundList()` | `SP_FE_FR_FUNDS` | `GET /funds` | `SP_API_FUNDLIST` | ✅ Done |
| 3 | `SetIndexList()` | `SP_FE_FR_INDICES` | `GET /funds/indices` | `SP_API_INDEXLIST` | ✅ Done |
| 4 | `SetLayoutList()` | `SP_FE_FR_LAYOUTS` | `GET /layouts` | `SP_API_LAYOUTS` | ✅ Done |
| 5 | `GetFundParameters()` | `SP_FE_FR_DATE_INDEX` | `GET /funds/:id/params` | `SP_API_FUND_PARAMS` | ✅ Done |
| 6 | `GetTableData()` | `SP_FE_LIVE` | `GET /portfolio` | `SP_API_LIVE_PORTFOLIO` | ✅ Done |
| 7 | `Get_EODFundIdx_Ret()` | `SP_FE_SPEC_FIDX_RET` | `GET /portfolio/return` | `SP_API_FUND_IDX_RETURN` | ✅ Done |
| 8 | `GetLivePriceDataREL()` | `ValueAT_EQUITYLIVEPRICES` (DION DB) | `GET /portfolio/live-prices` | `SP_API_LIVE_PRICES` | ⚠ Partial — currently reads `security_closeprices` not DION |
| 9 | `GetLiveIndexDataREL()` | DION DB — live index value | Not yet built | Not yet built | ❌ Not migrated |
| 10 | `UpdateLayout()` | `SP_FE_UPDATE_LAYOUT` | `PUT /layouts/:id` | `SP_API_UPDATE_LAYOUT` | ✅ Done |
| 11 | `SaveLayout()` | `SP_FE_SAVE_LAYOUT` | `POST /layouts` | `SP_API_SAVE_LAYOUT` | ✅ Done |
| 12 | `LoadLayout()` | `SP_FE_LOAD_LAYOUT` | `GET /layouts` | `SP_API_LAYOUTS` | ✅ Done |
| 13 | `GetHistoricalPerformance()` | `SP_FE_HIST_PERF` | Not yet built | Not yet built | ❌ Not migrated |
| 14 | `GetTurnOverRatio()` | `SP_FE_LIVE_TURNOVER_RAT` | Not yet built | Not yet built | ❌ Not migrated — placeholder KPI box |

---

## fe_live.txt — Oracle SP Column-by-Column Map

Original Oracle SP: `SP_FE_LIVE` → Migrated as: `SP_API_LIVE_PORTFOLIO`

### Input Parameters

| Old Oracle Param | New MSSQL Param | Notes |
|---|---|---|
| `FUNDID` (NUMBER) | `@fund_id` (INT) | |
| `INDEXID` (NUMBER) | `@index_id` (INT) | |
| `RUN_DATE` (DATE) | `@run_date` (DATE) | |
| `REP_TYPE` (VARCHAR) | — | Removed; always 'LIVE' behavior |
| `LOGINID` (VARCHAR) | `@user_id` (INT) | Changed from login string to user_id |

### Output Columns — Security Rows

| Old Oracle Column | New MSSQL Column | Old Table Source | New Table Source | Status |
|---|---|---|---|---|
| `SECTOR` | `sector` | `Sectors.SECTOR_SHORT_NAME` via `SECURITY_SECTOR_MAPPING` | `level_value_master.level_value_name` via `mapping_security_level` (level_id=1) | ✅ Done |
| `SECURITY_NAME` | `security_name` | `security_master.SECURITY_NAME` | `security_master.security_name` | ✅ Done |
| `ISIN` | `isin_code` | `security_code_bbisin_intmdt.SOURCE_SECURITY_CODE` | `security_master.isin_number` | ✅ Done |
| `INDEXFLAG` | `index_flag` | Derived from `security_underliers` | Derived from `instrument_master` | ✅ Done |
| `FUNDFLAG` | `fund_flag` | Derived from join | Derived from join | ✅ Done |
| `FUNDQTY` | `fund_qty` | `fund_holdings_live.QUANTITY` | `fund_holdings.quantity` | ✅ Done |
| `CMP` | `cmp` | `fund_holdings_live.MTM_VALUE_P / QUANTITY` (live) | `security_closeprices.closep` (NSE then BSE) → overwritten by polling | ✅ Done |
| — | `close_price` | Not in old system (same as CMP) | `security_closeprices.closep` (fixed EOD) | ✅ Added |
| `RET_1D` | `ret_1d` | `SECURITY_RETURNS.RET_1D` | `fund_security_returns.portfolio_return` (report_id=latest) | ✅ Done |
| `RET_5D` | `ret_5d` | `SECURITY_RETURNS.RET_5D` | Compound over last 5 report_ids | ✅ Done |
| `RET_1M` | `ret_1m` | `SECURITY_RETURNS.RET_1M` | Compound over last 21 report_ids | ✅ Done |
| `RET_3M` | `ret_3m` | `SECURITY_RETURNS.RET_3M` | Compound over last 63 report_ids | ✅ Done |
| `RET_6M` | `ret_6m` | `SECURITY_RETURNS.RET_6M` | Compound over last 126 report_ids | ✅ Done |
| `RET_1Y` | `ret_1y` | `SECURITY_RETURNS.RET_1Y` | Compound over last 252 report_ids | ✅ Done |
| `RET_YTD` | `ret_ytd` | `SECURITY_RETURNS.RET_YTD` | Compound from Jan 1 to eff_date | ✅ Done |
| `FUND_MTM` | `fund_mtm` | `fund_holdings_live.MTM_VALUE / 10M` | `fund_holdings.mtm_value / 10M` | ✅ Done |
| `FUND_MTM_CHG` | `fund_mtm_chg` | `(MTM × (1 + RET_1D) − MTM) / 10M` | `mtm_value × ret_1d / 10M` | ✅ Done |
| `FUND_WTS` | `fund_wts` | `MTM_VALUE / FUND_AUM` | `mtm_value / SUM(mtm_value)` | ✅ Done |
| `INDEX_WTS` | `index_wts` | `INDEX_CONSTITUENTS_LIVE.WEIGHTS` | `index_constituents.weights` | ✅ Done |
| `FUND_AUM` | `fund_aum` | `fund_nav.nav` | `SUM(fund_holdings.mtm_value) / 10M` | ✅ Done |
| `MCAP` | `mcap` | `SECURITY_RETURNS.MARKETCAP` | `security_dynamic_factors.marketcap` | ✅ Done |
| `MCAP_BUCKET` | `size` | `SECURITY_DYNAMIC_FACTORS.MARKETCAP_BUCKET` | `mapping_security_level` (level_id=5) → LC/MC/SC — imported from KotakLife | ✅ Done |
| `AVG_VOL` / `AVGADVT` | `avg_vol` | `AVERAGE_VOLUME.AVGVOLUME_3M` | `security_dynamic_factors.avg_volume` | ⚠ Partial — `security_dynamic_factors` has no data currently |
| `Rating` | `rating` | `security_rating_intmdt.RATING` | `security_rating_mapping.rating` (new table, sample data) | ✅ Done |
| `BOOK_VALUE` | — | `fund_holdings_live.ammortised_book_cost` | Removed from grid | ⚠ Not shown |
| `BONUS_SPLIT` | — | `mtm_affecting_cas_live` | `corporate_actions` (type_id IN 2,3,4) — `old_ratio:new_ratio` string | ❌ Not migrated — data exists |
| `DIVIDEND_PAYOUT` | — | `mtm_affecting_cas_live` | `corporate_actions` (type_id IN 1,11) — `coupon_dividend` field | ❌ Not migrated — data exists |
| `SUBSECTOR` | — | `Sectors` (SECTOR_CLASS_ID=3) | **Not migrated** (Sub sector checkbox disabled) | ❌ Not migrated |

### Output Columns — Sector Summary Rows

| Aspect | Old Oracle | New MSSQL | Status |
|---|---|---|---|
| Sector name | `Sectors.SECTOR_SHORT_NAME` | `level_value_master.level_value_name` | ✅ Done |
| Weighted returns | `SUM(RET × WT) / SUM(WT)` | Same formula | ✅ Done |
| `is_sector_row` flag | Implicit (ISIN = 'Sector') | Explicit `is_sector_row = 1` | ✅ Done |
| Sub-sector rows | YES — `SECTOR_CLASS_ID=3` | NO — not yet implemented | ❌ Not migrated |

---

## Key Architecture Differences: Oracle → MSSQL

| Topic | Old Oracle System | New MSSQL System |
|---|---|---|
| **Live prices source** | DION database (`ValueAT_EQUITYLIVEPRICES`) via `DionCommon` class | `security_closeprices` (MSSQL); DION not yet connected |
| **Security lookup** | `security_code` (proprietary code) | `security_id` (integer PK) |
| **ISIN mapping** | `security_code_bbisin_intmdt.SOURCE_SECURITY_CODE` | `security_master.isin_number` (direct) |
| **Sector mapping** | `SECURITY_SECTOR_MAPPING` + `Sectors` table | `mapping_security_level` (level_id=1) + `level_value_master` |
| **Market cap bucket** | `SECURITY_DYNAMIC_FACTORS.MARKETCAP_BUCKET` | `mapping_security_level` (level_id=5) — imported from KotakLife |
| **Ratings** | `security_rating_intmdt` | `security_rating_mapping` (new table, sample data) |
| **Fund holdings** | `fund_holdings_live` (live data) | `fund_holdings` (UAT historical — max date 2025-01-01) |
| **Index constituents** | `INDEX_CONSTITUENTS_LIVE` | `index_constituents` |
| **Returns** | `SECURITY_RETURNS` (pre-computed per security) | `fund_security_returns` (per fund+security+report) |
| **AUM** | `fund_nav.nav` (NAV table) | `SUM(fund_holdings.mtm_value)` |
| **Layout storage** | `report_layouts` table | `report_layouts` table (same) |

---

## What Still Needs to Be Built

Based on this old code, the following features exist in the old system but are **not yet in the new system**:

| Feature | Old Method | Old Oracle SP | Priority |
|---|---|---|---|
| **DION live prices** | `GetLivePriceDataREL()` | `ValueAT_EQUITYLIVEPRICES` (DION) | High — needed for real live prices |
| **Live index value** | `GetLiveIndexDataREL()` | DION DB | Medium |
| **Turnover Ratio** | `GetTurnOverRatio()` | `SP_FE_LIVE_TURNOVER_RAT` | Medium — KPI box placeholder |
| **Historical Performance** | `GetHistoricalPerformance()` | `SP_FE_HIST_PERF` | Low |
| **Sub-sector grouping** | Embedded in `SP_FE_LIVE` | `SECURITY_SECTOR_MAPPING` (SECTOR_CLASS_ID=3) | Low |
| **Bonus/Split adjustment** | Embedded in `SP_FE_LIVE` | `mtm_affecting_cas_live` → **new: `corporate_actions` type 2/3/4** | Low — data available; needs SP update |
| **Dividend payout** | Embedded in `SP_FE_LIVE` | `mtm_affecting_cas_live` → **new: `corporate_actions` type 1/11** | Low — data available; needs SP update |
| **52 Week High / Low** | `GetLivePriceDataREL()` — `FTW_HIGH`, `FTW_LOW` columns | `ValueAT_EQUITYLIVEPRICES` or `security_closeprices` | Medium |

---

---

## Corporate Actions Table Reference

**Table:** `dbo.corporate_actions` — 12,014 rows (2000-10-26 → 2024-12-27)

### Schema

| Column | Type | Description |
|---|---|---|
| `security_id` | INT | FK → `security_master.security_id` |
| `effective_date` | DATE | Date the action takes effect |
| `corporate_action_type_id` | INT | FK → `corporate_action_master.id` |
| `coupon_dividend` | DECIMAL | Dividend / coupon amount (₹ per share) — used for type 1 (DIVIDEND) and 11 (COUPON) |
| `old_ratio` | INT | For splits/bonus: denominator of ratio |
| `new_ratio` | INT | For splits/bonus: numerator of ratio |
| `equity_adjustment_factor` | DECIMAL | Price adjustment multiplier for equity |
| `nominal_adjustment_factor` | DECIMAL | Price adjustment multiplier for nominal value |
| `redemption_unit_pv` | DECIMAL | Redemption face value per unit |
| `new_security_id` | INT | Used on merger/ISIN change — new security after event |
| `sequence_number` | INT | Order when multiple CAs happen on same date |

### Action Types (`dbo.corporate_action_master`)

| type_id | Name | Relevant Columns | Grid Use |
|---|---|---|---|
| 1 | DIVIDEND | `coupon_dividend` (₹/share) | `DIVIDEND_PAYOUT` column |
| 2 | BONUS | `old_ratio`, `new_ratio` (e.g. 1:3 = 3 bonus shares for every 1 held) | `BONUS_SPLIT` column |
| 3 | STOCK SPLITS | `old_ratio`, `new_ratio` (e.g. 1:2 = split into 2 shares) | `BONUS_SPLIT` column |
| 4 | REVERSE STOCK SPLITS | `old_ratio`, `new_ratio` | `BONUS_SPLIT` column |
| 5 | NAME CHANGE | — | Not shown in grid |
| 6 | RIGHTS ISSUE | `old_ratio`, `new_ratio` | Not shown in grid |
| 7 | MERGER | `new_security_id` | Not shown in grid |
| 8 | DEMERGER | `new_security_id` | Not shown in grid |
| 9 | LISTING | — | Not shown in grid |
| 10 | DELISTING | — | Not shown in grid |
| 11 | COUPON | `coupon_dividend` (₹/unit — debt instruments) | `DIVIDEND_PAYOUT` column |
| 12 | ISIN CHANGE | `new_security_id` | Not shown in grid |
| 13 | REDEMPTION | `redemption_unit_pv` | Not shown in grid |
| 14 | REVALUATION | — | Not shown in grid |

### Supplementary: `stage.mapping_corporate_action_type`
Alternative mapping table with the same 14 types — stored in the `stage` schema.

### How to Show in Grid (SP Implementation Guidance)

**`BONUS_SPLIT` column** — show latest bonus/split event within the last 365 days:
```sql
-- In SP_API_LIVE_PORTFOLIO, add CTE:
BONUS_SPLIT_MAP AS (
    SELECT security_id,
           MAX(effective_date) AS ca_date,
           MAX(CASE WHEN corporate_action_type_id IN (2,3,4)
               THEN CAST(old_ratio AS VARCHAR) + ':' + CAST(new_ratio AS VARCHAR) END) AS bonus_split_ratio
    FROM dbo.corporate_actions
    WHERE corporate_action_type_id IN (2,3,4)
      AND effective_date >= DATEADD(YEAR,-1,GETDATE())
    GROUP BY security_id
)
-- Then LEFT JOIN BONUS_SPLIT_MAP bsm ON bsm.security_id = alld.security_id
-- Output: bsm.bonus_split_ratio AS bonus_split, bsm.ca_date AS bonus_split_date
```

**`DIVIDEND_PAYOUT` column** — show latest dividend/coupon within the last 365 days:
```sql
-- In SP_API_LIVE_PORTFOLIO, add CTE:
DIVIDEND_MAP AS (
    SELECT security_id,
           MAX(effective_date) AS div_date,
           MAX(coupon_dividend) AS dividend_amount
    FROM dbo.corporate_actions
    WHERE corporate_action_type_id IN (1,11)
      AND effective_date >= DATEADD(YEAR,-1,GETDATE())
    GROUP BY security_id
)
-- Then LEFT JOIN DIVIDEND_MAP dm ON dm.security_id = alld.security_id
-- Output: dm.dividend_amount AS dividend_payout, dm.div_date AS dividend_date
```

---

*Reference only — do not execute old Oracle code in new system.*
