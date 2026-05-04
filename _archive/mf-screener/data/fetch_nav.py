"""
data/fetch_nav.py
Data layer for fund holdings.

Phase 1: Returns hardcoded sample data for Parag Parikh FlexiCap.
Phase 2: Will call mfapi.in / AMFI API to fetch real fund holdings.
"""

# Hardcoded sample holdings — Parag Parikh FlexiCap
# Each entry: fund name, sector, weight (% of portfolio)
SAMPLE_HOLDINGS = [
    {"name": "ITC Ltd",             "sector": "FMCG",        "weight": 8.2},
    {"name": "Infosys Ltd",         "sector": "Technology",  "weight": 7.1},
    {"name": "TCS",                 "sector": "Technology",  "weight": 4.9},
    {"name": "Bajaj Auto",          "sector": "Auto",        "weight": 5.4},
    {"name": "HUL",                 "sector": "FMCG",        "weight": 4.1},
    {"name": "Sun Pharma",          "sector": "Pharma",      "weight": 3.8},
    {"name": "Wipro",               "sector": "Technology",  "weight": 3.5},
    {"name": "Asian Paints",        "sector": "Chemicals",   "weight": 3.2},
    {"name": "Maruti Suzuki",       "sector": "Auto",        "weight": 3.0},
    {"name": "Dr Reddys",           "sector": "Pharma",      "weight": 2.9},
    {"name": "HDFC Bank",           "sector": "Banking",     "weight": 6.8},
    {"name": "ICICI Bank",          "sector": "Banking",     "weight": 5.1},
    {"name": "Axis Bank",           "sector": "Banking",     "weight": 3.9},
    {"name": "Kotak Mahindra Bank", "sector": "Banking",     "weight": 3.3},
    {"name": "SBI Life Insurance",  "sector": "Insurance",   "weight": 3.2},
    {"name": "HDFC Life",           "sector": "Insurance",   "weight": 2.8},
    {"name": "Bajaj Finance",       "sector": "NBFC",        "weight": 4.2},
    {"name": "Muthoot Finance",     "sector": "NBFC",        "weight": 2.1},
    {"name": "United Spirits",      "sector": "Alcohol",     "weight": 1.8},
    {"name": "Pidilite Industries", "sector": "Chemicals",   "weight": 2.5},
    {"name": "Titan Company",       "sector": "Consumer",    "weight": 2.3},
    {"name": "Nestle India",        "sector": "FMCG",        "weight": 2.1},
    {"name": "Tata Motors",         "sector": "Auto",        "weight": 1.9},
    {"name": "L&T",                 "sector": "Engineering", "weight": 1.8},
    {"name": "Power Grid",          "sector": "Utilities",   "weight": 1.5},
]


def get_fund_holdings(fund_name: str) -> list:
    """
    Return holdings for a given fund name.

    Phase 1: Ignores fund_name and returns the hardcoded sample.
    Phase 2: Will use fund_name to search mfapi.in and return real data.

    Args:
        fund_name: Name of the mutual fund entered by the user.

    Returns:
        List of holding dicts with keys: name, sector, weight.
    """
    # Phase 2: replace this with an API call using fund_name
    return SAMPLE_HOLDINGS
