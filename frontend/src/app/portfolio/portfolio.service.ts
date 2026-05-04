import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { delay } from 'rxjs/operators';
import { ApiService } from '../shared/services/api.service';
import { Fund, Index, FundParams } from '../shared/models/fund.model';
import { PortfolioRow } from '../shared/models/portfolio-row.model';
import { Layout } from '../shared/models/layout.model';
import {
  MOCK_FUNDS, MOCK_INDICES, MOCK_FUND_PARAMS,
  MOCK_FUND_RETURN, MOCK_LAYOUTS,
} from '../shared/mock/mock-data';

// ── Toggle this to switch between mock and real API ──────────────────────
export const USE_MOCK = true;
// ─────────────────────────────────────────────────────────────────────────

@Injectable({ providedIn: 'root' })
export class PortfolioService {
  constructor(private api: ApiService, private http: HttpClient) {}

  getFunds(): Observable<Fund[]> {
    if (USE_MOCK) return of(MOCK_FUNDS as unknown as Fund[]).pipe(delay(100));
    return this.api.get<Fund[]>('/funds');
  }

  getIndices(): Observable<Index[]> {
    if (USE_MOCK) return of(MOCK_INDICES as Index[]).pipe(delay(80));
    return this.api.get<Index[]>('/funds/indices');
  }

  getFundParams(fundId: number): Observable<FundParams> {
    if (USE_MOCK) return of(MOCK_FUND_PARAMS as unknown as FundParams).pipe(delay(80));
    return this.api.get<FundParams>(`/funds/${fundId}/params`);
  }

  getPortfolio(fundId: number, indexId: number, runDate: string): Observable<PortfolioRow[]> {
    if (USE_MOCK) return this.http.get<PortfolioRow[]>('assets/portfolio-data.json');
    return this.api.get<PortfolioRow[]>('/portfolio', { fundId, indexId, runDate });
  }

  getLayouts(widgetId = 19): Observable<Layout[]> {
    if (USE_MOCK) return of(MOCK_LAYOUTS as unknown as Layout[]).pipe(delay(80));
    return this.api.get<Layout[]>('/layouts', { widgetId });
  }

  saveLayout(payload: {
    widgetId: number;
    layoutName: string;
    layoutString: string;
    layoutState: string;
    isDefault: number;
  }): Observable<Layout> {
    if (USE_MOCK) return of({ layout_id: 99, layout_name: payload.layoutName, widget_id: 19, is_default_layout: 0, layout_state: payload.layoutState } as unknown as Layout);
    return this.api.post<Layout>('/layouts', payload);
  }

  updateLayout(id: number, payload: {
    layoutString: string;
    layoutState: string;
    isDefault: number;
  }): Observable<{ success: boolean }> {
    if (USE_MOCK) return of({ success: true });
    return this.api.put<{ success: boolean }>(`/layouts/${id}`, payload);
  }

  getLivePrices(fundId: number, indexId: number, runDate: string): Observable<any[]> {
    if (USE_MOCK) return of([]);
    return this.api.get<any[]>('/portfolio/live-prices', { fundId, indexId, runDate });
  }

  getFundReturn(fundId: number, indexId: number, effDate: string): Observable<any> {
    if (USE_MOCK) return of(MOCK_FUND_RETURN).pipe(delay(100));
    return this.api.get<any>('/portfolio/return', { fundId, indexId, effDate });
  }

  logActivity(fundId: number, runDate: string): Observable<void> {
    if (USE_MOCK) return of(undefined as void);
    return this.api.post<void>('/activity-log', { pageId: 19, fundId, toDate: runDate });
  }
}
