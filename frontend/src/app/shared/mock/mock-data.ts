/**
 * Mock data for frontend-only development.
 * Flip USE_MOCK = true in portfolio.service.ts to activate.
 *
 * fund_flag='FUND' + index_wts=null  → Fund-only  (shows in Only Fund, hidden in Only Index)
 * fund_flag=null   + index_wts>0     → BM-only    (shows in Only Index, hidden in Only Fund)
 * fund_flag='FUND' + index_wts>0     → In both    (shows in both filters)
 */

export const MOCK_FUNDS = [
  { fund_id: 1001, fund_name: 'Nippon India Multi Cap Fund',       fund_type: 'EQ', is_default_fund: 1 },
  { fund_id: 1002, fund_name: 'Nippon India Large Cap Fund',       fund_type: 'EQ', is_default_fund: 0 },
  { fund_id: 1003, fund_name: 'Nippon India Mid Cap Fund',         fund_type: 'EQ', is_default_fund: 0 },
  { fund_id: 1004, fund_name: 'Nippon India Flexi Cap Fund',       fund_type: 'EQ', is_default_fund: 0 },
  { fund_id: 1005, fund_name: 'Nippon India Small Cap Fund',       fund_type: 'EQ', is_default_fund: 0 },
];

export const MOCK_INDICES = [
  { index_id: 1,  index_name: 'Nifty 500 Multicap 50:25:25',    index_short_name: 'NIFTY500 MULTICAP 50:25:25' },
  { index_id: 2,  index_name: 'NIFTY 50',                       index_short_name: 'NIFTY50'                    },
  { index_id: 3,  index_name: 'NIFTY 500',                      index_short_name: 'NIFTY500'                   },
  { index_id: 4,  index_name: 'NIFTY MIDCAP 150',               index_short_name: 'NIFTYMID150'                },
  { index_id: 5,  index_name: 'BSE SENSEX',                     index_short_name: 'SENSEX'                     },
];

export const MOCK_FUND_PARAMS = {
  effective_date: '2025-04-17',
  index_id: 1,
};

export const MOCK_FUND_RETURN = {
  fund_1d:  0.0079,   // ~0.79% — from sector header aggregates
  index_1d: 0.0061,   // ~0.61% benchmark
};

export const MOCK_LAYOUTS = [
  {
    layout_id: 1,
    layout_name: 'Default View',
    widget_id: 19,
    is_default_layout: 1,
    layout_state: null,
  },
];
