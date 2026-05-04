-- Stored procedure to return fund holding report for a given date (p_effdate).
-- Call from C# or: VARIABLE rc REFCURSOR; EXEC FINAL_HOLDINGS_REPORT(TO_DATE('2026-02-12','YYYY-MM-DD'), :rc); PRINT rc;
CREATE OR REPLACE PROCEDURE FINAL_HOLDINGS_REPORT(
    p_effdate IN DATE,
    out_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN out_cursor FOR
    WITH 
    holdings_union AS (
        SELECT 
            fh1.fund_id, 
            fh1.effective_date, 
            fh1.security_code, 
            fh1.quantity, 
            fh1.mtm_value,
            fh1.option_position, 
            fh1.pur_value, 
            fh1.ammortised_book_cost, 
            fh1.accrued_interest
        FROM fund_holdings_LIVE fh1
        JOIN security_master sm1 ON sm1.security_code = fh1.security_code
        JOIN sectors sect1 ON sm1.sector_id = sect1.sector_id
        WHERE TRUNC(fh1.effective_date) = TRUNC(p_effdate)
          AND sect1.sector_id NOT IN (20)
        UNION ALL
        SELECT 
            fh2.fund_id,
            fh2.effective_date,
            'CASHEQ000001' AS security_code,
            SUM(fh2.quantity) AS quantity,
            SUM(fh2.mtm_value) AS mtm_value,
            MAX(fh2.option_position) AS option_position,
            SUM(fh2.pur_value) AS pur_value,
            SUM(fh2.ammortised_book_cost) AS ammortised_book_cost,
            SUM(fh2.accrued_interest) AS accrued_interest
        FROM fund_holdings_LIVE fh2
        JOIN security_master sm2 ON sm2.security_code = fh2.security_code
        JOIN sectors sect2 ON sm2.sector_id = sect2.sector_id
        WHERE TRUNC(fh2.effective_date) = TRUNC(p_effdate)
          AND sect2.sector_id IN (20)
        GROUP BY fh2.fund_id, fh2.effective_date, sect2.sector_id
    ),
    fund_aum AS (
        SELECT 
            fund_id, 
            SUM(mtm_value + NVL(accrued_interest,0)) AS fund_aum
        FROM fund_holdings
        WHERE TRUNC(effective_date) = TRUNC(p_effdate)
        GROUP BY fund_id
    ),
    filtered_funds AS (
        SELECT *
        FROM funds 
        WHERE fund_id NOT IN (57,61,73,72)
          AND fund_id NOT IN (
                SELECT fund_id 
                FROM funds 
                WHERE UPPER(fund_name) LIKE '%ETF%'
          )
          AND fund_id NOT IN (
                SELECT fund_id 
                FROM fund_user_mapping 
                WHERE login_id='70280867'
          )
    ),
    fund_nav AS (
        SELECT *
        FROM fund_nav_returns 
        WHERE TRUNC(effective_date) = TRUNC(p_effdate)
    ),
    sec_returns AS (
        SELECT *
        FROM security_returns
        WHERE TRUNC(effective_date) = TRUNC(p_effdate)
    ),
    idx_const AS (
        SELECT *
        FROM index_constituents
        WHERE TRUNC(effective_date) = TRUNC(p_effdate)
    )
    SELECT 
        fnd.effective_date AS HoldingDate,
        fnd.fund_id AS valueAtFundCode,
        fnd.fund_name AS SchemeName,
        fnd.fund_manager_name AS FundManagerName,
        fnd.index_name AS FundBenchmark, 
        fnd.fund_category AS TypeOfFund, 
        (fnd.fund_aum/10000000) AS AUMincr,
        fnd.security_code AS ValueAtScripCode,
        fnd.source_security_code AS ISIN,  
        fnd.security_name AS ScripName, 
        fnd.sector_name AS Sector,
        ROUND(NVL(idx.weights,0)*100, 6) AS ScriptWtInBenchMark, 
        ROUND(NVL(fnd.fundwt,0)*100, 6) AS ScriptWtInFund, 
        fnd.quantity AS Quantity,
        ROUND(NVL(fnd.ammortised_book_cost/fnd.quantity,0),6) AS BVinRs,
        ROUND(NVL(fnd.mtm_value/fnd.quantity,0),6) AS EODPriceinRs, 
        NVL(fnd.ammortised_book_cost,0)/10000000 AS BVcr,
        NVL(fnd.mtm_value,0)/10000000 AS MVcr,
        fnd.fnd1d AS FundRet_1D,
        fnd.fnd1w AS FundRet_1W,
        fnd.fnd1m AS FundRet_1M,
        fnd.fnd3m AS FundRet_3M,
        fnd.fnd1y AS FundRet_1Y,
        fnd.secret1d AS ScripRet_1D,
        fnd.secret1w AS ScripRet_1W,
        fnd.secret1m AS ScripRet_1M,
        fnd.secret3m AS ScripRet_3M,
        fnd.secret1y AS ScripRet_1Y,
        NVL(fnd.MCAP,0) AS MCAP
    FROM (
        SELECT 
            fh.effective_date,
            fh.fund_id, 
            f.fund_name,
            i.index_id,
            i.index_name,
            f.fund_category,
            bbisn.source_security_code,
            fh.security_code,
            CASE WHEN sect.sector_id=20 THEN sect.sector_name ELSE sm.security_name END AS security_name,
            sect.sector_name,
            (fh.mtm_value/aumfnd.fund_aum) AS fundwt,
            ROUND(aumfnd.fund_aum,6) AS fund_aum,
            f.fund_manager_name, 
            fh.quantity, 
            fh.ammortised_book_cost, 
            fh.mtm_value,
            secret.closep,
            secret.ret_1d * 100 AS secret1d, 
            secret.ret_5d*100 AS secret1w, 
            secret.ret_1m*100 AS secret1m, 
            secret.ret_3m*100 AS secret3m,
            secret.ret_1y*100 AS secret1Y,
            fndnav.ret_1d*100 AS fnd1d,
            fndnav.ret_5d*100 AS fnd1w,
            fndnav.ret_1m*100 AS fnd1m,
            fndnav.ret_3m*100 AS fnd3m,
            fndnav.ret_1y*100 AS fnd1y,
            secret.marketcap AS MCAP
        FROM holdings_union fh
        LEFT JOIN fund_aum aumfnd ON aumfnd.fund_id = fh.fund_id
        JOIN security_master sm ON sm.security_code = fh.security_code
        JOIN filtered_funds f ON f.fund_id = fh.fund_id
        JOIN sectors sect ON sm.sector_id = sect.sector_id
        JOIN indices i ON i.index_id = f.default_index_id
        LEFT JOIN security_code_bbisin_intmdt bbisn ON bbisn.bm_code = fh.security_code
        LEFT JOIN fund_nav fndnav ON fndnav.fund_id = fh.fund_id
        LEFT JOIN sec_returns secret ON secret.security_code = fh.security_code
        WHERE f.fund_id NOT IN (SELECT base_fund_id FROM normalized_funds)
    ) fnd
    LEFT JOIN idx_const idx
        ON idx.index_id = fnd.index_id AND idx.security_code = fnd.security_code
    ORDER BY fnd.fund_id, fnd.security_code;

END FINAL_HOLDINGS_REPORT;
/