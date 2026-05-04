export interface Fund {
  fund_id: number;
  fund_name: string;
  short_name: string;
  fund_type: string;
  is_default_fund: boolean;
  default_index_id: number | null;
}

export interface Index {
  index_id: number;
  index_name: string;
  index_short_name: string;
}

export interface FundParams {
  effective_date: string;
  index_id: number | null;
  index_name: string;
  index_short_name: string;
}
