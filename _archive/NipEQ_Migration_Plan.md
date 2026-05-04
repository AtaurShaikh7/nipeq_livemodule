# NipEQ Migration Plan
### Migration: ValueAT (.NET / Oracle) → Node.js + MS SQL + Angular 19

**Server:** `10.11.3.10:1433`
**Primary DB:** `ValueAT_UAT_Nippon`
**Supplementary DB:** `KotakLife` (same server — market cap reference data)
**Last updated:** 2026-04-02 (added Corporate Actions reference — Section 8)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Angular 19 SPA (localhost:4200)                        │
│  ├─ Login Screen          auth/login                    │
│  └─ Live Portfolio Screen portfolio/                    │
│       ├─ Controls Row (fund / index / date)             │
│       ├─ KPI Stats Strip  (14 boxes)                    │
│       ├─ Tab Bar + Filters                              │
│       └─ AG Grid (data grid)                            │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP + JWT  /api/*
┌────────────────────▼────────────────────────────────────┐
│  Node.js + Express API (localhost:3000)                  │
│  ├─ /auth         auth.controller.ts                    │
│  ├─ /funds        fund.controller.ts                    │
│  ├─ /portfolio    portfolio.controller.ts               │
│  ├─ /layouts      layout.controller.ts                  │
│  └─ /activity-log log.controller.ts                     │
└────────────────────┬────────────────────────────────────┘
                     │ mssql (node package)
┌────────────────────▼────────────────────────────────────┐
│  MS SQL Server — ValueAT_UAT_Nippon                     │
│  11 Stored Procedures  (all deployed)                   │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Login Screen

| Element | Source | Table | Field / Logic |
|---|---|---|---|
| Email / Login ID | User input | `user_master` | `login_id` (looked up via `SP_API_LOGIN`) |
| Password | User input | `user_master` | `password` — bcrypt hash verified with **bcryptjs** |
| JWT Token | API response | — | Signed with `NipEQ_JWT_Secret_2025`, expiry 8h |
| **Login credential** | — | — | `support@valuefy.com` / `NipEQ@2025` |

---

## 3. Live Portfolio Screen

### 3.1 Controls Row

| Element | SP Called | Table(s) | Field / Logic |
|---|---|---|---|
| **Fund Name dropdown** | `SP_API_FUNDLIST` | `mapping_fund_user` → `fund_master` | Lists funds mapped to logged-in user; `fund_id`, `fund_name` |
| **Default fund selection** | `SP_API_FUNDLIST` | `mapping_fund_user` | `is_default_fund = 1` → auto-selects on load (currently fund_id=1533, type=EQ) |
| **Layout Name dropdown** | `SP_API_LAYOUTS` | `report_layouts` | `layout_id`, `layout_name`, `is_default_layout` |
| **Index Name dropdown** | `SP_API_INDEXLIST` | `index_master` | `index_id`, `index_name`, `index_short_name` |
| **Auto index on fund change** | `SP_API_FUND_PARAMS` | `mapping_fund_index` (is_default_index=1) → `index_master` | Index dropdown auto-updates when user picks a different fund |
| **Report Date picker** | `SP_API_FUND_PARAMS` | `fund_holdings` | `MAX(effective_date)` ≤ today; defaults to latest available data date |
| **Process button** | `SP_API_LIVE_PORTFOLIO` | (see Section 3.3) | Loads grid; runs automatically on first page open |

---

### 3.2 KPI Stats Strip — Element-wise Data Source

> All stats computed in `computeStats()` from rows returned by `SP_API_LIVE_PORTFOLIO`.
> Fund/Index returns fetched separately via `SP_API_FUND_IDX_RETURN`.

| # | KPI Box | Value | Table(s) | Column / Calculation |
|---|---|---|---|---|
| 1 | **Fund Ret. (%)** | e.g. `0.0%` | `fund_security_returns`, `report_references` | `fund_1d × 100` — 1-day weighted fund return from `SP_API_FUND_IDX_RETURN` |
| 2 | **Alpha (%)** | e.g. `0.0%` | Derived | `Fund Ret. − Index Ret.` (frontend calc) |
| 3 | **Index Ret. (%)** | e.g. `0.0%` | `fund_security_returns`, `report_references` | `index_1d × 100` from `SP_API_FUND_IDX_RETURN` |
| 4 | **Invested % (Cr.)** | e.g. `72.82` | `fund_holdings` | `SUM(fund_wts)` where sector ≠ CASH |
| 5 | **AUM (Cr.)** | e.g. `6,627` | `fund_holdings` | `SUM(mtm_value) / 10,000,000` for `fund_id` + `effective_date` |
| 6 | **Cash & C.E. % (Cr.)** | e.g. `27.2% (1)` | `fund_holdings`, `level_value_master` | `SUM(fund_wts)` where sector = 'CASH'; count of cash rows in `()` |
| 7 | **Avg. Mcap Fund/Idx** | e.g. `—/—` | `security_dynamic_factors` | `Σ(fund_wts × marketcap) / Σ(fund_wts) / 1000` for fund; same with index_wts for index |
| 8 | **Large Cap (%)** | e.g. `36.1%` | `mapping_security_level` (level_id=5), `level_value_master` | `SUM(fund_wts)` where `size = 'LC'` — imported from `KotakLife` via ISIN |
| 9 | **Mid Cap (%)** | e.g. `11.8%` | `mapping_security_level` (level_id=5), `level_value_master` | `SUM(fund_wts)` where `size = 'MC'` |
| 10 | **Small Cap (%)** | e.g. `2.9%` | `mapping_security_level` (level_id=5), `level_value_master` | `SUM(fund_wts)` where `size = 'SC'` |
| 11 | **Rest (%)** | derived | — | `100 − LC% − MC% − SC%` (frontend calc) |
| 12 | **Mkt. Pos. (%)** | — | — | ⚠ Placeholder — not yet wired |
| 13 | **T/O Ratio** | — | — | ⚠ Placeholder — not yet wired |
| 14 | **C Rating Wtg (%)** | e.g. `0.0%` | `security_rating_mapping` | `SUM(fund_wts)` where `rating = 'C'` |

> **Size data note:** `mapping_security_level` (level_id=5) was empty in `ValueAT_UAT_Nippon`. Data was imported by cross-referencing `isin_number` with `KotakLife.mapping_security_level`. New `level_value_master` entries added: `91=Large Cap`, `92=Mid Cap`, `93=Small Cap` (level_id=5).

---

### 3.3 Grid — Column-wise Data Source

All columns from **`SP_API_LIVE_PORTFOLIO`** (`@fund_id`, `@index_id`, `@run_date`, `@user_id`).

The SP does a **FULL OUTER JOIN** of `fund_holdings` (fund positions) and `index_constituents` (benchmark weights), enriched with security metadata and returns.

#### Visible Columns (default ON)

| Column | SP Output Field | Table(s) | Logic |
|---|---|---|---|
| **Company** | `security_name` | `security_master` | `security_name` (max 32 chars); sector rows come from `level_value_master` (level_id=1) via `mapping_security_level` |
| **Cl. Price** | `close_price` | `security_closeprices` | NSE (`exchange_id=1`) close price for `price_date = eff_date`; falls back to BSE (`exchange_id=2`) if NSE null |
| **Price** | `cmp` | `security_closeprices` | Same as Cl. Price on load; **polled every 15 min** by `SP_API_LIVE_PRICES` and overwritten |
| **Mcap (Cr.)** | `mcap` | `security_dynamic_factors` | `marketcap` column for `effective_date = eff_date` |
| **3M ADTV (Cr.)** | `avg_vol` | `security_dynamic_factors` | `avg_volume` for `effective_date = eff_date` |
| **52 WH Chg. %** | `_52whchg` | — | ⚠ Placeholder — always blank |
| **Pt. Wt. %** | `fund_wts` | `fund_holdings` | `mtm_value / SUM(all mtm_value) × 100` (fund weight %) |
| **Qty.** | `fund_qty` | `fund_holdings` | `quantity`; negative for short positions (`long_short_position = 'S'`) |
| **Rating** | `rating` | `security_rating_mapping` | A / B / C; sample data created for fund 1533 — 73 securities (37A, 32B, 4C) |
| **Value (Cr.)** | `fund_mtm` | `fund_holdings` | `mtm_value / 10,000,000` |
| **1D %** | `ret_1d` | `fund_security_returns` | `portfolio_return × 100` for latest `report_id` linked via `report_references` |
| **1W %** | `ret_5d` | `fund_security_returns`, `report_references` | Geometric compound over last 5 report dates |
| **1M %** | `ret_1m` | `fund_security_returns`, `report_references` | Geometric compound over last 21 report dates |
| **3M %** | `ret_3m` | `fund_security_returns`, `report_references` | Geometric compound over last 63 report dates |
| **6M %** | `ret_6m` | `fund_security_returns`, `report_references` | Geometric compound over last 126 report dates |
| **1Y %** | `ret_1y` | `fund_security_returns`, `report_references` | Geometric compound over last 252 report dates |

#### Hidden Columns (default OFF — toggleable via "Show / hide columns")

| Column | SP Output Field | Table(s) | Logic |
|---|---|---|---|
| **Size** | `size` | `mapping_security_level` (level_id=5), `level_value_master` | `LC` (≥Large Cap) / `MC` (Mid Cap) / `SC` (Small Cap) — imported from KotakLife |
| **ISIN** | `isin_code` | `security_master` | `isin_number` |
| **MTM (Cr.)** | `fund_mtm_chg` | `fund_holdings`, `fund_security_returns` | `mtm_value × ret_1d / 10,000,000` — daily MTM change in Cr. |
| **3M Avg. Vol.** | `_avgvol3m` | — | ⚠ Placeholder |
| **52 WL** | `_52wl` | — | ⚠ Placeholder — suggested: `MIN(closep)` over 52 weeks from `security_closeprices` |
| **52 WH** | `_52wh_abs` | — | ⚠ Placeholder — suggested: `MAX(closep)` over 52 weeks from `security_closeprices` |
| **BM Wt. %** | `index_wts` | `index_constituents` | `weights × 100`; index resolved from `mapping_fund_index` |
| **OW/UW** | Computed | Derived | `fund_wts − index_wts`; green if overweight, red if underweight |
| **YTD %** | `ret_ytd` | `fund_security_returns`, `report_references` | Geometric compound from Jan 1 of `eff_date` year to `eff_date` |

---

### 3.4 Grid Row Types

| Row Type | `is_sector_row` | Source | Display |
|---|---|---|---|
| **Sector header** | `1` | `mapping_security_level` (level_id=1) → `level_value_master.level_value_name` | Bold, background `#ebeff6`, spans full width |
| **Security row** | `0` | `fund_holdings` FULL OUTER JOIN `index_constituents` | Normal row with all column values |

Ordering: `ORDER BY sector, is_sector_row DESC, security_name` — sectors first, then securities alphabetically within each sector.

---

### 3.5 Filters (Filter Row)

| Filter | Effect |
|---|---|
| **Only Fund** (default) | Shows securities with `fund_flag = 'FUND'` + their sector headers |
| **Only Index** | Shows securities with `index_flag` set (in benchmark but not in fund) |
| **No Position** | Shows securities where `fund_qty = 0 or null` |
| **Only Sector** | Shows sector header rows only (no security rows) |
| **No Sector** | Hides all sector header rows |
| **Search box** | Filters by `security_name` or `isin_code` (case-insensitive) |

---

### 3.6 Live Price Polling

| Event | Interval | SP | Table | What Updates |
|---|---|---|---|---|
| After Process | Every **15 min** | `SP_API_LIVE_PRICES` | `security_closeprices` (latest price_date, exchange_id=1) | `cmp` (Price column) overwrites initial close price |
| On each poll | — | — | — | `fund_mtm` recalculated as `fund_qty × cmp / 10,000,000` |
| `Price ticks as on` label | On Process | — | `new Date()` | Shows current datetime of last price fetch |

---

### 3.7 Export

| Button | Output | Library | Data Source |
|---|---|---|---|
| **PDF** | `.pdf` — landscape A3 | jsPDF + jspdf-autotable | All visible grid columns from `filteredRows` |
| **XLS** | `.xlsx` | SheetJS (xlsx) | All visible grid columns from `filteredRows` |

---

## 4. Stored Procedures — Full Reference

| SP | Trigger | Key Tables |
|---|---|---|
| `SP_API_LOGIN` | Login submit | `user_master` |
| `SP_API_FUNDLIST` | Page load | `mapping_fund_user`, `fund_master` |
| `SP_API_INDEXLIST` | Page load | `index_master` |
| `SP_API_FUND_PARAMS` | Fund change | `fund_holdings`, `mapping_fund_index`, `index_master` |
| `SP_API_LIVE_PORTFOLIO` | Process / auto-load | `fund_holdings`, `security_master`, `security_closeprices`, `fund_security_returns`, `report_references`, `index_constituents`, `mapping_security_level`, `level_value_master`, `security_dynamic_factors`, `security_rating_mapping` |
| `SP_API_LIVE_PRICES` | Every 15 min | `security_closeprices`, `fund_holdings` |
| `SP_API_FUND_IDX_RETURN` | After Process | `fund_security_returns`, `report_references` |
| `SP_API_LAYOUTS` | Grid ready | `report_layouts` |
| `SP_API_SAVE_LAYOUT` | "New Layout" | `report_layouts` |
| `SP_API_UPDATE_LAYOUT` | "Update Layout" | `report_layouts` |
| `SP_API_LOG_ACTIVITY` | After Process | `user_access_logs` |

---

## 5. API Endpoints

| Method | URL | SP Called | Description |
|---|---|---|---|
| POST | `/auth/login` | `SP_API_LOGIN` | Returns JWT token |
| GET | `/funds` | `SP_API_FUNDLIST` | Funds for logged-in user |
| GET | `/funds/indices` | `SP_API_INDEXLIST` | All benchmark indices |
| GET | `/funds/:id/params` | `SP_API_FUND_PARAMS` | Max date + default index for a fund |
| GET | `/portfolio` | `SP_API_LIVE_PORTFOLIO` | Full portfolio grid data |
| GET | `/portfolio/live-prices` | `SP_API_LIVE_PRICES` | Live/latest prices for polling |
| GET | `/portfolio/return` | `SP_API_FUND_IDX_RETURN` | 1-day fund and index return |
| GET | `/layouts` | `SP_API_LAYOUTS` | Saved column layouts |
| POST | `/layouts` | `SP_API_SAVE_LAYOUT` | Save new layout |
| PUT | `/layouts/:id` | `SP_API_UPDATE_LAYOUT` | Update existing layout |
| POST | `/activity-log` | `SP_API_LOG_ACTIVITY` | Log page access |

---

## 6. New Tables Created (Migration Additions)

| Table | Purpose | Data |
|---|---|---|
| `security_rating_mapping` | Security credit ratings A/B/C | 73 securities for fund 1533; `(security_id PK, rating VARCHAR(5), from_date DATE)` |

## 7. Data Imported (Migration Additions)

| What | From | To | Method |
|---|---|---|---|
| Market cap sizes (LC/MC/SC) | `KotakLife.mapping_security_level` (level_id=5) | `ValueAT_UAT_Nippon.mapping_security_level` | Cross-referenced by `isin_number` via `security_master`; 461 rows merged |
| `level_value_master` entries | — | `ValueAT_UAT_Nippon.level_value_master` | Added level_value_id 91=Large Cap, 92=Mid Cap, 93=Small Cap (level_id=5) |

---

## 8. Corporate Actions Reference

**Table:** `dbo.corporate_actions` — 12,014 rows covering 2000-10-26 → 2024-12-27.
**Type lookup:** `dbo.corporate_action_master` (also: `stage.mapping_corporate_action_type`)

### Key Columns

| Column | Type | Notes |
|---|---|---|
| `security_id` | INT | FK → `security_master` |
| `effective_date` | DATE | Date the action takes effect |
| `corporate_action_type_id` | INT | 1–14; see table below |
| `coupon_dividend` | DECIMAL | ₹/share for dividends (type 1) or coupons (type 11) |
| `old_ratio` | INT | Ratio denominator for bonus/split (type 2/3/4) |
| `new_ratio` | INT | Ratio numerator — e.g. old=1, new=3 → 1:3 bonus |
| `equity_adjustment_factor` | DECIMAL | Price multiplier applied after corporate action |
| `new_security_id` | INT | Replacement security after merger/ISIN change |

### Action Type Master

| type_id | Action | Old Oracle Source | Grid Column | Status |
|---|---|---|---|---|
| 1 | DIVIDEND | `mtm_affecting_cas_live` | `DIVIDEND_PAYOUT` | ❌ Not migrated — data available |
| 2 | BONUS | `mtm_affecting_cas_live` | `BONUS_SPLIT` | ❌ Not migrated — data available |
| 3 | STOCK SPLITS | `mtm_affecting_cas_live` | `BONUS_SPLIT` | ❌ Not migrated — data available |
| 4 | REVERSE STOCK SPLITS | `mtm_affecting_cas_live` | `BONUS_SPLIT` | ❌ Not migrated |
| 5 | NAME CHANGE | — | Not in grid | — |
| 6 | RIGHTS ISSUE | — | Not in grid | — |
| 7 | MERGER | — | Not in grid | — |
| 8 | DEMERGER | — | Not in grid | — |
| 9 | LISTING | — | Not in grid | — |
| 10 | DELISTING | — | Not in grid | — |
| 11 | COUPON | `mtm_affecting_cas_live` | `DIVIDEND_PAYOUT` | ❌ Not migrated — data available |
| 12 | ISIN CHANGE | — | Not in grid | — |
| 13 | REDEMPTION | — | Not in grid | — |
| 14 | REVALUATION | — | Not in grid | — |

### Mapping: Oracle `mtm_affecting_cas_live` → New MSSQL `corporate_actions`

The old Oracle SP joined `mtm_affecting_cas_live` to show `BONUS_SPLIT` and `DIVIDEND_PAYOUT` indicator columns in the grid. The equivalent in the new system:
- **BONUS_SPLIT**: `corporate_actions WHERE type_id IN (2,3,4)` → display as `old_ratio:new_ratio` string + `effective_date`
- **DIVIDEND_PAYOUT**: `corporate_actions WHERE type_id IN (1,11)` → display `coupon_dividend` (₹) + `effective_date`

Both columns can be added to `SP_API_LIVE_PORTFOLIO` via LEFT JOIN CTEs on `security_id`, filtering to the most recent event within the last 12 months.

---

## 9. Outstanding Placeholders

| Column / Feature | Status | Suggested Implementation |
|---|---|---|
| **52 WH** (absolute) | ⚠ Placeholder | `MAX(closep)` over last 52 weeks from `security_closeprices` |
| **52 WL** (absolute) | ⚠ Placeholder | `MIN(closep)` over last 52 weeks from `security_closeprices` |
| **52 WH Chg. %** | ⚠ Placeholder | `(cmp − 52WH) / 52WH × 100` |
| **3M Avg. Vol.** | ⚠ Placeholder | Average daily volume from `security_dynamic_factors.avg_volume` (currently no data) |
| **Mkt. Pos. (%)** KPI | ⚠ Placeholder | `SUM(fund_wts)` for long positions only |
| **T/O Ratio** KPI | ⚠ Placeholder | Turnover from fund activity / transaction data |
| **BONUS_SPLIT column** | ⚠ Not migrated | `corporate_actions` type 2/3/4 — data available, needs SP + model update |
| **DIVIDEND_PAYOUT column** | ⚠ Not migrated | `corporate_actions` type 1/11 — data available, needs SP + model update |
| **Style Analysis tab** | ⚠ Not built | Second tab — factor/style breakdown |

---

## 10. Project Structure

```
D:\Ataur\Project_NipEQ\
├── api/                        ← Node.js + Express API (TypeScript)
│   ├── src/
│   │   ├── controllers/        ← auth, fund, portfolio, layout, log
│   │   ├── services/           ← sp-executor.ts, auth.ts (JWT/bcrypt)
│   │   ├── datasources/        ← mssql.ts (connection pool)
│   │   ├── middleware/         ← jwt.middleware.ts
│   │   └── index.ts            ← Express entry point
│   ├── scripts/                ← SQL scripts (SP definitions)
│   └── .env                    ← DB credentials + JWT secret
│
├── frontend/                   ← Angular 19 SPA
│   ├── src/app/
│   │   ├── auth/               ← login, guard, JWT interceptor
│   │   ├── portfolio/          ← main screen, service, models
│   │   └── shared/models/      ← PortfolioRow, Fund, Layout interfaces
│   ├── proxy.conf.json         ← /api → localhost:3000
│   └── angular.json            ← AG Grid CSS, port 4200
│
├── database/
│   └── 01_stored_procedures.sql ← All 11 SPs
│
├── NipEQ_Migration_Plan.md     ← This document
├── HOWTO_RUN.md                ← How to start the app
├── setup.bat                   ← npm install (run once)
└── start.bat                   ← Starts API + Frontend
```

---

## 11. Credentials & Config

| Item | Value |
|---|---|
| DB Server | `10.11.3.10:1433` |
| DB Name | `ValueAT_UAT_Nippon` |
| DB User | `da_user` |
| DB Password | `DA@@DA@@123` |
| JWT Secret | `NipEQ_JWT_Secret_2025_Secure` |
| JWT Expiry | `8h` |
| API Port | `3000` |
| Frontend Port | `4200` |
| Login ID | `support@valuefy.com` |
| Password | `NipEQ@2025` |
