export interface PortfolioRow {
  sector: string;
  sub_sector?: string | null;
  instrument_type?: string | null;
  security_name: string;
  isin_code: string;
  index_flag: string | null;
  fund_flag: string | null;
  fund_qty: number | null;
  cmp: number | null;
  ret_1d: number | null;
  ret_5d: number | null;
  ret_1m: number | null;
  ret_3m: number | null;
  ret_6m: number | null;
  ret_1y: number | null;
  ret_ytd: number | null;
  fund_mtm: number | null;
  fund_mtm_chg: number | null;
  fund_wts: number | null;
  index_wts: number | null;
  fund_aum: number | null;
  mcap: number | null;
  close_price: number | null;
  size: string | null;
  avg_vol: number | null;
  rating: string | null;
  is_sector_row: number;  // 0=security, 1=sector header, 2=sub-sector header
}
