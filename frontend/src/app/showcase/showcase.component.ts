import { Component, OnInit, HostBinding } from '@angular/core';
import { CommonModule, DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { AgGridModule } from 'ag-grid-angular';
import {
  ColDef, ColGroupDef, GridApi, GridReadyEvent, RowClassParams,
  ModuleRegistry, ClientSideRowModelModule,
} from 'ag-grid-community';
import { PortfolioRow } from '../shared/models/portfolio-row.model';

ModuleRegistry.registerModules([ClientSideRowModelModule]);

interface SectorRow    { sector: string; indexPct: number; fundPct: number; owUw: number; }
interface StockRow     { company: string; rating: string; indexPct: number; fundPct: number; }
interface RatingRow    { label: string; fundPct: number; indexPct: number; }
interface HoldingRow   { label: string; fundPct: number; indexPct: number; }
interface McapSegment  { label: string; pct: number; color: string; }
interface PerfRow { peer: string; m1: number|null; m3: number|null; m6: number|null; y1: number|null; y3: number|null; y5: number|null; isHighlight?: boolean; isIndex?: boolean; }

type SortDir = 'asc' | 'desc' | null;

interface KpiData {
  fundRet1d:    number;
  indexRet1d:   number;
  alpha1d:      number;
  aumCr:        number;
  investedPct:  number;
  cashPct:      number;
  wtdMcapFund:  number;   // weighted avg mcap (Cr)
  wtdMcapIndex: number;
}

@Component({
  selector: 'app-showcase',
  standalone: true,
  imports: [CommonModule, DecimalPipe, FormsModule, AgGridModule],
  templateUrl: './showcase.component.html',
  styleUrls: ['./showcase.component.scss'],
})
export class ShowcaseComponent implements OnInit {

  kpi:                KpiData       = { fundRet1d: 0, indexRet1d: 0, alpha1d: 0, aumCr: 0, investedPct: 0, cashPct: 0, wtdMcapFund: 0, wtdMcapIndex: 0 };
  historicalPerf:     PerfRow[]     = [];
  cosGt1:             StockRow[]    = [];
  sectorPattern:      SectorRow[]   = [];
  top20Stocks:        StockRow[]    = [];
  ratingExposure:     RatingRow[]   = [];
  holdingsPattern:    HoldingRow[]  = [];
  mcapFundSegments:   McapSegment[] = [];
  mcapIndexSegments:  McapSegment[] = [];

  // Sort state
  sectorSort: { col: keyof SectorRow | null; dir: SortDir } = { col: null, dir: null };
  top20Sort:  { col: keyof StockRow  | null; dir: SortDir } = { col: null, dir: null };
  perfSort:   { col: keyof PerfRow   | null; dir: SortDir } = { col: null, dir: null };
  cosGt1Sort: { col: keyof StockRow  | null; dir: SortDir } = { col: null, dir: null };

  // Natural-order snapshots for sort reset (3rd click)
  private _sectorOrig: SectorRow[] = [];
  private _top20Orig:  StockRow[]  = [];
  private _perfOrig:   PerfRow[]   = [];
  private _cosGt1Orig: StockRow[]  = [];

  // Theme toggle — persisted in localStorage (same key as portfolio)
  @HostBinding('class.dark') darkMode = true;
  toggleDarkMode(): void {
    this.darkMode = !this.darkMode;
    localStorage.setItem('nipeq_dark', this.darkMode ? '1' : '0');
  }

  // Controls bar
  scFundName  = 'Nippon India Multi Cap Fund';
  scIndexName = 'Nifty 500 Multicap 50:25:25';
  scLayout    = 'Default';
  scDate      = new Date().toISOString().substring(0, 10); // yyyy-mm-dd for input

  // Dropdown open states
  scFundOpen   = false;
  scIndexOpen  = false;
  scLayoutOpen = false;

  // Static lists (showcase uses JSON, one dataset)
  readonly scFunds = [
    { name: 'Nippon India Multi Cap Fund' },
    { name: 'Nippon India Large Cap Fund' },
    { name: 'Nippon India Small Cap Fund' },
  ];
  readonly scIndices = [
    { name: 'Nifty 500 Multicap 50:25:25' },
    { name: 'Nifty 50' },
    { name: 'Nifty 500' },
    { name: 'No Benchmark' },
  ];
  readonly scLayouts = ['Default', 'Compact', 'Wide'];

  // Search state for fund / index dropdowns
  scFundSearch  = '';
  scIndexSearch = '';

  get filteredScFunds(): { name: string }[] {
    const q = this.scFundSearch.toLowerCase().trim();
    return q ? this.scFunds.filter(f => f.name.toLowerCase().includes(q)) : this.scFunds;
  }
  get filteredScIndices(): { name: string }[] {
    const q = this.scIndexSearch.toLowerCase().trim();
    return q ? this.scIndices.filter(i => i.name.toLowerCase().includes(q)) : this.scIndices;
  }

  closeDropdowns(): void {
    this.scFundOpen = this.scIndexOpen = this.scLayoutOpen = false;
    this.scFundSearch = this.scIndexSearch = '';
  }

  selectFund(name: string, e: Event): void {
    e.stopPropagation();
    this.scFundName = name;
    this.scFundOpen = false;
    this.scFundSearch = '';
  }
  selectIndex(name: string, e: Event): void {
    e.stopPropagation();
    this.scIndexName = name;
    this.scIndexOpen = false;
    this.scIndexSearch = '';
  }
  selectLayout(name: string, e: Event): void {
    e.stopPropagation();
    this.scLayout = name;
    this.scLayoutOpen = false;
  }

  toggleFundDd(e: Event): void   { e.stopPropagation(); this.scFundOpen = !this.scFundOpen; this.scIndexOpen = this.scLayoutOpen = false; this.scFundSearch = ''; }
  toggleIndexDd(e: Event): void  { e.stopPropagation(); this.scIndexOpen = !this.scIndexOpen; this.scFundOpen = this.scLayoutOpen = false; this.scIndexSearch = ''; }
  toggleLayoutDd(e: Event): void { e.stopPropagation(); this.scLayoutOpen = !this.scLayoutOpen; this.scFundOpen = this.scIndexOpen = false; }

  process(e?: Event): void {
    e?.stopPropagation();
    this.closeDropdowns();
    this.loading = true;
    this.http.get<PortfolioRow[]>('assets/portfolio-data.json').subscribe(rows => {
      setTimeout(() => {
        this.allRows = rows;
        this.computeStats(rows);
        this.onFilterChange();
        this.compute(rows);
        this.loading = false;
      }, 600);
    });
  }

  // ── Sidebar ───────────────────────────────────────────────────
  sidebarCollapsed = true;

  // ── Tab switching ─────────────────────────────────────────────
  activeTab: 'fund' | 'style' = 'fund';

  // ── Stats strip ───────────────────────────────────────────────
  stats = {
    fundRet: 0, alpha: 0, indexRet: 0,
    investedPct: 0, investedCr: 0, aum: 0, cashPct: 0, cashCr: 0, cashCount: 0,
    wtdMcapFund: 0, wtdMcapIndex: 0,
    largeCap: 0, midCap: 0, smallCap: 0, rest: 0,
    mktPos: 0, toRatio: 0, cRatingWtg: 0, dRatingWtg: 0,
  };

  // ── AG Grid ───────────────────────────────────────────────────
  private gridApi!: GridApi;
  allRows: PortfolioRow[]      = [];
  filteredRows: PortfolioRow[] = [];
  loading = false;

  // Skeleton loader config (matches portfolio)
  readonly skColWidths = [220, 75, 95, 100, 90, 80, 95, 65, 95, 62, 62, 62, 62, 62];
  readonly skRows = this.buildSkRows();
  private buildSkRows() {
    const rows: { isSector: boolean; fills: number[] }[] = [];
    const rand = (min: number, max: number) => Math.floor(Math.random() * (max - min + 1)) + min;
    const cols = 14;
    for (let g = 0; g < 6; g++) {
      rows.push({ isSector: true, fills: [] });
      const count = rand(3, 5);
      for (let r = 0; r < count; r++) {
        rows.push({ isSector: false, fills: Array.from({ length: cols }, (_, i) => i === 0 ? rand(55, 85) : rand(40, 80)) });
      }
    }
    return rows;
  }

  // ── Filters ───────────────────────────────────────────────────
  onlyFund   = true;
  onlyIndex  = false;
  noPosition = false;
  onlySector = false;
  subSector  = false;
  noSector   = false;
  searchText = '';
  showColPanel = false;

  // ── Column visibility ─────────────────────────────────────────
  colVis: { field: string; headerName: string; visible: boolean }[] = [];
  private colDefaults: Map<string, boolean> = new Map();

  // ── Column defs ───────────────────────────────────────────────
  columnDefs: ColDef[] = [];
  defaultColDef: ColDef = { sortable: true, resizable: true, filter: false, suppressMovable: false };

  // max values for bar scaling
  get ratingMax(): number {
    return Math.max(...this.ratingExposure.map(r => Math.max(r.fundPct, r.indexPct)), 1);
  }
  get holdingMax(): number {
    return Math.max(...this.holdingsPattern.map(r => Math.max(r.fundPct, r.indexPct)), 1);
  }
  get mcapExpDonuts(): McapSegment[] {
    const order = ['Large Cap', 'Mid Cap', 'Small Cap', 'Rest'];
    return order
      .map(lbl => {
        const seg = this.mcapFundSegments.find(s => s.label === lbl);
        return { label: lbl, pct: seg ? seg.pct : 0, color: seg?.color ?? '#93c5fd' };
      });
  }

  get fundRestPct(): number {
    return +(this.mcapFundSegments.find(s => s.label === 'Rest')?.pct ?? 0);
  }
  get indexRestPct(): number {
    return +(this.mcapIndexSegments.find(s => s.label === 'Rest')?.pct ?? 0);
  }

  get ratingCD(): RatingRow[] {
    return this.ratingExposure.filter(r => r.label === 'C' || r.label === 'D');
  }
  get owMax(): number {
    return Math.max(...this.sectorPattern.map(r => Math.abs(r.owUw)), 1);
  }

  constructor(private http: HttpClient) {}

  ngOnInit(): void {
    this.darkMode = localStorage.getItem('nipeq_dark') !== '0'; // default dark
    this.buildColumnDefs();
    this.http.get<PortfolioRow[]>('assets/portfolio-data.json').subscribe(rows => {
      this.allRows = rows;
      this.computeStats(rows);
      this.onFilterChange();
      this.compute(rows);
    });
    this.http.get<any>('assets/style-analysis-data.json').subscribe(d => {
      this.historicalPerf = d.historicalPerformance ?? [];
      this._perfOrig = [...this.historicalPerf];
    });
  }

  // ── Build column defs ─────────────────────────────────────────
  private buildColumnDefs(): void {
    // Rating cell renderer — circle badge (same rat-badge classes as Style Analysis)
    const ratingRenderer = (p: any): string => {
      if (!p.value) return '';
      const cls = 'rat-badge rat-' + String(p.value).toLowerCase();
      return `<span class="${cls}" style="width:22px;height:22px;border-radius:50%;padding:0;display:inline-flex;align-items:center;justify-content:center;font-size:10px;font-weight:700">${p.value}</span>`;
    };

    // 100% exact same column definitions as original portfolio component
    this.columnDefs = [
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
      { field: 'close_price', headerName: 'Cl. Price',      minWidth: 70,  flex: 1.5, type: 'numericColumn', hide: true, valueFormatter: (p: any) => this.fmtNum(p.value, 2), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 2) },
      { field: 'cmp',         headerName: 'Price',          minWidth: 65,  flex: 1.5, type: 'numericColumn', valueFormatter: (p: any) => this.fmtNum(p.value, 2), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 2) },
      { field: 'fund_mtm_chg',headerName: 'MTM Chg. (Cr.)', minWidth: 85,  flex: 1.5, type: 'numericColumn', hide: true, valueFormatter: (p: any) => p.value == null ? '' : this.fmtNum(p.value / 1e7, 2), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value / 1e7, 2) + ' Cr.' },
      { field: 'mcap',        headerName: 'Mcap (Cr.)',     minWidth: 80,  flex: 2,   type: 'numericColumn', valueFormatter: (p: any) => this.fmtNum(p.value, 0, true), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 0, true) + ' Cr.' },
      { field: 'avg_vol',     headerName: '3M ADTV (Cr.)', minWidth: 85,  flex: 2,   type: 'numericColumn', valueFormatter: (p: any) => this.fmtNum(p.value, 0, true), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 0, true) + ' Cr.' },
      { field: '_avgvol3m',   headerName: '3M Avg. Vol.',  minWidth: 85,  flex: 2,   type: 'numericColumn', hide: true, valueGetter: () => null, valueFormatter: () => '' },
      { field: '_52wl',       headerName: '52 WL',          minWidth: 65,  flex: 1.5, type: 'numericColumn', hide: true, valueGetter: () => null, valueFormatter: () => '' },
      { field: '_52wh_abs',   headerName: '52 WH',          minWidth: 65,  flex: 1.5, type: 'numericColumn', hide: true, valueGetter: () => null, valueFormatter: () => '' },
      { field: '_52whchg',    headerName: '52 WH Chg.%',   minWidth: 75,  flex: 1.5, type: 'numericColumn', valueGetter: () => null, valueFormatter: () => '' },
      { field: 'fund_wts',    headerName: 'Pt. Wt. %',     minWidth: 65,  flex: 1.5, type: 'numericColumn', valueFormatter: (p: any) => this.fmtNum(p.value, 2), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 2) + '%' },
      { field: 'index_wts',   headerName: 'BM Wt. %',      minWidth: 65,  flex: 1.5, type: 'numericColumn', hide: true, valueFormatter: (p: any) => this.fmtNum(p.value, 2), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 2) + '%' },
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
      { field: 'fund_qty',    headerName: 'Qty.',           minWidth: 75,  flex: 1.8, type: 'numericColumn', valueFormatter: (p: any) => this.fmtNum(p.value, 0, true), tooltipValueGetter: (p: any) => p.value == null ? null : this.fmtNum(p.value, 0, true) },
      { field: 'rating',      headerName: 'Rating',         minWidth: 55,  flex: 1,   cellRenderer: ratingRenderer, cellStyle: { display: 'flex', alignItems: 'center', justifyContent: 'center' } },
      { field: 'fund_mtm',    headerName: 'Value (Cr.)',    minWidth: 80,  flex: 1.8, type: 'numericColumn', valueFormatter: (p: any) => p.value == null ? '' : this.fmtNum(p.value / 1e7, 2) },
      ...this.retCol('ret_1d',  '1D %'),
      ...this.retCol('ret_5d',  '1W %'),
      ...this.retCol('ret_1m',  '1M %'),
      ...this.retCol('ret_3m',  '3M %'),
      ...this.retCol('ret_6m',  '6M %'),
      ...this.retCol('ret_1y',  '1Y %'),
      ...this.retCol('ret_ytd', 'YTD %', true),
    ];

    // Build col-visibility list (skip pinned Company column)
    this.colVis = this.columnDefs
      .filter((c: any) => c.field !== 'security_name')
      .map((c: any) => ({
        field: c.colId || c.field || '',
        headerName: c.headerName || c.field || '',
        visible: !c.hide,
      }));
    // Store defaults for reset
    this.colDefaults = new Map(this.colVis.map(c => [c.field, c.visible]));
  }

  // Exact same retCol as original portfolio component
  private retCol(field: string, header: string, hide = false): ColDef[] {
    return [{
      field, headerName: header, minWidth: 55, flex: 1.2, type: 'numericColumn', hide,
      tooltipValueGetter: (p: any) => p.value == null ? null : Number(p.value).toFixed(2) + '%',
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

  // ── Grid callbacks ────────────────────────────────────────────
  onGridReady(params: GridReadyEvent): void {
    this.gridApi = params.api;
  }

  getRowClass = (params: RowClassParams): string => {
    if (params.data?.is_sector_row === 1) return 'sector-row';
    if (params.data?.is_sector_row === 2) return 'subsector-row';
    return '';
  };

  postSortRows = (params: { nodes: any[] }): void => {
    const nodes = params.nodes;
    const sectorHeaderMap = new Map<string, any>();
    nodes.forEach(n => {
      if (n.data?.is_sector_row === 1) sectorHeaderMap.set(n.data.sector, n);
    });
    const hasSubSector = nodes.some(n => n.data?.is_sector_row === 2);
    if (!hasSubSector) {
      const hasSecurities = nodes.some(n => n.data?.is_sector_row === 0);
      if (!hasSecurities) return;
      const sectorOrder: string[] = [];
      const sectorRowsMap = new Map<string, any[]>();
      nodes.forEach(n => {
        if (n.data?.is_sector_row === 1) return;
        const sec: string = n.data?.sector ?? '';
        if (!sectorRowsMap.has(sec)) { sectorRowsMap.set(sec, []); sectorOrder.push(sec); }
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
    const subSectorHeaderMap = new Map<string, any>();
    nodes.forEach(n => {
      if (n.data?.is_sector_row === 2) {
        subSectorHeaderMap.set(`${n.data.sector}|||${n.data.sub_sector}`, n);
      }
    });
    const sectorOrder: string[] = [];
    const sectorMap = new Map<string, { subOrder: string[]; subMap: Map<string, any[]> }>();
    nodes.forEach(n => {
      if (n.data?.is_sector_row !== 0) return;
      const sec: string = n.data?.sector ?? '';
      const sub: string = n.data?.sub_sector || 'Other';
      if (!sectorMap.has(sec)) { sectorMap.set(sec, { subOrder: [], subMap: new Map() }); sectorOrder.push(sec); }
      const sData = sectorMap.get(sec)!;
      if (!sData.subMap.has(sub)) { sData.subMap.set(sub, []); sData.subOrder.push(sub); }
      sData.subMap.get(sub)!.push(n);
    });
    const result: any[] = [];
    sectorOrder.forEach(sec => {
      const sHdr = sectorHeaderMap.get(sec);
      if (sHdr) result.push(sHdr);
      const sData = sectorMap.get(sec)!;
      sData.subOrder.forEach(sub => {
        const subHdr = subSectorHeaderMap.get(`${sec}|||${sub}`);
        if (subHdr) result.push(subHdr);
        result.push(...sData.subMap.get(sub)!);
      });
    });
    nodes.splice(0, nodes.length, ...result);
  };

  // ── Filter methods ────────────────────────────────────────────
  onFilterChange(): void { this.applyFilters(); }

  private applyFilters(): void {
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

    const aggMap = new Map<string, Agg>();
    secRows.forEach(r => {
      if (!aggMap.has(r.sector)) aggMap.set(r.sector, blankAgg());
      accumulate(aggMap.get(r.sector)!, r);
    });

    const sectorHeaders = new Map(
      this.allRows.filter(r => r.is_sector_row === 1).map(r => [r.sector, r])
    );

    let rows: PortfolioRow[];
    if (this.noSector) {
      rows = secRows;
    } else if (this.onlySector) {
      rows = [...aggMap.keys()].map(sec => {
        const hdr = sectorHeaders.get(sec);
        return hdr ? enrich(hdr, aggMap.get(sec)!) : null;
      }).filter(Boolean) as PortfolioRow[];
    } else {
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

    // Inject sub-sector headers when enabled
    if (this.subSector && !this.onlySector && !this.noSector) {
      const subAggMap = new Map<string, Agg>();
      secRows.forEach(r => {
        const key = `${r.sector}|||${(r as any).sub_sector || 'Other'}`;
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
        const sub = (row as any).sub_sector || 'Other';
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

  onSearch(): void { this.onFilterChange(); }

  onNoPositionChange(): void {
    if (this.noPosition) {
      this.onlyFund = false;
    } else {
      this.onlyFund = true;
    }
    this.onFilterChange();
  }

  onNoSectorChange(): void {
    if (this.noSector) {
      this.onlySector = false;
      this.subSector  = false;
    }
    this.onFilterChange();
  }

  onOnlySectorChange(): void {
    if (this.onlySector) {
      this.noSector  = false;
      this.subSector = false;
    }
    this.onFilterChange();
  }

  onSubSectorChange(): void {
    if (this.subSector) {
      this.noSector   = false;
      this.onlySector = false;
    }
    this.onFilterChange();
  }

  toggleColumn(field: string, visible: boolean): void {
    if (this.gridApi && field) this.gridApi.setColumnsVisible([field], visible);
  }

  resetColumns(): void {
    this.colVis.forEach(col => {
      const def = this.colDefaults.get(col.field) ?? false;
      col.visible = def;
      if (this.gridApi) this.gridApi.setColumnsVisible([col.field], def);
    });
  }

  // ── Compute stats strip ───────────────────────────────────────
  computeStats(rows: PortfolioRow[]): void {
    const sec = rows.filter(r => r.is_sector_row === 0);
    this.stats.aum = sec.length ? Number(sec[0].fund_aum ?? 0) : 0;

    const cashRows = sec.filter(r => (r.sector || '').toUpperCase().includes('CASH'));
    this.stats.cashCount = cashRows.length;

    const eqRows = sec.filter(r => !(r.sector || '').toUpperCase().includes('CASH') && Number(r.fund_wts ?? 0) > 0);
    this.stats.investedPct = +eqRows.reduce((s, r) => s + Number(r.fund_wts ?? 0), 0).toFixed(2);

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
      const fw = Number(r.fund_wts ?? 0);
      const iw = Number(r.index_wts ?? 0);
      if (m > 0 && fw > 0) { wN  += fw * m; wD  += fw; }
      if (m > 0 && iw > 0) { wiN += iw * m; wiD += iw; }
    });
    this.stats.wtdMcapFund  = wD  > 0 ? wN  / wD  / 1000 : 0;
    this.stats.wtdMcapIndex = wiD > 0 ? wiN / wiD / 1000 : 0;

    this.stats.cRatingWtg = sec.filter(r => r.rating === 'C').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
    this.stats.dRatingWtg = sec.filter(r => r.rating === 'D').reduce((s, r) => s + Number(r.fund_wts ?? 0), 0);
  }

  // ── Compute style analysis data ───────────────────────────────
  private compute(dataRows: PortfolioRow[]): void {
    const sec     = dataRows.filter(r => r.is_sector_row === 0);
    const isCash  = (r: PortfolioRow) => (r.sector || '').toUpperCase().includes('CASH');
    const fundSec = sec.filter(r => r.fund_flag === 'FUND' && !isCash(r));
    const idxSec  = sec.filter(r => (r.index_wts ?? 0) > 0 && !isCash(r));

    // cash totals
    const cashFund  = sec.filter(r => isCash(r) && r.fund_flag === 'FUND')
                         .reduce((s, r) => s + (r.fund_wts ?? 0), 0);

    // ── KPI ──────────────────────────────────────────────────────
    const fundRetNum  = fundSec.reduce((s, r) => s + (r.fund_wts ?? 0) * (r.ret_1d ?? 0), 0);
    const fundRetDen  = fundSec.reduce((s, r) => s + (r.fund_wts  ?? 0), 0);
    const idxRetNum   = idxSec.reduce((s,  r) => s + (r.index_wts ?? 0) * (r.ret_1d ?? 0), 0);
    const idxRetDen   = idxSec.reduce((s,  r) => s + (r.index_wts  ?? 0), 0);
    const fundRet1d   = fundRetDen  > 0 ? +(fundRetNum / fundRetDen).toFixed(2) : 0;
    const indexRet1d  = idxRetDen   > 0 ? +(idxRetNum  / idxRetDen).toFixed(2)  : 0;
    // AUM = sum of all fund MTM (fund_mtm is in Cr); fallback to fund_aum field
    const aumFromMtm  = sec.filter(r => r.fund_flag === 'FUND').reduce((s, r) => s + (r.fund_mtm ?? 0), 0);
    const aumFromFld  = sec.find(r => (r.fund_aum ?? 0) > 0)?.fund_aum ?? 0;
    const aumCr       = aumFromMtm > 0 ? aumFromMtm : aumFromFld;
    const investedPct = +fundSec.reduce((s, r) => s + (r.fund_wts ?? 0), 0).toFixed(1);
    const mfNum = fundSec.reduce((s, r) => s + (r.fund_wts ?? 0) * (r.mcap ?? 0), 0);
    const miNum = idxSec.reduce((s,  r) => s + (r.index_wts ?? 0) * (r.mcap ?? 0), 0);
    this.kpi = {
      fundRet1d, indexRet1d, alpha1d: +(fundRet1d - indexRet1d).toFixed(2),
      aumCr: +(aumCr / 1e7).toFixed(0),
      investedPct, cashPct: +(cashFund).toFixed(1),
      wtdMcapFund:  fundRetDen > 0 ? +(mfNum / fundRetDen).toFixed(0) : 0,
      wtdMcapIndex: idxRetDen  > 0 ? +(miNum / idxRetDen).toFixed(0)  : 0,
    };

    // ── Sector Pattern ───────────────────────────────────────────
    const sFund  = new Map<string, number>();
    const sIdx   = new Map<string, number>();
    const order  = dataRows.filter(r => r.is_sector_row === 1 && !isCash({ sector: r.sector } as PortfolioRow))
                          .map(r => r.sector);
    fundSec.forEach(r => sFund.set(r.sector, (sFund.get(r.sector) ?? 0) + (r.fund_wts ?? 0)));
    idxSec.forEach(r  => sIdx.set(r.sector,  (sIdx.get(r.sector)  ?? 0) + (r.index_wts ?? 0)));
    const allS = [...new Set([...order, ...sFund.keys(), ...sIdx.keys()])];
    this.sectorPattern = allS.map(sector => {
      const f = +(sFund.get(sector) ?? 0).toFixed(2);
      const i = +(sIdx.get(sector)  ?? 0).toFixed(2);
      return { sector, indexPct: i, fundPct: f, owUw: +(f - i).toFixed(2) };
    });

    // ── Cos@ >1% WT IN INDEX ─────────────────────────────────────
    const cosMap = new Map<string, PortfolioRow>();
    sec.forEach(r => { if ((r.index_wts ?? 0) >= 1.0) cosMap.set(r.security_name, r); });
    this.cosGt1 = [...cosMap.values()]
      .sort((a, b) => (b.fund_wts ?? 0) - (a.fund_wts ?? 0))
      .map(r => ({
        company:  r.security_name,
        rating:   r.rating || 'NA',
        indexPct: +(r.index_wts ?? 0).toFixed(2),
        fundPct:  +(r.fund_wts  ?? 0).toFixed(2),
      }));

    // ── Top 20 ──────────────────────────────────────────────────
    this.top20Stocks = [...fundSec]
      .filter(r => (r.fund_wts ?? 0) > 0)
      .sort((a, b) => (b.fund_wts ?? 0) - (a.fund_wts ?? 0))
      .slice(0, 20)
      .map(r => ({
        company:  r.security_name,
        rating:   r.rating || 'NA',
        indexPct: +(r.index_wts ?? 0).toFixed(2),
        fundPct:  +(r.fund_wts  ?? 0).toFixed(2),
      }));

    // ── Rating Exposure ──────────────────────────────────────────
    const ratingOrder = ['A', 'B', 'C', 'D', 'NA', 'DNA'];
    const rF = new Map<string, number>();
    const rI = new Map<string, number>();
    fundSec.forEach(r => { const k = (r.rating || 'NA').toUpperCase(); rF.set(k, (rF.get(k) ?? 0) + (r.fund_wts ?? 0)); });
    idxSec.forEach(r  => { const k = (r.rating || 'NA').toUpperCase(); rI.set(k, (rI.get(k) ?? 0) + (r.index_wts ?? 0)); });
    this.ratingExposure = ratingOrder
      .map(rat => ({ label: rat, fundPct: +(rF.get(rat) ?? 0).toFixed(1), indexPct: +(rI.get(rat) ?? 0).toFixed(1) }))
      .filter(r => r.fundPct > 0 || r.indexPct > 0);

    // ── Holdings Pattern ─────────────────────────────────────────
    const sf = [...fundSec].filter(r => (r.fund_wts  ?? 0) > 0).sort((a, b) => (b.fund_wts  ?? 0) - (a.fund_wts  ?? 0));
    const si = [...idxSec].filter(r  => (r.index_wts ?? 0) > 0).sort((a, b) => (b.index_wts ?? 0) - (a.index_wts ?? 0));
    const cumF = (n: number) => sf.slice(0, n).reduce((s, r) => s + (r.fund_wts  ?? 0), 0);
    const cumI = (n: number) => si.slice(0, n).reduce((s, r) => s + (r.index_wts ?? 0), 0);
    this.holdingsPattern = [5, 10, 20, 30].map(n => ({
      label: `Top ${n}`, fundPct: +cumF(n).toFixed(1), indexPct: +cumI(n).toFixed(1),
    }));

    // ── MCAP Exposure ────────────────────────────────────────────
    const mF = new Map<string, number>();
    const mI = new Map<string, number>();
    const sizeLabel = (s: string | null | undefined) =>
      s === 'LC' ? 'Large Cap' : s === 'MC' ? 'Mid Cap' : s === 'SC' ? 'Small Cap' : null;
    fundSec.forEach(r => {
      const lbl = sizeLabel(r.size);
      if (lbl) mF.set(lbl, (mF.get(lbl) ?? 0) + (r.fund_wts ?? 0));
    });
    idxSec.forEach(r => {
      const lbl = sizeLabel(r.size);
      if (lbl) mI.set(lbl, (mI.get(lbl) ?? 0) + (r.index_wts ?? 0));
    });
    const mcapColors: Record<string, string> = {
      'Large Cap': '#2563eb', 'Mid Cap': '#3b82f6', 'Small Cap': '#60a5fa', 'Rest': '#93c5fd',
    };
    const mcapOrder = ['Large Cap', 'Mid Cap', 'Small Cap'];

    const totalFundWts   = fundSec.reduce((s, r) => s + (r.fund_wts  ?? 0), 0);
    const totalIdxWts    = idxSec.reduce((s,  r) => s + (r.index_wts ?? 0), 0);
    const cashIndex      = sec.filter(r => isCash(r) && (r.index_wts ?? 0) > 0)
                              .reduce((s, r) => s + (r.index_wts ?? 0), 0);
    const fundLcMcSc     = mcapOrder.reduce((s, lbl) => s + (mF.get(lbl) ?? 0), 0);
    const idxLcMcSc      = mcapOrder.reduce((s, lbl) => s + (mI.get(lbl) ?? 0), 0);
    const fundRestPctRaw = Math.max(0, (totalFundWts - fundLcMcSc) + cashFund);
    const idxRestPctRaw  = Math.max(0, (totalIdxWts  - idxLcMcSc)  + cashIndex);

    this.mcapFundSegments = [
      ...mcapOrder.map(lbl => ({ label: lbl, pct: +(mF.get(lbl) ?? 0).toFixed(1), color: mcapColors[lbl] })),
      { label: 'Rest', pct: +fundRestPctRaw.toFixed(1), color: mcapColors['Rest'] },
    ].filter(s => +s.pct > 0);
    this.mcapIndexSegments = [
      ...mcapOrder.map(lbl => ({ label: lbl, pct: +(mI.get(lbl) ?? 0).toFixed(1), color: mcapColors[lbl] })),
      { label: 'Rest', pct: +idxRestPctRaw.toFixed(1), color: mcapColors['Rest'] },
    ].filter(s => +s.pct > 0);

    // Reset sort states + snapshot natural order
    this.sectorSort = { col: null, dir: null };
    this.top20Sort  = { col: null, dir: null };
    this.cosGt1Sort = { col: null, dir: null };
    this._sectorOrig = [...this.sectorPattern];
    this._top20Orig  = [...this.top20Stocks];
    this._cosGt1Orig = [...this.cosGt1];
  }

  // ── Generic sort (asc → desc → natural, third click resets) ──
  private applySort<T>(
    arr: T[], original: T[],
    state: { col: keyof T | null; dir: SortDir },
    col: keyof T,
  ): T[] {
    if (state.col === col) {
      state.dir = state.dir === 'asc' ? 'desc' : state.dir === 'desc' ? null : 'asc';
    } else {
      state.col = col; state.dir = 'desc';
    }
    if (!state.dir) { state.col = null; return [...original]; }
    const dir = state.dir;
    return [...arr].sort((a, b) => {
      const av = a[col] as any, bv = b[col] as any;
      if (av == null && bv == null) return 0;
      if (av == null) return 1; if (bv == null) return -1;
      const d = av < bv ? -1 : av > bv ? 1 : 0;
      return dir === 'asc' ? d : -d;
    });
  }

  sortSector(col: keyof SectorRow) {
    this.sectorPattern  = this.applySort(this.sectorPattern,  this._sectorOrig, this.sectorSort, col);
  }
  sortTop20(col: keyof StockRow) {
    this.top20Stocks    = this.applySort(this.top20Stocks,    this._top20Orig,  this.top20Sort,  col);
  }
  sortPerf(col: keyof PerfRow) {
    this.historicalPerf = this.applySort(this.historicalPerf, this._perfOrig,   this.perfSort,   col);
  }
  sortCosGt1(col: keyof StockRow) {
    this.cosGt1         = this.applySort(this.cosGt1,         this._cosGt1Orig, this.cosGt1Sort, col);
  }

  sortIcon<T>(state: { col: keyof T | null; dir: SortDir }, col: keyof T): string {
    if (state.col !== col) return '⇅';
    return state.dir === 'asc' ? '↑' : state.dir === 'desc' ? '↓' : '⇅';
  }

  // ── Helpers ──────────────────────────────────────────────────
  readonly Math = Math;
  n1(v: number): string { return v.toFixed(1); }
  n1n(v: number | null | undefined): string { return v == null ? '—' : v.toFixed(1); }
  retCls(v: number | null | undefined): string { return v == null ? '' : v > 0 ? 'pos' : v < 0 ? 'neg' : ''; }
  n2(v: number): string { return v.toFixed(2); }
  fmt(v: number): string {
    if (Math.abs(v) >= 1_00_000) return (v / 1000).toFixed(0) + 'k';
    if (Math.abs(v) >= 1000)     return (v / 1000).toFixed(1) + 'k';
    return v.toFixed(0);
  }
  fmt1(v: number): string { return v == null ? '—' : v.toFixed(1); }
  fmtK(v: number): string {
    if (Math.abs(v) >= 1_00_000) return (v / 1000).toFixed(0) + 'k';
    if (Math.abs(v) >= 1000)     return (v / 1000).toFixed(1) + 'k';
    return v.toFixed(0);
  }
  fmtNum(v: any, dec = 2, skipZero = false): string {
    const n = Number(v);
    if (v == null || isNaN(n)) return '';
    if (skipZero && n === 0) return '';
    return dec === 0
      ? n.toLocaleString('en-IN', { maximumFractionDigits: 0 })
      : n.toFixed(dec);
  }
  owClass(v: number): string { return v > 0 ? 'pos' : v < 0 ? 'neg' : 'zero'; }
  retClass(v: number): string { return v > 0 ? 'kpi-pos' : v < 0 ? 'kpi-neg' : 'kpi-zero'; }
  retColor(v: number): string { return v >= 0 ? '#34d399' : '#f87171'; }
  donutTransform(v: number): string {
    return v < 0
      ? 'rotate(-90 22 22) translate(44,0) scale(-1,1)'
      : 'rotate(-90 22 22)';
  }

  gaugeDash(ret: number, max = 2): string {
    const track = 84.823, total = 113.097;
    const fill = Math.min(Math.abs(ret), max) / max * track;
    return `${fill.toFixed(1)} ${(total - fill).toFixed(1)}`;
  }

  speedoDash(ret: number, max = 2): string {
    const halfCirc = Math.PI * 42;
    const fill = Math.min(Math.abs(ret), max) / max * halfCirc;
    return `${fill.toFixed(1)} ${(halfCirc - fill).toFixed(1)}`;
  }
  ratingClass(r: string): string { return 'rat-' + r.toLowerCase(); }
  barWidth(v: number, max: number): string { return Math.min((v / max) * 100, 100).toFixed(1) + '%'; }

  sparkline(seed: number, positive: boolean): string {
    const W = 88, H = 32, pts = 14;
    const xs: number[] = [], ys: number[] = [];
    let y = positive ? H * 0.65 : H * 0.35;
    for (let i = 0; i < pts; i++) {
      const r = (Math.sin(seed * (i + 1) * 7.391) * 0.5 + 0.5);
      const trend = positive ? -(i / pts) * H * 0.45 : (i / pts) * H * 0.45;
      y = Math.max(3, Math.min(H - 3, H * 0.5 + trend + (r - 0.5) * 9));
      xs.push(i * (W / (pts - 1))); ys.push(y);
    }
    return xs.map((x, i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${ys[i].toFixed(1)}`).join(' ');
  }

  donutDash(pct: number): string {
    const c = 2 * Math.PI * 18;
    const fill = (Math.min(Math.max(pct, 0), 100) / 100) * c;
    return `${fill.toFixed(1)} ${(c - fill).toFixed(1)}`;
  }

  donutDashRat(pct: number): string {
    const c = 2 * Math.PI * 15;
    const fill = (Math.min(Math.max(pct, 0), 100) / 100) * c;
    return `${fill.toFixed(1)} ${(c - fill).toFixed(1)}`;
  }

  ratingColor(r: string): string {
    const map: Record<string, string> = {
      A: '#34d399', B: '#60a5fa', C: '#fbbf24', D: '#f87171',
      NA: '#6b7280', DNA: '#6b7280',
    };
    return map[r.toUpperCase()] ?? '#6b7280';
  }
}
