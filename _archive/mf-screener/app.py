"""
app.py
Shariah Fund Decomposer — Main Streamlit App

Flow:
  1. User types a fund name and clicks Analyse
  2. App loads sample holdings (Phase 1) / real API data (Phase 2)
  3. Each holding is classified as Shariah-compliant or not
  4. Non-compliant holdings are removed; remaining ones are reweighted to 100%
  5. UI shows: metric cards, two-column table, pie chart, disclaimer
"""

import streamlit as st
import pandas as pd
import plotly.express as px

from data.fetch_nav import get_fund_holdings
from analysis.returns import classify_holdings, reweight

# ─── Page config ─────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Shariah Fund Decomposer",
    page_icon="☪️",
    layout="wide",
)

# ─── Title ────────────────────────────────────────────────────────────────────
st.title("☪️ Shariah Fund Decomposer")
st.caption("Enter any mutual fund name to see a Shariah-compliant version of its portfolio.")

# ─── Element 1: Search ───────────────────────────────────────────────────────
fund_name = st.text_input(
    label="Enter fund name",
    placeholder="e.g. Parag Parikh FlexiCap",
)

analyse_clicked = st.button("Analyse", type="primary")

# Only run analysis after the button is clicked
if analyse_clicked:

    if not fund_name.strip():
        st.warning("Please enter a fund name first.")
        st.stop()

    # ── Load and process data ─────────────────────────────────────────────────
    raw_holdings = get_fund_holdings(fund_name)               # Step 1: fetch
    classified   = classify_holdings(raw_holdings)            # Step 2: classify
    shariah_port = reweight(classified)                       # Step 3: reweight

    # Convert to DataFrames for display
    df_all     = pd.DataFrame(classified)
    df_shariah = pd.DataFrame(shariah_port)

    # ── Element 2: Metric cards ───────────────────────────────────────────────
    total_count     = len(df_all)
    compliant_count = df_all["compliant"].sum()
    removed_count   = total_count - compliant_count

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Holdings",          total_count)
    col2.metric("Shariah-Compliant",        compliant_count)
    col3.metric("Removed",                 removed_count)
    col4.metric("Your Allocation",         "100%")

    st.divider()

    # ── Element 3: Two-column table ───────────────────────────────────────────
    left_col, right_col = st.columns(2)

    with left_col:
        st.subheader("📋 Full Fund Holdings")
        st.caption("All securities — original weights and compliance status")

        # Add a readable compliance column with icons
        df_display = df_all[["name", "sector", "weight", "compliant"]].copy()
        df_display["status"] = df_display["compliant"].apply(
            lambda x: "✅ Compliant" if x else "❌ Removed"
        )
        df_display = df_display.drop(columns=["compliant"])
        df_display.columns = ["Security", "Sector", "Weight (%)", "Status"]

        st.dataframe(df_display, use_container_width=True, hide_index=True)

    with right_col:
        st.subheader("☪️ Your Shariah Portfolio")
        st.caption("Only compliant securities — reweighted proportionally to 100%")

        df_shariah_display = df_shariah[["name", "sector", "weight", "new_weight"]].copy()
        df_shariah_display.columns = ["Security", "Sector", "Original Weight (%)", "New Weight (%)"]

        st.dataframe(df_shariah_display, use_container_width=True, hide_index=True)

    st.divider()

    # ── Element 4: Pie chart ──────────────────────────────────────────────────
    st.subheader("📊 Sector Breakdown — Shariah Portfolio")

    # Group by sector, sum the reweighted allocations
    sector_data = (
        df_shariah.groupby("sector")["new_weight"]
        .sum()
        .reset_index()
        .rename(columns={"sector": "Sector", "new_weight": "Weight (%)"})
    )

    fig = px.pie(
        sector_data,
        names="Sector",
        values="Weight (%)",
        hole=0.3,  # donut-style looks cleaner
    )
    fig.update_traces(textposition="inside", textinfo="percent+label")
    fig.update_layout(showlegend=True, margin=dict(t=20, b=20))

    st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # ── Element 5: Disclaimer ─────────────────────────────────────────────────
    st.info(
        "**Disclaimer:** Removed securities have been excluded based on sector classification. "
        "Remaining weights have been proportionally reweighted to 100%. "
        "This is not investment advice."
    )
