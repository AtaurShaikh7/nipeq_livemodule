"""
analysis/returns.py
Core Shariah compliance logic:
  - classify_holdings: marks each holding as compliant or not
  - reweight: filters compliant holdings and proportionally reweights to 100%
"""

# Sectors that are non-compliant under Shariah rules
HARAM_SECTORS = [
    "Banking",
    "Insurance",
    "NBFC",
    "Alcohol",
    "Gambling",
    "Tobacco",
]


def classify_holdings(holdings: list) -> list:
    """
    Add a 'compliant' field (True/False) to each holding dict.
    A holding is non-compliant if its sector is in HARAM_SECTORS.

    Args:
        holdings: list of dicts with keys: name, sector, weight

    Returns:
        Same list with an extra 'compliant' key on each dict.
    """
    result = []
    for holding in holdings:
        is_compliant = holding["sector"] not in HARAM_SECTORS
        result.append({**holding, "compliant": is_compliant})
    return result


def reweight(holdings: list) -> list:
    """
    Filter only compliant holdings and reweight them proportionally to sum to 100%.

    Formula:
        new_weight = (original_weight / total_compliant_weight) * 100

    Args:
        holdings: list of dicts that already have the 'compliant' field

    Returns:
        List of compliant holdings only, each with an added 'new_weight' field.
    """
    compliant = [h for h in holdings if h["compliant"]]

    total_compliant_weight = sum(h["weight"] for h in compliant)

    reweighted = []
    for h in compliant:
        new_weight = (h["weight"] / total_compliant_weight) * 100
        reweighted.append({**h, "new_weight": round(new_weight, 2)})

    return reweighted
