# NipEQ — How to Run

## Step 1: Install Node.js (one time only)

1. Open browser → go to: **https://nodejs.org/**
2. Download the **LTS** version (e.g., 20.x or 22.x)
3. Run the installer, keep all defaults, click Next → Finish
4. Open a new Command Prompt and verify:
   ```
   node --version    ← should print v20.x.x or similar
   npm --version     ← should print 10.x.x or similar
   ```

---

## Step 2: Install project dependencies (one time only)

Double-click **`setup.bat`**

This will:
- Install all Node.js packages for the API (`api/`)
- Install all Node.js packages for the frontend (`frontend/`)

It takes 3–5 minutes the first time.

---

## Step 3: Start the application (every time)

Double-click **`start.bat`**

This opens two terminal windows:
- **NipEQ API** — Node.js backend on http://localhost:3000
- **NipEQ Frontend** — Angular app, auto-opens http://localhost:4200

---

## Login

| Field    | Value                 |
|----------|-----------------------|
| Login ID | `support@valuefy.com` |
| Password | `NipEQ@2025`          |

---

## What the app does

- **Login screen** → validates credentials against `user_master` in `ValueAT_UAT_Nippon` (SQL Server)
- **Portfolio screen** → Live portfolio grid for the selected fund, date, and benchmark
  - Fund dropdown shows all funds mapped to the logged-in user
  - Default date: latest available date in the database (`2025-01-01`)
  - Grid shows sector header rows + individual security rows
  - Filters: Only Fund / Only BM / No Position / Only Sectors / Sub-Sector grouping
  - Columns: Security, ISIN, Qty, Price, 1D%–YTD% returns, Fund MTM, Pt. Wt.%, BM Wt.%, AUM, MCap, etc.
  - Show/hide individual columns via the column panel
  - Save and load named column layouts (stored in `layout_master`)
  - Export to XLS / PDF

---

## Project Structure

```
D:\Ataur\Project_NipEQ\
├── api/                      ← Node.js + Express API (TypeScript)
│   ├── src/
│   │   ├── controllers/      ← auth, fund, portfolio, layout, log
│   │   ├── services/         ← sp-executor (DB calls), auth (JWT + bcrypt)
│   │   ├── datasources/      ← mssql.ts (SQL Server connection pool)
│   │   ├── middleware/        ← jwt.middleware.ts
│   │   └── index.ts          ← Express app entry point
│   ├── .env                  ← DB credentials + JWT secret (do not commit)
│   └── package.json
│
├── frontend/                 ← Angular 21 SPA (standalone components)
│   ├── src/app/
│   │   ├── auth/             ← login component, route guard, JWT interceptor
│   │   ├── portfolio/        ← main portfolio grid screen + service
│   │   └── shared/
│   │       ├── models/       ← TypeScript interfaces (PortfolioRow, Fund, etc.)
│   │       ├── services/     ← api.service.ts (base HTTP wrapper)
│   │       └── mock/         ← mock-data.ts (used during development)
│   ├── proxy.conf.json       ← proxies /api → localhost:3000
│   └── package.json
│
├── _archive/                 ← Legacy reference files (macros, old docs, SQL scripts)
│
├── HOWTO_RUN.md              ← This file
├── setup.bat                 ← Run once to install dependencies
└── start.bat                 ← Run every time to start the app
```

---

## Database

| Setting  | Value                     |
|----------|---------------------------|
| Server   | `10.11.3.10`              |
| Database | `ValueAT_UAT_Nippon`      |
| User     | `da_user`                 |
| Port     | `1433`                    |

Connection config is in `api/.env`. The database is pre-populated — no setup needed.

---

## API Endpoints (for reference)

| Method | URL | Description |
|--------|-----|-------------|
| POST | `/auth/login` | Login, returns JWT |
| GET | `/funds` | Funds mapped to the logged-in user |
| GET | `/funds/:id/params` | Max available date + default index for a fund |
| GET | `/funds/indices` | All active benchmark indices |
| GET | `/portfolio?fundId=&indexId=&runDate=` | Portfolio grid data |
| GET | `/portfolio/return?fundId=&indexId=&effDate=` | 1D fund + index return |
| GET | `/portfolio/live-prices?fundId=&runDate=` | Live intraday prices (DION) |
| GET | `/layouts?widgetId=` | Saved column layouts for the user |
| POST | `/layouts` | Save a new layout |
| PUT | `/layouts/:id` | Update an existing layout |
| POST | `/activity-log` | Log a page visit |
