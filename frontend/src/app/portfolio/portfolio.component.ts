import { Component, OnInit, OnDestroy, HostBinding } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';

import { AgGridModule } from 'ag-grid-angular';
import {
  ColDef, GridApi, GridReadyEvent, RowClassParams,
  ModuleRegistry, ClientSideRowModelModule, CsvExportModule,
} from 'ag-grid-community';

ModuleRegistry.registerModules([ClientSideRowModelModule, CsvExportModule]);

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';

import { PortfolioService } from './portfolio.service';
import { Fund, Index } from '../shared/models/fund.model';
import { PortfolioRow } from '../shared/models/portfolio-row.model';
import { Layout } from '../shared/models/layout.model';
import { StyleAnalysisComponent } from './style-analysis/style-analysis.component';

interface Stats {
  fundRet: number; alpha: number; indexRet: number;
  investedPct: number; investedCr: number; aum: number; cashPct: number; cashCr: number; cashCount: number;
  wtdMcapFund: number; wtdMcapIndex: number;
  largeCap: number; midCap: number; smallCap: number; rest: number;
  mktPos: number; toRatio: number; cRatingWtg: number; dRatingWtg: number;
}

interface ColVis { field: string; headerName: string; visible: boolean; }

@Component({
  selector: 'app-portfolio',
  standalone: true,
  imports: [CommonModule, FormsModule, MatSnackBarModule, AgGridModule, StyleAnalysisComponent],
  templateUrl: './portfolio.component.html',
  styleUrls: ['./portfolio.component.scss'],
})
export class PortfolioComponent implements OnInit, OnDestroy {
  funds: Fund[]    = [];
  indices: Index[] = [];
  allRows: PortfolioRow[]      = [];
  filteredRows: PortfolioRow[] = [];
  layouts: Layout[]            = [];

  selectedFundId   = 0;
  selectedIndexId  = -1;
  selectedDate     = '';
  readonly todayStr = new Date().toISOString().substring(0, 10);
  selectedFundName = '';
  private _dataDate = '';

  selectedLayoutId: number | null = null;
  newLayoutName = '';
  searchText    = '';

  // ── Filters (all independent booleans — multiple can be active simultaneously)
  onlyFund   = true;   // default: show only fund holdings
  onlyIndex  = false;
  noPosition = false;
  onlySector = false;
  noSector   = false;
  subSector  = false;

  /** No Position ticked   → clear Only Fund (contradictory: can't show no-position AND fund-only rows).
   *  No Position unticked → restore Only Fund to true (return to the default meaningful state).
   *  Only Index is intentionally left untouched in both directions. */
  onNoPositionChange(): void {
    if (this.noPosition) {
      this.onlyFund = false;
    } else {
      this.onlyFund = true;   // restore default when noPosition is turned off
    }
    this.onFilterChange();
  }

  /** No Sector ticked → clear Only Sector + Sub Sector (mutual exclusion). */
  onNoSectorChange(): void {
    if (this.noSector) {
      this.onlySector = false;
      this.subSector  = false;
    }
    this.onFilterChange();
  }

  /** Only Sector / Sub Sector changes:
   *  - Either ticked → clear No Sector
   *  - Only Sector and Sub Sector are mutually exclusive with each other
   *    (onlySector = sector rows only; subSector = inject sub-headers between securities —
   *     both together would make subSector a silent no-op per applyFilters guard) */
  onOnlySectorChange(): void {
    if (this.onlySector) {
      this.noSector  = false;
      this.subSector = false;   // mutually exclusive
    }
    this.onFilterChange();
  }

  onSubSectorChange(): void {
    if (this.subSector) {
      this.noSector   = false;
      this.onlySector = false;  // mutually exclusive
    }
    this.onFilterChange();
  }

  activeTab: 'fund' | 'style' = 'fund';

  loading       = false;
  priceTickDate = '';
  showColPanel  = false;
  colVis: ColVis[] = [];
  private colDefaults: Map<string, boolean> = new Map();

  // Custom fund dropdown
  fundDropdownOpen = false;
  fundSearch       = '';
  get filteredFunds(): Fund[] {
    const q = this.fundSearch.toLowerCase().trim();
    return q ? this.funds.filter(f => f.fund_name.toLowerCase().includes(q)) : this.funds;
  }
  selectFund(f: Fund): void {
    this.fundDropdownOpen = false;
    this.fundSearch = '';
    this.onFundChange(f.fund_id);
  }

  // Custom index dropdown
  indexDropdownOpen = false;
  indexSearch       = '';
  get selectedIndexName(): string {
    return this.indices.find(i => i.index_id === this.selectedIndexId)?.index_name ?? 'Select Index';
  }
  get filteredIndices(): Index[] {
    const q = this.indexSearch.toLowerCase().trim();
    return q ? this.indices.filter(i => i.index_name.toLowerCase().includes(q)) : this.indices;
  }
  selectIndex(i: Index): void {
    this.selectedIndexId = i.index_id;
    this.indexDropdownOpen = false;
    this.indexSearch = '';
  }

  // Custom layout dropdown
  layoutDropdownOpen = false;
  get selectedLayoutName(): string {
    if (!this.selectedLayoutId) return 'Default';
    return this.layouts.find(l => l.layout_id === this.selectedLayoutId)?.layout_name ?? 'Default';
  }
  selectLayout(id: number | null): void {
    this.selectedLayoutId = id;
    this.layoutDropdownOpen = false;
    if (id) {
      const layout = this.layouts.find(l => l.layout_id === id);
      if (layout) this.applyLayout(layout);
    }
  }

  // Skeleton loader config
  readonly skColWidths = [220, 75, 95, 100, 90, 80, 95, 65, 95, 62, 62, 62, 62, 62];
  readonly skRows = this.buildSkRows();
  private buildSkRows() {
    const rows: { isSector: boolean; fills: number[] }[] = [];
    const rand = (min: number, max: number) => Math.floor(Math.random() * (max - min + 1)) + min;
    const cols = 14;
    // Pattern: sector, 4-5 securities, repeat x5
    for (let g = 0; g < 6; g++) {
      rows.push({ isSector: true, fills: [] });
      const count = rand(3, 5);
      for (let r = 0; r < count; r++) {
        rows.push({ isSector: false, fills: Array.from({ length: cols }, (_, i) => i === 0 ? rand(55, 85) : rand(40, 80)) });
      }
    }
    return rows;
  }

  @HostBinding('class.dark') darkMode = false;
  toggleDarkMode(): void {
    this.darkMode = !this.darkMode;
    // Persist preference
    localStorage.setItem('nipeq_dark', this.darkMode ? '1' : '0');
  }

  stats: Stats = {
    fundRet: 0, alpha: 0, indexRet: 0,
    investedPct: 0, investedCr: 0, aum: 0, cashPct: 0, cashCr: 0, cashCount: 0,
    wtdMcapFund: 0, wtdMcapIndex: 0,
    largeCap: 0, midCap: 0, smallCap: 0, rest: 0,
    mktPos: 0, toRatio: 0, cRatingWtg: 0, dRatingWtg: 0,
  };

  private gridApi!: GridApi;
  private liveInterval: any;

  // ── Column Definitions ──────────────────────────────────────────
  // hide:true = hidden by default; columns retain position when toggled
  // flex weights: relative proportions — grid always fills 100% width.
  // minWidth prevents columns from being squished too small.
  // Pinned 'Company' column has fixed width; all others use flex.
  columnDefs: ColDef[] = [
    {
      field: 'security_name', headerName: 'Company',
      width: 220, pinned: 'left', suppressSizeToFit: true,
      cellRenderer: (p: any) => {
        if (!p.value) return '';
        const isSector    = p.data?.is_sector_row === 1;
        const isSubSector = p.data?.is_sector_row === 2;
        if (isSector)    return `<span class="sector-label" title="${p.value}">${p.value}</span>`;
        if (isSubSector) return `<span class="subsector-label" title="${p.value}">${p.value}</span>`;
        return `<span title="${p.value}">${String(p.value).substring(0, 32)}</span>`;
      },
    },
    { field: 'size',        headerName: 'Size',           minWidth: 48,  flex: 1,  hide: true },
    { field: 'isin_code',   headerName: 'ISIN',           minWidth: 110, flex: 2,  hide: true },
    { field: 'close_price', headerName: 'Cl. Price',      minWidth: 70,  flex: 1.5, type: 'numericColumn', hide: true, valueFormatter: p => this.fmtNum(p.value, 2) },
    { field: 'cmp',         headerName: 'Price',          minWidth: 65,  flex: 1.5, type: 'numericColumn', valueFormatter: p => this.fmtNum(p.value, 2) },
    { field: 'fund_mtm_chg',headerName: 'MTM Chg. (Cr.)', minWidth: 85,  flex: 1.5, type: 'numericColumn', valueFormatter: p => p.value == null ? '' : this.fmtNum(p.value / 1e7, 2), hide: true },
    { field: 'mcap',        headerName: 'Mcap (Cr.)',     minWidth: 80,  flex: 2,   type: 'numericColumn', valueFormatter: p => this.fmtNum(p.value, 0, true) },
    { field: 'avg_vol',     headerName: '3M ADTV (Cr.)', minWidth: 85,  flex: 2,   type: 'numericColumn', valueFormatter: p => this.fmtNum(p.value, 0, true) },
    { field: '_avgvol3m',   headerName: '3M Avg. Vol.',  minWidth: 85,  flex: 2,   type: 'numericColumn', valueGetter: () => null, valueFormatter: () => '', hide: true },
    { field: '_52wl',       headerName: '52 WL',          minWidth: 65,  flex: 1.5, type: 'numericColumn', valueGetter: () => null, valueFormatter: () => '', hide: true },
    { field: '_52wh_abs',   headerName: '52 WH',          minWidth: 65,  flex: 1.5, type: 'numericColumn', valueGetter: () => null, valueFormatter: () => '', hide: true },
    { field: '_52whchg',    headerName: '52 WH Chg.%',   minWidth: 75,  flex: 1.5, type: 'numericColumn', valueGetter: () => null, valueFormatter: () => '' },
    { field: 'fund_wts',    headerName: 'Pt. Wt. %',     minWidth: 65,  flex: 1.5, type: 'numericColumn', valueFormatter: p => this.fmtNum(p.value, 2) },
    { field: 'index_wts',   headerName: 'BM Wt. %',      minWidth: 65,  flex: 1.5, type: 'numericColumn', valueFormatter: p => this.fmtNum(p.value, 2), hide: true },
    {
      colId: 'owuw', headerName: 'OW/UW',                minWidth: 60,  flex: 1.2, type: 'numericColumn', hide: true,
      valueGetter: (p: any) => {
        if ((p.data?.is_sector_row ?? 0) >= 1) return null;
        return parseFloat((Number(p.data?.fund_wts ?? 0) - Number(p.data?.index_wts ?? 0)).toFixed(2));
      },
      valueFormatter: (p: any) => p.value != null ? p.value.toFixed(1) : '',
      cellStyle: (p: any): any => {
        if (p.value == null) return {};
        return { color: p.value > 0 ? '#1a8a3a' : p.value < 0 ? '#d32f2f' : '#555' };
      },
    },
    { field: 'fund_qty',    headerName: 'Qty.',           minWidth: 75,  flex: 1.8, type: 'numericColumn', valueFormatter: p => this.fmtNum(p.value, 0, true) },
    { field: 'rating',      headerName: 'Rating',         minWidth: 55,  flex: 1 },
    { field: 'fund_mtm',    headerName: 'Value (Cr.)',    minWidth: 80,  flex: 1.8, type: 'numericColumn', valueFormatter: p => p.value == null ? '' : this.fmtNum(p.value / 1e7, 2) },
    ...this.retCol('ret_1d',  '1D %'),
    ...this.retCol('ret_5d',  '1W %'),
    ...this.retCol('ret_1m',  '1M %'),
    ...this.retCol('ret_3m',  '3M %'),
    ...this.retCol('ret_6m',  '6M %'),
    ...this.retCol('ret_1y',  '1Y %'),
    ...this.retCol('ret_ytd', 'YTD %', true),
  ];

  defaultColDef: ColDef = { sortable: true, resizable: true, filter: false, suppressMovable: false };

  constructor(
    private svc: PortfolioService,
    private snack: MatSnackBar,
  ) {}

  ngOnInit(): void {
    this.darkMode = localStorage.getItem('nipeq_dark') === '1';

    // Build col-visibility list from column defs (skip the pinned Company column)
    this.colVis = this.columnDefs
      .filter(c => c.field !== 'security_name')
      .map(c => ({
        field: (c as any).colId || c.field || '',
        headerName: c.headerName || c.field || '',
        visible: !c.hide,
      }));
    // Store defaults for reset
    this.colDefaults = new Map(this.colVis.map(c => [c.field, c.visible]));

    // Set today's date in picker
    this.selectedDate = new Date().toISOString().substring(0, 10);

    this.svc.getIndices().subscribe(idx => {
      this.indices = [{ index_id: -1, index_name: 'No Benchmark', index_short_name: '' }, ...idx];
    });

    this.svc.getFunds().subscribe(funds => {
      this.funds = funds;
      const def  = funds.find(f => f.is_default_fund) || funds[0];
      if (def) {
        this.selectedFundId   = def.fund_id;
        this.selectedFundName = def.fund_name;
        // Load params then auto-process on first open
        this.svc.getFundParams(def.fund_id).subscribe(p => {
          if (p) {
            this._dataDate       = String(p.effective_date).substring(0, 10);
            this.selectedIndexId = p.index_id ?? -1;
          }
          this.process(true);
        });
      }
    });
  }

  ngOnDestroy(): void {
    if (this.liveInterval) clearInterval(this.liveInterval);
  }

  onGridReady(evt: GridReadyEvent): void {
    this.gridApi = evt.api;
    this.loadLayouts();
  }

  // ── Called when user changes fund in dropdown (no auto-reload)
  onFundChange(fundId: number): void {
    this.selectedFundId   = fundId;
    const f = this.funds.find(x => x.fund_id === fundId);
    this.selectedFundName = f?.fund_name || '';
    this.svc.getFundParams(fundId).subscribe(p => {
      if (p) {
        this._dataDate       = String(p.effective_date).substring(0, 10);
        this.selectedIndexId = p.index_id ?? -1;
      }
    });
  }

  // ── Process button (or auto on first load)
  process(isInitial = false): void {
    if (!this.selectedFundId) return;
    const today   = new Date().toISOString().substring(0, 10);
    const runDate = (this.selectedDate && this.selectedDate !== today)
      ? this.selectedDate
      : (this._dataDate || this.selectedDate);
    if (!runDate) return;

    this.loading = true;
    this.svc.getPortfolio(this.selectedFundId, this.selectedIndexId, runDate).subscribe({
      next: rows => {
        this.allRows      = rows;
        this.priceTickDate = new Date().toISOString().substring(0, 10);
        this.computeStats(rows);
        this.applyFilters();
        this.loading = false;
        this.svc.logActivity(this.selectedFundId, runDate).subscribe();

        this.svc.getFundReturn(this.selectedFundId, this.selectedIndexId, runDate).subscribe(r => {
          if (r) {
            this.stats.fundRet  = parseFloat((Number(r['fund_1d'])  * 100).toFixed(2));
            this.stats.indexRet = parseFloat((Number(r['index_1d']) * 100).toFixed(2));
            this.stats.alpha    = parseFloat((this.stats.fundRet - this.stats.indexRet).toFixed(2));
          }
        });

        // Start live price polling every 3 minutes
        if (this.liveInterval) clearInterval(this.liveInterval);
        this.liveInterval = setInterval(() => this.refreshLivePrices(runDate), 3 * 60 * 1000);
      },
      error: () => {
        this.loading = false;
        this.snack.open('Failed to load portfolio data', 'Close', { duration: 4000 });
      },
    });
  }

  // ── Refresh live prices (CMP × Qty = Value) every 3 min
  private refreshLivePrices(runDate: string): void {
    this.svc.getLivePrices(this.selectedFundId, this.selectedIndexId, runDate).subscribe(prices => {
      if (!prices?.length) return;
      const priceMap = new Map<string, number>(prices.map((p: any) => [p.isin_code || p.security_name, Number(p.live_price ?? p.cmp ?? 0)]));
      this.allRows = this.allRows.map(r => {
        const lp = priceMap.get(r.isin_code || '') ?? priceMap.get(r.security_name || '');
        if (lp && lp > 0 && r.is_sector_row === 0) {
          const newMtm = parseFloat(((Number(r.fund_qty ?? 0) * lp) / 1e7).toFixed(2)); // Cr.
          return { ...r, cmp: lp, fund_mtm: newMtm };
        }
        return r;
      });
      this.applyFilters();
    });
  }

  // ── Filters
  applyFilters(): void {
    // Shared aggregate builder — always reflects currently VISIBLE security rows
    // so sector/sub-sector headers stay consistent with what's displayed below them.
    // For No Position (fund_wts=0), we fall back to index_wts for weighting returns.
    type Agg = {
      fundWts: number; indexWts: number; fundMtm: number;
      r1dS: number; r5dS: number; r1mS: number; r3mS: number;
      r6mS: number; r1yS: number; rYtdS: number; wtSum: number;
    };
    const blankAgg = (): Agg => ({
      fundWts: 0, indexWts: 0, fundMtm: 0,
      r1dS: 0, r5dS: 0, r1mS: 0, r3mS: 0,
      r6mS: 0, r1yS: 0, rYtdS: 0, wtSum: 0,
    });
    const accumulate = (a: Agg, r: PortfolioRow) => {
      a.fundWts  += Number(r.fund_wts  ?? 0);
      a.indexWts += Number(r.index_wts ?? 0);
      a.fundMtm  += Number(r.fund_mtm  ?? 0);
      // Weight by fund_wts if available, else fall back to index_wts (No Position case)
      const wt = Number(r.fund_wts ?? 0) || Number(r.index_wts ?? 0);
      if (wt > 0) {
        a.wtSum  += wt;
        a.r1dS   += wt * Number(r.ret_1d  ?? 0);
        a.r5dS   += wt * Number(r.ret_5d  ?? 0);
        a.r1mS   += wt * Number(r.ret_1m  ?? 0);
        a.r3mS   += wt * Number(r.ret_3m  ?? 0);
        a.r6mS   += wt * Number(r.ret_6m  ?? 0);
        a.r1yS   += wt * Number(r.ret_1y  ?? 0);
        a.rYtdS  += wt * Number(r.ret_ytd ?? 0);
      }
    };
    const enrich = (base: PortfolioRow, a: Agg): PortfolioRow => {
      const w = a.wtSum;
      const wav = (s: number) => w > 0 ? +(s / w).toFixed(2) : null;
      return {
        ...base,
        fund_wts:  a.fundWts  || null,
        index_wts: a.indexWts || null,
        fund_mtm:  a.fundMtm  || null,
        ret_1d:  wav(a.r1dS),  ret_5d:  wav(a.r5dS),
        ret_1m:  wav(a.r1mS),  ret_3m:  wav(a.r3mS),
        ret_6m:  wav(a.r6mS),  ret_1y:  wav(a.r1yS),
        ret_ytd: wav(a.rYtdS),
      } as PortfolioRow;
    };

    // ── Step 1: filter security rows only (no headers yet) ───────────────
    let secRows = this.allRows.filter(r => r.is_sector_row === 0);

    if (this.onlyFund)   secRows = secRows.filter(r => r.fund_flag === 'FUND');
    if (this.onlyIndex)  secRows = secRows.filter(r => r.index_wts != null && Number(r.index_wts) > 0);
    if (this.noPosition) secRows = secRows.filter(r => !r.fund_wts || Number(r.fund_wts) === 0);

    if (this.searchText.trim()) {
      const q = this.searchText.toLowerCase();
      secRows = secRows.filter(r =>
        (r.security_name || '').toLowerCase().includes(q) ||
        (r.isin_code || '').toLowerCase().includes(q)
      );
    }

    // ── Step 2: compute sector aggregates from filtered security rows ─────
    const aggMap = new Map<string, Agg>();
    secRows.forEach(r => {
      if (!aggMap.has(r.sector)) aggMap.set(r.sector, blankAgg());
      accumulate(aggMap.get(r.sector)!, r);
    });

    // ── Step 3: build row list — only sectors that have visible securities ─
    const sectorHeaders = new Map(
      this.allRows.filter(r => r.is_sector_row === 1).map(r => [r.sector, r])
    );

    let rows: PortfolioRow[];

    if (this.noSector) {
      // No sector headers at all — just securities
      rows = secRows;
    } else if (this.onlySector) {
      // Only enriched sector headers for sectors that have visible securities
      rows = [...aggMap.keys()].map(sec => {
        const hdr = sectorHeaders.get(sec);
        return hdr ? enrich(hdr, aggMap.get(sec)!) : null;
      }).filter(Boolean) as PortfolioRow[];
    } else {
      // Interleave enriched sector headers + their filtered securities
      // Maintain original sector order from allRows
      const orderedSectors = this.allRows
        .filter(r => r.is_sector_row === 1)
        .map(r => r.sector)
        .filter(s => aggMap.has(s));

      rows = [];
      orderedSectors.forEach(sec => {
        const hdr = sectorHeaders.get(sec);
        if (hdr) rows.push(enrich(hdr, aggMap.get(sec)!));
        rows.push(...secRows.filter(r => r.sector === sec));
      });
    }

    // ── Step 4: inject sub-sector headers when enabled ────────────────────
    if (this.subSector && !this.onlySector && !this.noSector) {
      // Compute sub-sector aggregates from the same filtered security rows
      const subAggMap = new Map<string, Agg>();
      secRows.forEach(r => {
        const key = `${r.sector}|||${r.sub_sector || 'Other'}`;
        if (!subAggMap.has(key)) subAggMap.set(key, blankAgg());
        accumulate(subAggMap.get(key)!, r);
      });

      const expanded: PortfolioRow[] = [];
      let currentSector = '';
      let currentSubSector = '';
      for (const row of rows) {
        if (row.is_sector_row === 1) {
          currentSector = row.sector;
          currentSubSector = '';
          expanded.push(row);
          continue;
        }
        const sub = row.sub_sector || 'Other';
        if (sub !== currentSubSector) {
          currentSubSector = sub;
          const key = `${currentSector}|||${sub}`;
          const a = subAggMap.get(key) ?? blankAgg();
          const baseSubRow = {
            is_sector_row: 2, sector: currentSector, sub_sector: sub,
            security_name: sub, isin_code: '', index_flag: null, fund_flag: null,
            fund_qty: null, cmp: null, mcap: null, close_price: null,
            avg_vol: null, size: null, rating: null, fund_mtm_chg: null, fund_aum: null,
            fund_wts: null, index_wts: null, fund_mtm: null,
            ret_1d: null, ret_5d: null, ret_1m: null, ret_3m: null,
            ret_6m: null, ret_1y: null, ret_ytd: null,
          } as PortfolioRow;
          expanded.push(enrich(baseSubRow, a));
        }
        expanded.push(row);
      }
      rows = expanded;
    }

    this.filteredRows = rows;
  }

  onFilterChange(): void { this.applyFilters(); }
  onSearch(): void       { this.applyFilters(); }

  // ── Stats
  computeStats(rows: PortfolioRow[]): void {
    const sec = rows.filter(r => r.is_sector_row === 0);
    this.stats.aum = sec.length ? Number(sec[0].fund_aum ?? 0) : 0;

    const cashRows  = sec.filter(r => (r.sector || '').toUpperCase().includes('CASH'));
    this.stats.cashCount = cashRows.length;

    // Invested = sum of fund_wts for non-cash securities that are in the fund
    const eqRows = sec.filter(r => !(r.sector || '').toUpperCase().includes('CASH') && Number(r.fund_wts ?? 0) > 0);
    this.stats.investedPct = +eqRows.reduce((s, r) => s + Number(r.fund_wts ?? 0), 0).toFixed(2);

    // Cash = complement of invested (basic finance: invested + cash = 100% of AUM)
    const aum = this.stats.aum;
    this.stats.investedCr = Math.round(this.stats.investedPct / 100 * aum);
    this.stats.cashPct    = +(100 - this.stats.investedPct).toFixed(2);
    this.stats.cashCr     = aum - this.stats.investedCr;

    this.stats.largeCap = sec.filter(r => r.size === 'LC').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
    this.stats.midCap   = sec.filter(r => r.size === 'MC').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
    this.stats.smallCap = sec.filter(r => r.size === 'SC').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
    this.stats.rest     = Math.max(0, 100 - this.stats.largeCap - this.stats.midCap - this.stats.smallCap);

    let wN = 0, wD = 0, wiN = 0, wiD = 0;
    sec.forEach(r => {
      const m = Number(r.mcap ?? 0);
      const fw = Number(r.fund_wts ?? 0); const iw = Number(r.index_wts ?? 0);
      if (m > 0 && fw > 0) { wN  += fw * m; wD  += fw; }
      if (m > 0 && iw > 0) { wiN += iw * m; wiD += iw; }
    });
    this.stats.wtdMcapFund  = wD  > 0 ? wN  / wD  / 1000 : 0;
    this.stats.wtdMcapIndex = wiD > 0 ? wiN / wiD / 1000 : 0;

    this.stats.cRatingWtg = sec.filter(r => r.rating === 'C').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
    this.stats.dRatingWtg = sec.filter(r => r.rating === 'D').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
  }

  getRowClass = (params: RowClassParams): string => {
    if (params.data?.is_sector_row === 1) return 'sector-row';
    if (params.data?.is_sector_row === 2) return 'subsector-row';
    return '';
  };

  // After AG Grid sorts, re-anchor sector headers above their own securities.
  // IMPORTANT: securities from the same sector can become interleaved after sort
  // (e.g. HDFC #1, RELIANCE #2, ICICI #3 — ICICI would appear under OIL without this fix).
  // Solution: collect headers, group securities by sector (preserving sorted order within
  // each sector), then output sector-by-sector ordered by each sector's best-ranked row.
  postSortRows = (params: { nodes: any[] }): void => {
    const nodes = params.nodes;

    // Collect sector headers (is_sector_row=1)
    const sectorHeaderMap = new Map<string, any>();
    nodes.forEach(n => {
      if (n.data?.is_sector_row === 1) sectorHeaderMap.set(n.data.sector, n);
    });

    // If sub-sector mode: also collect sub-sector headers (is_sector_row=2)
    const hasSubSector = nodes.some(n => n.data?.is_sector_row === 2);

    if (!hasSubSector) {
      // If there are no security rows (e.g. Only Sector mode), nothing to reorder
      const hasSecurities = nodes.some(n => n.data?.is_sector_row === 0);
      if (!hasSecurities) return;

      // Group securities by sector, sector order = first appearance in sorted list
      const sectorOrder: string[] = [];
      const sectorRowsMap = new Map<string, any[]>();
      nodes.forEach(n => {
        if (n.data?.is_sector_row === 1) return;
        const sec: string = n.data?.sector ?? '';
        if (!sectorRowsMap.has(sec)) {
          sectorRowsMap.set(sec, []);
          sectorOrder.push(sec);
        }
        sectorRowsMap.get(sec)!.push(n);
      });
      const result: any[] = [];
      sectorOrder.forEach(sec => {
        const hdr = sectorHeaderMap.get(sec);
        if (hdr) result.push(hdr);
        result.push(...sectorRowsMap.get(sec)!);
      });
      nodes.splice(0, nodes.length, ...result);
      return;
    }

    // Sub-sector mode: group by sector → sub-sector → securities
    // Collect sub-sector headers: key = "sector|||subsector"
    const subSectorHeaderMap = new Map<string, any>();
    nodes.forEach(n => {
      if (n.data?.is_sector_row === 2) {
        const key = `${n.data.sector}|||${n.data.sub_sector}`;
        subSectorHeaderMap.set(key, n);
      }
    });

    // Group security nodes (is_sector_row=0) by sector then sub_sector
    const sectorOrder: string[] = [];
    const sectorMap = new Map<string, { subOrder: string[]; subMap: Map<string, any[]> }>();

    nodes.forEach(n => {
      if (n.data?.is_sector_row !== 0) return;
      const sec: string = n.data?.sector ?? '';
      const sub: string = n.data?.sub_sector || 'Other';
      if (!sectorMap.has(sec)) {
        sectorMap.set(sec, { subOrder: [], subMap: new Map() });
        sectorOrder.push(sec);
      }
      const sData = sectorMap.get(sec)!;
      if (!sData.subMap.has(sub)) {
        sData.subMap.set(sub, []);
        sData.subOrder.push(sub);
      }
      sData.subMap.get(sub)!.push(n);
    });

    const result: any[] = [];
    sectorOrder.forEach(sec => {
      const sHdr = sectorHeaderMap.get(sec);
      if (sHdr) result.push(sHdr);
      const sData = sectorMap.get(sec)!;
      sData.subOrder.forEach(sub => {
        const subKey = `${sec}|||${sub}`;
        const subHdr = subSectorHeaderMap.get(subKey);
        if (subHdr) result.push(subHdr);
        result.push(...sData.subMap.get(sub)!);
      });
    });

    nodes.splice(0, nodes.length, ...result);
  };

  // ── Layout
  loadLayouts(): void {
    this.svc.getLayouts(19).subscribe(ls => {
      this.layouts = ls;
      const def = ls.find(l => l.is_default_layout);
      if (def) this.applyLayout(def);
    });
  }

  onLayoutSelect(id: number): void {
    const l = this.layouts.find(x => x.layout_id === id);
    if (l) this.applyLayout(l);
  }

  applyLayout(layout: Layout): void {
    if (!this.gridApi || !layout.layout_state) return;
    try {
      this.gridApi.applyColumnState({ state: JSON.parse(layout.layout_state), applyOrder: true });
      this.selectedLayoutId = layout.layout_id;
    } catch {}
  }

  saveNewLayout(): void {
    if (!this.newLayoutName.trim()) {
      this.snack.open('Enter a layout name first', '', { duration: 2000 });
      return;
    }
    const state = JSON.stringify(this.gridApi.getColumnState());
    this.svc.saveLayout({ widgetId: 19, layoutName: this.newLayoutName.trim(), layoutString: state, layoutState: state, isDefault: 0 }).subscribe({
      next: () => { this.snack.open('Layout saved', '', { duration: 2000 }); this.newLayoutName = ''; this.loadLayouts(); },
    });
  }

  updateCurrentLayout(): void {
    if (!this.selectedLayoutId) { this.snack.open('Select a layout first', '', { duration: 2000 }); return; }
    const state = JSON.stringify(this.gridApi.getColumnState());
    this.svc.updateLayout(this.selectedLayoutId, { layoutString: state, layoutState: state, isDefault: 0 }).subscribe({
      next: () => this.snack.open('Layout updated', '', { duration: 2000 }),
    });
  }

  toggleColumn(colKey: string, visible: boolean): void {
    if (colKey) this.gridApi.setColumnsVisible([colKey], visible);
  }

  resetColumns(): void {
    this.colVis.forEach(col => {
      const def = this.colDefaults.get(col.field) ?? false;
      col.visible = def;
      if (this.gridApi) this.gridApi.setColumnsVisible([col.field], def);
    });
  }

  // ── Formatters
  fmt1(v: number): string { return (v ?? 0).toFixed(1); }
  fmtK(v: number): string {
    if (!v || v === 0) return '—';
    return v >= 1 ? v.toFixed(0) + 'k' : (v * 1000).toFixed(0);
  }
  fmtNum(v: any, dec = 2, skipZero = false): string {
    const n = Number(v);
    if (v == null || isNaN(n)) return '';
    if (skipZero && n === 0) return '';
    return dec === 0
      ? n.toLocaleString('en-IN', { maximumFractionDigits: 0 })
      : n.toFixed(dec);
  }

  private retCol(field: string, header: string, hide = false): ColDef[] {
    return [{
      field, headerName: header, minWidth: 55, flex: 1.2, type: 'numericColumn', hide,
      valueFormatter: (p: any) => {
        if (p.value == null) return '';
        return Number(p.value).toFixed(2);
      },
      cellStyle: (p: any): any => {
        if (p.value == null) return {};
        const v = Number(p.value);
        if (this.darkMode) {
          return { color: v > 0 ? '#34d399' : v < 0 ? '#f87171' : '#6b7280' };
        }
        return { color: v > 0 ? '#16a34a' : v < 0 ? '#dc2626' : '#6b7280' };
      },
    }];
  }

  // ── Export as PDF
  exportPdf(): void {
    const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'a3' });
    const cols = this.gridApi.getAllDisplayedColumns()
      .map(c => c.getColDef().headerName || c.getColId())
      .filter(h => h !== 'Company');
    const companyHeader = ['Company', ...cols];

    const rows = this.filteredRows.map(row => {
      const vals: any[] = [row.security_name || ''];
      this.gridApi.getAllDisplayedColumns().forEach(col => {
        const hdr = col.getColDef().headerName;
        if (hdr === 'Company') return;
        const val = this.gridApi.getValue(col, { data: row } as any);
        vals.push(val ?? '');
      });
      return vals;
    });

    doc.setFontSize(11);
    doc.text(`Live Portfolio — ${this.selectedFundName}`, 20, 30);
    doc.setFontSize(8);
    doc.text(`Price ticks as on: ${this.priceTickDate}`, 20, 44);

    autoTable(doc, {
      head: [companyHeader],
      body: rows,
      startY: 55,
      styles: { fontSize: 7, cellPadding: 2 },
      headStyles: { fillColor: [28, 43, 74], textColor: 255, fontStyle: 'bold' },
    });

    doc.save(`portfolio_${this.selectedFundName}_${this.priceTickDate}.pdf`);
  }

  // ── Export as Excel
  exportXls(): void {
    const cols = this.gridApi.getAllDisplayedColumns();
    const headers = cols.map(c => c.getColDef().headerName || c.getColId());

    const data = this.filteredRows.map(row => {
      const obj: any = {};
      cols.forEach(col => {
        const hdr = col.getColDef().headerName || col.getColId();
        const val = this.gridApi.getValue(col, { data: row } as any);
        obj[hdr] = val ?? '';
      });
      return obj;
    });

    const ws = XLSX.utils.json_to_sheet(data, { header: headers });
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Portfolio');
    XLSX.writeFile(wb, `portfolio_${this.selectedFundName}_${this.priceTickDate}.xlsx`);
  }
}
