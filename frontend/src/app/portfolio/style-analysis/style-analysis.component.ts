import { Component, OnInit, OnChanges, Input, HostBinding, SimpleChanges } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { PortfolioRow } from '../../shared/models/portfolio-row.model';

// ── Derived table row shapes ──────────────────────────────────────────────────
export interface SectorPatternRow { sector: string; indexPct: number; fundPct: number; owUw: number; }
export interface StockRow         { company: string; rating: string; indexPct: number; fundPct: number; }
export interface PerfRow          { peer: string; m1: number | null; m3: number | null; m6: number | null; y1: number | null; y3: number | null; y5: number | null; isHighlight?: boolean; isIndex?: boolean; }
export interface TwoColRow        { label: string; indexPct: number; fundPct: number; }

type SortDir = 'asc' | 'desc' | null;

@Component({
  selector: 'app-style-analysis',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './style-analysis.component.html',
  styleUrls: ['./style-analysis.component.scss'],
})
export class StyleAnalysisComponent implements OnInit, OnChanges {
  @Input() darkMode = false;
  @Input() allRows: PortfolioRow[] = [];

  /** Apply :host.dark in the same cycle the input is set — no parent-binding delay. */
  @HostBinding('class.dark') get darkClass() { return this.darkMode; }

  // Computed tables
  sectorPattern:   SectorPatternRow[] = [];
  top20Stocks:     StockRow[]         = [];
  cosGt1:          StockRow[]         = [];
  ratingExposure:  TwoColRow[]        = [];
  holdingsPattern: TwoColRow[]        = [];
  mcapExposure:    TwoColRow[]        = [];

  // Historical performance — from DB/JSON, not computed from portfolio rows
  historicalPerf: PerfRow[] = [];

  // Sort state
  sectorSort: { col: keyof SectorPatternRow | null; dir: SortDir } = { col: null, dir: null };
  top20Sort:  { col: keyof StockRow         | null; dir: SortDir } = { col: null, dir: null };
  perfSort:   { col: keyof PerfRow          | null; dir: SortDir } = { col: null, dir: null };
  cosGt1Sort: { col: keyof StockRow         | null; dir: SortDir } = { col: null, dir: null };

  // Natural-order snapshots for reset-on-third-click
  private _sectorOrig:  SectorPatternRow[] = [];
  private _top20Orig:   StockRow[]         = [];
  private _perfOrig:    PerfRow[]          = [];
  private _cosGt1Orig:  StockRow[]         = [];

  constructor(private http: HttpClient) {}

  ngOnInit(): void {
    // Load historical performance from JSON (comes from DB in production)
    this.http.get<any>('assets/style-analysis-data.json').subscribe(d => {
      this.historicalPerf = d.historicalPerformance ?? [];
      this._perfOrig = [...this.historicalPerf];
    });
    this.compute();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['allRows']) this.compute();
  }

  // ── Main computation ─────────────────────────────────────────────────────
  private compute(): void {
    if (!this.allRows?.length) return;

    // Reset sort states so visual indicators stay in sync with data order
    this.sectorSort = { col: null, dir: null };
    this.top20Sort  = { col: null, dir: null };
    this.cosGt1Sort = { col: null, dir: null };

    // Work only with security rows (not sector headers)
    const sec = this.allRows.filter(r => r.is_sector_row === 0);
    const isCash = (r: PortfolioRow) => (r.sector || '').toUpperCase().includes('CASH');

    const fundSec  = sec.filter(r => r.fund_flag === 'FUND' && !isCash(r));
    const indexSec = sec.filter(r => (r.index_wts ?? 0) > 0 && !isCash(r));

    // ── 1. Sector-Wise Investment Pattern ──────────────────────────────────
    const sectorFundMap  = new Map<string, number>();
    const sectorIndexMap = new Map<string, number>();

    // Preserve sector order from sector header rows
    const sectorOrder = this.allRows
      .filter(r => r.is_sector_row === 1 && !isCash({ sector: r.sector } as PortfolioRow))
      .map(r => r.sector);

    fundSec.forEach(r => {
      sectorFundMap.set(r.sector, (sectorFundMap.get(r.sector) ?? 0) + (r.fund_wts ?? 0));
    });
    indexSec.forEach(r => {
      sectorIndexMap.set(r.sector, (sectorIndexMap.get(r.sector) ?? 0) + (r.index_wts ?? 0));
    });

    // Add cash sectors
    const cashFund  = sec.filter(r => isCash(r) && r.fund_flag === 'FUND')
                         .reduce((s, r) => s + (r.fund_wts ?? 0), 0);
    const cashIndex = sec.filter(r => isCash(r))
                         .reduce((s, r) => s + (r.index_wts ?? 0), 0);

    const allSectors = [...new Set([...sectorOrder, ...sectorFundMap.keys(), ...sectorIndexMap.keys()])];
    this.sectorPattern = allSectors.map(sector => {
      const fundPct  = +(sectorFundMap.get(sector)  ?? 0).toFixed(2);
      const indexPct = +(sectorIndexMap.get(sector) ?? 0).toFixed(2);
      return { sector, indexPct, fundPct, owUw: +(fundPct - indexPct).toFixed(2) };
    });

    // Append Cash & Cash Equivalents row
    if (cashFund > 0 || cashIndex > 0) {
      this.sectorPattern.push({
        sector: 'CASH & CASH EQUIVALENTS',
        indexPct: +cashIndex.toFixed(2),
        fundPct:  +cashFund.toFixed(2),
        owUw:     +(cashFund - cashIndex).toFixed(2),
      });
    }

    // ── 2. Top 20 Stocks (by fund weight) ─────────────────────────────────
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

    // ── 3. Cos@ >1% WT in Index ────────────────────────────────────────────
    // Securities with index_wts >= 1%, showing both fund and index weight
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

    // ── 4. Rating Exposure ─────────────────────────────────────────────────
    const ratingOrder = ['A', 'B', 'C', 'D', 'NA', 'DNA'];
    const rFund  = new Map<string, number>();
    const rIndex = new Map<string, number>();

    fundSec.forEach(r => {
      const rat = (r.rating || 'NA').toUpperCase();
      rFund.set(rat, (rFund.get(rat) ?? 0) + (r.fund_wts ?? 0));
    });
    indexSec.forEach(r => {
      const rat = (r.rating || 'NA').toUpperCase();
      rIndex.set(rat, (rIndex.get(rat) ?? 0) + (r.index_wts ?? 0));
    });

    const allRatings = [...new Set([...rFund.keys(), ...rIndex.keys(), ...ratingOrder])];
    this.ratingExposure = allRatings
      .sort((a, b) => {
        const ai = ratingOrder.indexOf(a); const bi2 = ratingOrder.indexOf(b);
        return (ai === -1 ? 99 : ai) - (bi2 === -1 ? 99 : bi2);
      })
      .map(rat => ({
        label:    rat,
        indexPct: +(rIndex.get(rat) ?? 0).toFixed(1),
        fundPct:  +(rFund.get(rat)  ?? 0).toFixed(1),
      }))
      .filter(r => r.indexPct > 0 || r.fundPct > 0);

    // ── 5. Holdings Pattern (concentration) ───────────────────────────────
    const sortedFund  = [...fundSec].filter(r => (r.fund_wts ?? 0) > 0)
                                    .sort((a, b) => (b.fund_wts ?? 0) - (a.fund_wts ?? 0));
    const sortedIndex = [...indexSec].filter(r => (r.index_wts ?? 0) > 0)
                                     .sort((a, b) => (b.index_wts ?? 0) - (a.index_wts ?? 0));

    const cumFund  = (n: number) => sortedFund.slice(0, n).reduce((s, r) => s + (r.fund_wts  ?? 0), 0);
    const cumIndex = (n: number) => sortedIndex.slice(0, n).reduce((s, r) => s + (r.index_wts ?? 0), 0);

    this.holdingsPattern = [5, 10, 20, 30].map(n => ({
      label:    `Top ${n}`,
      indexPct: +cumIndex(n).toFixed(1),
      fundPct:  +cumFund(n).toFixed(1),
    }));

    // ── 6. MCAP Exposure ───────────────────────────────────────────────────
    const mcapFund  = new Map<string, number>();
    const mcapIndex = new Map<string, number>();
    const sizeLabel = (s: string | null | undefined) =>
      s === 'LC' ? 'Large Cap' : s === 'MC' ? 'Mid Cap' : s === 'SC' ? 'Small Cap' : 'Other';

    fundSec.forEach(r => {
      const lbl = sizeLabel(r.size);
      mcapFund.set(lbl, (mcapFund.get(lbl) ?? 0) + (r.fund_wts ?? 0));
    });
    indexSec.forEach(r => {
      const lbl = sizeLabel(r.size);
      mcapIndex.set(lbl, (mcapIndex.get(lbl) ?? 0) + (r.index_wts ?? 0));
    });

    const mcapOrder = ['Large Cap', 'Mid Cap', 'Small Cap'];
    this.mcapExposure = mcapOrder.map(lbl => ({
      label:    lbl,
      indexPct: +(mcapIndex.get(lbl) ?? 0).toFixed(1),
      fundPct:  +(mcapFund.get(lbl)  ?? 0).toFixed(1),
    }));
    // Add Cash row
    this.mcapExposure.push({ label: 'Cash & C.E.', indexPct: +cashIndex.toFixed(1), fundPct: +cashFund.toFixed(1) });

    // Snapshot natural order for sort-reset
    this._sectorOrig = [...this.sectorPattern];
    this._top20Orig  = [...this.top20Stocks];
    this._cosGt1Orig = [...this.cosGt1];
  }

  // ── Generic sort ──────────────────────────────────────────────────────────
  // Returns a NEW sorted array; state is updated as a controlled side-effect.
  // Third click on the same column resets to the supplied `original` snapshot.
  private applySort<T>(
    arr: T[],
    original: T[],
    state: { col: keyof T | null; dir: SortDir },
    col: keyof T,
  ): T[] {
    if (state.col === col) {
      state.dir = state.dir === 'asc' ? 'desc' : state.dir === 'desc' ? null : 'asc';
    } else {
      state.col = col;
      state.dir = 'desc';
    }
    if (!state.dir) {
      state.col = null;
      return [...original]; // true reset to natural order
    }
    const dir = state.dir;
    return [...arr].sort((a, b) => {
      const av = a[col] as any;
      const bv = b[col] as any;
      // nulls always last
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      const diff = av < bv ? -1 : av > bv ? 1 : 0;
      return dir === 'asc' ? diff : -diff;
    });
  }

  sortSector(col: keyof SectorPatternRow) {
    this.sectorPattern  = this.applySort(this.sectorPattern,  this._sectorOrig,  this.sectorSort,  col);
  }
  sortTop20(col: keyof StockRow) {
    this.top20Stocks    = this.applySort(this.top20Stocks,    this._top20Orig,   this.top20Sort,   col);
  }
  sortPerf(col: keyof PerfRow) {
    this.historicalPerf = this.applySort(this.historicalPerf, this._perfOrig,    this.perfSort,    col);
  }
  sortCosGt1(col: keyof StockRow) {
    this.cosGt1         = this.applySort(this.cosGt1,         this._cosGt1Orig,  this.cosGt1Sort,  col);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  sortIcon<T>(state: { col: keyof T | null; dir: SortDir }, col: keyof T): string {
    if (state.col !== col) return '⇅';
    return state.dir === 'asc' ? '↑' : state.dir === 'desc' ? '↓' : '⇅';
  }

  n1(v: number | null | undefined): string {
    if (v == null) return '—';
    return v.toFixed(1);
  }

  owClass(v: number | null | undefined): string { return v == null ? '' : v > 0 ? 'pos' : v < 0 ? 'neg' : ''; }
  retClass(v: number | null | undefined): string { return v == null ? '' : v > 0 ? 'pos' : v < 0 ? 'neg' : ''; }
}
