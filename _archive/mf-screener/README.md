# Shariah Fund Decomposer

A tool that takes any mutual fund, removes non-Shariah-compliant
holdings (banking, insurance, NBFC, alcohol etc.), and reweights
the remaining securities proportionally.

## Run locally

```bash
pip install -r requirements.txt
streamlit run app.py
```

## Phase 2 (coming later)
- Real fund holdings via AMFI / mfapi.in API
- Zerodha API integration for automatic replication
- Weekly auto-refresh when fund updates holdings
