-- ============================================================
-- NipEQ API Stored Procedures
-- Database: ValueAT_UAT_Nippon
-- Run in SSMS against ValueAT_UAT_Nippon
-- READ-ONLY on existing data tables. Only new SPs created.
-- ============================================================

USE ValueAT_UAT_Nippon;
GO

-- ============================================================
-- SP_API_LOGIN
-- ============================================================
IF OBJECT_ID('dbo.SP_API_LOGIN', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_LOGIN;
GO
CREATE PROCEDURE dbo.SP_API_LOGIN
    @login_id VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        user_id,
        login_id,
        password,
        first_name,
        last_name,
        role_id,
        is_active,
        client_id
    FROM dbo.user_master
    WHERE login_id = @login_id
      AND is_active = 1;
END
GO

-- ============================================================
-- SP_API_FUNDLIST
-- ============================================================
IF OBJECT_ID('dbo.SP_API_FUNDLIST', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_FUNDLIST;
GO
CREATE PROCEDURE dbo.SP_API_FUNDLIST
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        fm.fund_id,
        fm.fund_name,
        fm.short_name,
        fm.fund_type,
        fm.fund_base_currency,
        ISNULL(fmm.fund_manager_name, '') AS fund_manager_name,
        CAST(ISNULL(mfu.is_default_fund, 0) AS BIT) AS is_default_fund,
        ISNULL(mfi.index_id, -1)            AS default_index_id,
        ISNULL(im.index_name, 'No Benchmark') AS default_index_name,
        ISNULL(im.index_short_name, '')     AS default_index_short_name
    FROM dbo.mapping_fund_user mfu
    INNER JOIN dbo.fund_master fm ON fm.fund_id = mfu.fund_id
    LEFT  JOIN dbo.fund_manager_master fmm ON fmm.fund_manager_id = fm.fund_manager_id
    LEFT  JOIN dbo.mapping_fund_index mfi
           ON mfi.fund_id = fm.fund_id AND mfi.is_default_index = 1
    LEFT  JOIN dbo.index_master im ON im.index_id = mfi.index_id
    WHERE mfu.user_id = @user_id
    ORDER BY CAST(ISNULL(mfu.is_default_fund,0) AS BIT) DESC, fm.fund_name;
END
GO

-- ============================================================
-- SP_API_INDEXLIST
-- ============================================================
IF OBJECT_ID('dbo.SP_API_INDEXLIST', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_INDEXLIST;
GO
CREATE PROCEDURE dbo.SP_API_INDEXLIST
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        index_id,
        index_name,
        ISNULL(index_short_name, index_name) AS index_short_name
    FROM dbo.index_master
    WHERE ISNULL(active_inactive_flag, 1) = 1
      AND index_id > 0
    ORDER BY index_name;
END
GO

-- ============================================================
-- SP_API_FUND_PARAMS
-- ============================================================
IF OBJECT_ID('dbo.SP_API_FUND_PARAMS', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_FUND_PARAMS;
GO
CREATE PROCEDURE dbo.SP_API_FUND_PARAMS
    @fund_id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @eff_date  DATE;
    DECLARE @index_id  INT;
    DECLARE @index_name VARCHAR(250);
    DECLARE @index_short VARCHAR(50);

    SELECT @eff_date = MAX(effective_date)
    FROM dbo.fund_holdings
    WHERE fund_id = @fund_id;

    SELECT TOP 1
        @index_id    = mfi.index_id,
        @index_name  = ISNULL(im.index_name, 'No Benchmark'),
        @index_short = ISNULL(im.index_short_name, '')
    FROM dbo.mapping_fund_index mfi
    LEFT JOIN dbo.index_master im ON im.index_id = mfi.index_id
    WHERE mfi.fund_id = @fund_id AND mfi.is_default_index = 1;

    SELECT
        @eff_date                               AS effective_date,
        ISNULL(@index_id, -1)                   AS index_id,
        ISNULL(@index_name, 'No Benchmark')     AS index_name,
        ISNULL(@index_short, '')                AS index_short_name;
END
GO

-- ============================================================
-- SP_API_LIVE_PORTFOLIO
-- Main portfolio grid SP. Mirrors Oracle SP_FE_LIVE in T-SQL.
-- Uses dbo schema tables only.
-- ============================================================
IF OBJECT_ID('dbo.SP_API_LIVE_PORTFOLIO', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_LIVE_PORTFOLIO;
GO
CREATE PROCEDURE dbo.SP_API_LIVE_PORTFOLIO
    @fund_id  INT,
    @index_id INT,
    @run_date DATE,
    @user_id  INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Effective date: latest holdings date <= run_date
    DECLARE @eff_date DATE;
    SELECT @eff_date = MAX(effective_date)
    FROM dbo.fund_holdings
    WHERE fund_id = @fund_id AND effective_date <= @run_date;

    IF @eff_date IS NULL RETURN;

    -- Total fund MTM (used as AUM proxy)
    DECLARE @fund_aum DECIMAL(25,4) = 0;
    SELECT @fund_aum = SUM(ISNULL(mtm_value, 0))
    FROM dbo.fund_holdings
    WHERE fund_id = @fund_id AND effective_date = @eff_date;

    -- Index short name
    DECLARE @index_short VARCHAR(50) = '';
    SELECT @index_short = ISNULL(index_short_name, index_name)
    FROM dbo.index_master WHERE index_id = @index_id;

    -- Latest report_id for this fund on eff_date
    DECLARE @report_id INT;
    SELECT TOP 1 @report_id = report_id
    FROM dbo.report_references
    WHERE fund_id = @fund_id AND to_date = @eff_date
    ORDER BY report_id DESC;

    -- Collect rolling report_ids for multi-period returns
    DECLARE @report_ids TABLE (report_id INT, to_date DATE, rn INT);
    INSERT INTO @report_ids
    SELECT report_id, to_date, ROW_NUMBER() OVER (ORDER BY to_date DESC) AS rn
    FROM dbo.report_references
    WHERE fund_id = @fund_id AND to_date <= @eff_date;

    -- YTD start date
    DECLARE @ytd_start DATE = DATEFROMPARTS(YEAR(@eff_date), 1, 1);

    -- Log activity
    INSERT INTO dbo.user_access_logs (activity_time, user_id, page_id, fund_id, from_date, to_date)
    VALUES (GETDATE(), @user_id, 19, @fund_id, @eff_date, @eff_date);

    -- --------------------------------------------------------
    -- Build sector lookup (latest mapping per security)
    -- --------------------------------------------------------
    ;WITH

    SECTOR_MAP AS (
        SELECT security_id, MAX(level_value_id) AS level_value_id
        FROM dbo.mapping_security_level
        WHERE level_id = 1
        GROUP BY security_id
    ),

    -- Fund holdings with computed weight
    FH AS (
        SELECT
            fh.security_id,
            fh.quantity,
            fh.mtm_value,
            CASE WHEN @fund_aum > 0 THEN fh.mtm_value / @fund_aum ELSE ISNULL(fh.weight,0) END AS weight,
            fh.ammortised_book_cost,
            ISNULL(fh.long_short_position, 'L') AS position
        FROM dbo.fund_holdings fh
        WHERE fh.fund_id = @fund_id AND fh.effective_date = @eff_date
    ),

    -- Index constituents
    IC AS (
        SELECT security_id, weights
        FROM dbo.index_constituents
        WHERE index_id = @index_id AND effective_date = @eff_date
    ),

    -- Full outer join: fund + index
    ALLD AS (
        SELECT
            COALESCE(fh.security_id, ic.security_id) AS security_id,
            fh.quantity,
            fh.mtm_value,
            fh.weight        AS fund_weight,
            fh.ammortised_book_cost,
            fh.position,
            ic.weights       AS index_weight
        FROM FH fh
        FULL OUTER JOIN IC ic ON fh.security_id = ic.security_id
    ),

    -- 1D returns
    R1D AS (
        SELECT security_id, portfolio_return AS ret_1d, portfolio_weight
        FROM dbo.fund_security_returns
        WHERE fund_id = @fund_id AND report_id = @report_id
    ),
    R5D AS (
        SELECT fsr.security_id,
               EXP(SUM(LOG(CASE WHEN fsr.portfolio_return <= -1 THEN 0.000001 ELSE 1 + fsr.portfolio_return END))) - 1 AS ret_5d
        FROM dbo.fund_security_returns fsr
        JOIN @report_ids ri ON fsr.report_id = ri.report_id
        WHERE fsr.fund_id = @fund_id AND ri.rn <= 5
        GROUP BY fsr.security_id
    ),
    R1M AS (
        SELECT fsr.security_id,
               EXP(SUM(LOG(CASE WHEN fsr.portfolio_return <= -1 THEN 0.000001 ELSE 1 + fsr.portfolio_return END))) - 1 AS ret_1m
        FROM dbo.fund_security_returns fsr
        JOIN @report_ids ri ON fsr.report_id = ri.report_id
        WHERE fsr.fund_id = @fund_id AND ri.rn <= 21
        GROUP BY fsr.security_id
    ),
    R3M AS (
        SELECT fsr.security_id,
               EXP(SUM(LOG(CASE WHEN fsr.portfolio_return <= -1 THEN 0.000001 ELSE 1 + fsr.portfolio_return END))) - 1 AS ret_3m
        FROM dbo.fund_security_returns fsr
        JOIN @report_ids ri ON fsr.report_id = ri.report_id
        WHERE fsr.fund_id = @fund_id AND ri.rn <= 63
        GROUP BY fsr.security_id
    ),
    R6M AS (
        SELECT fsr.security_id,
               EXP(SUM(LOG(CASE WHEN fsr.portfolio_return <= -1 THEN 0.000001 ELSE 1 + fsr.portfolio_return END))) - 1 AS ret_6m
        FROM dbo.fund_security_returns fsr
        JOIN @report_ids ri ON fsr.report_id = ri.report_id
        WHERE fsr.fund_id = @fund_id AND ri.rn <= 126
        GROUP BY fsr.security_id
    ),
    R1Y AS (
        SELECT fsr.security_id,
               EXP(SUM(LOG(CASE WHEN fsr.portfolio_return <= -1 THEN 0.000001 ELSE 1 + fsr.portfolio_return END))) - 1 AS ret_1y
        FROM dbo.fund_security_returns fsr
        JOIN @report_ids ri ON fsr.report_id = ri.report_id
        WHERE fsr.fund_id = @fund_id AND ri.rn <= 252
        GROUP BY fsr.security_id
    ),
    RYTD AS (
        SELECT fsr.security_id,
               EXP(SUM(LOG(CASE WHEN fsr.portfolio_return <= -1 THEN 0.000001 ELSE 1 + fsr.portfolio_return END))) - 1 AS ret_ytd
        FROM dbo.fund_security_returns fsr
        JOIN dbo.report_references rr ON fsr.report_id = rr.report_id
        WHERE fsr.fund_id = @fund_id
          AND rr.to_date >= @ytd_start
          AND rr.to_date <= @eff_date
        GROUP BY fsr.security_id
    )

    -- ---- Security rows ----
    SELECT
        UPPER(ISNULL(lv.level_value_name, 'UNKNOWN'))   AS sector,
        LEFT(ISNULL(sm.security_name, ''), 60)           AS security_name,
        ISNULL(sm.isin_number, '')                        AS isin_code,
        CASE
            WHEN alld.fund_weight IS NULL AND alld.index_weight IS NOT NULL THEN @index_short
            WHEN im2.instrument_name LIKE '%Future%'    THEN 'FUT'
            WHEN im2.instrument_name LIKE '%Option%'    THEN 'OPT'
            WHEN sm.instrument_type_id NOT IN (1) AND sm.instrument_type_id IS NOT NULL THEN 'OTH'
            ELSE 'No'
        END                                              AS index_flag,
        CASE WHEN alld.fund_weight IS NOT NULL THEN 'FUND' ELSE '' END AS fund_flag,
        CASE WHEN alld.position = 'S'
             THEN -1 * ISNULL(alld.quantity, 0)
             ELSE ISNULL(alld.quantity, 0) END           AS fund_qty,
        ISNULL(cp.closep, 0)                              AS cmp,
        ROUND(ISNULL(r1d.ret_1d, 0) * 100, 4)           AS ret_1d,
        ROUND(ISNULL(r5d.ret_5d, 0) * 100, 4)           AS ret_5d,
        ROUND(ISNULL(r1m.ret_1m, 0) * 100, 4)           AS ret_1m,
        ROUND(ISNULL(r3m.ret_3m, 0) * 100, 4)           AS ret_3m,
        ROUND(ISNULL(r6m.ret_6m, 0) * 100, 4)           AS ret_6m,
        ROUND(ISNULL(r1y.ret_1y, 0) * 100, 4)           AS ret_1y,
        ROUND(ISNULL(rytd.ret_ytd, 0) * 100, 4)         AS ret_ytd,
        CASE WHEN alld.mtm_value IS NOT NULL
             THEN ROUND(alld.mtm_value / 10000000.0, 2) ELSE NULL END AS fund_mtm,
        CASE WHEN alld.mtm_value IS NOT NULL
             THEN ROUND(alld.mtm_value * ISNULL(r1d.ret_1d,0) / 10000000.0, 2) ELSE NULL END AS fund_mtm_chg,
        CASE WHEN alld.fund_weight IS NOT NULL
             THEN ROUND(alld.fund_weight * 100, 4) ELSE NULL END      AS fund_wts,
        CASE WHEN alld.index_weight IS NOT NULL
             THEN ROUND(alld.index_weight * 100, 4) ELSE NULL END     AS index_wts,
        ROUND(@fund_aum / 10000000.0, 0)                              AS fund_aum,
        ISNULL(df.marketcap, 0)                                       AS mcap,
        ISNULL(df.marketcap_bucket, 'NA')                             AS mcap_bucket,
        ISNULL(alld.ammortised_book_cost, 0)                          AS book_value,
        ISNULL(df.avg_volume, 0)                                      AS avg_vol,
        ''                                                            AS rating,
        0                                                             AS is_sector_row
    FROM ALLD alld
    INNER JOIN dbo.security_master sm ON sm.security_id = alld.security_id
    LEFT  JOIN dbo.instrument_master im2 ON im2.instrument_id = sm.instrument_type_id
    LEFT  JOIN SECTOR_MAP sec_m ON sec_m.security_id = alld.security_id
    LEFT  JOIN dbo.level_value_master lv ON lv.level_value_id = sec_m.level_value_id
    LEFT  JOIN dbo.security_closeprices cp
           ON cp.security_id = alld.security_id AND cp.price_date = @eff_date AND cp.exchange_id = 1
    LEFT  JOIN dbo.security_dynamic_factors df
           ON df.security_id = alld.security_id AND df.effective_date = @eff_date
    LEFT  JOIN R1D r1d   ON r1d.security_id   = alld.security_id
    LEFT  JOIN R5D r5d   ON r5d.security_id   = alld.security_id
    LEFT  JOIN R1M r1m   ON r1m.security_id   = alld.security_id
    LEFT  JOIN R3M r3m   ON r3m.security_id   = alld.security_id
    LEFT  JOIN R6M r6m   ON r6m.security_id   = alld.security_id
    LEFT  JOIN R1Y r1y   ON r1y.security_id   = alld.security_id
    LEFT  JOIN RYTD rytd ON rytd.security_id  = alld.security_id

    UNION ALL

    -- ---- Sector summary rows ----
    SELECT
        UPPER(ISNULL(lv2.level_value_name, 'UNKNOWN')) AS sector,
        UPPER(ISNULL(lv2.level_value_name, 'UNKNOWN')) AS security_name,
        'Sector'    AS isin_code,
        NULL        AS index_flag,
        CASE WHEN SUM(ISNULL(fh2.weight,0)) > 0 THEN 'FUND' ELSE NULL END AS fund_flag,
        NULL AS fund_qty,
        NULL AS cmp,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(sr.portfolio_return,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_1d,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(sr5.ret_5d,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_5d,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(sr1m.ret_1m,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_1m,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(sr3m.ret_3m,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_3m,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(sr6m.ret_6m,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_6m,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(sr1y.ret_1y,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_1y,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(srytd.ret_ytd,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_ytd,
        CASE WHEN SUM(ISNULL(fh2.mtm_value,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(fh2.mtm_value,0))/10000000.0,0) END AS fund_mtm,
        CASE WHEN SUM(ISNULL(fh2.mtm_value,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(fh2.mtm_value,0))
                  * ISNULL(SUM(ISNULL(sr.portfolio_return,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0),0)
                  /10000000.0, 2) END                     AS fund_mtm_chg,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL
             ELSE ROUND(SUM(ISNULL(fh2.weight,0))*100,2) END AS fund_wts,
        NULL AS index_wts,
        NULL AS fund_aum,
        NULL AS mcap,
        'Sector' AS mcap_bucket,
        0 AS book_value,
        0 AS avg_vol,
        '' AS rating,
        1  AS is_sector_row
    FROM dbo.fund_holdings fh2
    INNER JOIN dbo.security_master sm2 ON sm2.security_id = fh2.security_id
    LEFT JOIN SECTOR_MAP sec_m2 ON sec_m2.security_id = fh2.security_id
    LEFT JOIN dbo.level_value_master lv2 ON lv2.level_value_id = sec_m2.level_value_id
    LEFT JOIN dbo.fund_security_returns sr
           ON sr.security_id = fh2.security_id AND sr.fund_id = @fund_id AND sr.report_id = @report_id
    LEFT JOIN (
        SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_5d
        FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id
        WHERE fsr.fund_id=@fund_id AND ri.rn<=5 GROUP BY fsr.security_id
    ) sr5 ON sr5.security_id = fh2.security_id
    LEFT JOIN (
        SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_1m
        FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id
        WHERE fsr.fund_id=@fund_id AND ri.rn<=21 GROUP BY fsr.security_id
    ) sr1m ON sr1m.security_id = fh2.security_id
    LEFT JOIN (
        SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_3m
        FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id
        WHERE fsr.fund_id=@fund_id AND ri.rn<=63 GROUP BY fsr.security_id
    ) sr3m ON sr3m.security_id = fh2.security_id
    LEFT JOIN (
        SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_6m
        FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id
        WHERE fsr.fund_id=@fund_id AND ri.rn<=126 GROUP BY fsr.security_id
    ) sr6m ON sr6m.security_id = fh2.security_id
    LEFT JOIN (
        SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_1y
        FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id
        WHERE fsr.fund_id=@fund_id AND ri.rn<=252 GROUP BY fsr.security_id
    ) sr1y ON sr1y.security_id = fh2.security_id
    LEFT JOIN (
        SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_ytd
        FROM dbo.fund_security_returns fsr
        JOIN dbo.report_references rr ON fsr.report_id=rr.report_id
        WHERE fsr.fund_id=@fund_id AND rr.to_date>=@ytd_start AND rr.to_date<=@eff_date
        GROUP BY fsr.security_id
    ) srytd ON srytd.security_id = fh2.security_id
    WHERE fh2.fund_id = @fund_id AND fh2.effective_date = @eff_date
    GROUP BY lv2.level_value_name

    ORDER BY sector, is_sector_row DESC, security_name;
END
GO

-- ============================================================
-- SP_API_LIVE_PRICES
-- ============================================================
IF OBJECT_ID('dbo.SP_API_LIVE_PRICES', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_LIVE_PRICES;
GO
CREATE PROCEDURE dbo.SP_API_LIVE_PRICES
    @isin_list NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
    SELECT RTRIM(LTRIM(isincode)) AS isin_code,
           ISNULL(nse_live_price,0) AS nse_live_price,
           ISNULL(bse_live_price,0) AS bse_live_price,
           ISNULL(nse_marketcap,0)  AS nse_marketcap,
           ISNULL(bse_marketcap,0)  AS bse_marketcap,
           ISNULL(nse_per_change,0) AS nse_per_change,
           ISNULL(bse_per_change,0) AS bse_per_change,
           CONVERT(VARCHAR(20),PriceDate,106) AS price_date
    FROM [Fundoo_Server].[Valuefy_CorporateContent].[dbo].[ValueAT_EQUITYLIVEPRICES]
    WHERE RTRIM(LTRIM(isincode)) IN (' + @isin_list + N')
    UNION ALL
    SELECT RTRIM(LTRIM(isincode)),
           ISNULL(nse_live_price,0), ISNULL(bse_live_price,0),
           ISNULL(nse_marketcap,0),  ISNULL(bse_marketcap,0),
           ISNULL(nse_per_change,0), ISNULL(bse_per_change,0),
           CONVERT(VARCHAR(20),PriceDate,106)
    FROM [Fundoo_Server].[Valuefy_CorporateContent].[dbo].[ValueAT_FNOLIVEEODPRICES]
    WHERE RTRIM(LTRIM(isincode)) IN (' + @isin_list + N')';
    EXEC sp_executesql @sql;
END
GO

-- ============================================================
-- SP_API_FUND_IDX_RETURN
-- ============================================================
IF OBJECT_ID('dbo.SP_API_FUND_IDX_RETURN', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_FUND_IDX_RETURN;
GO
CREATE PROCEDURE dbo.SP_API_FUND_IDX_RETURN
    @fund_id  INT,
    @index_id INT,
    @eff_date DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @report_id INT;
    SELECT TOP 1 @report_id = report_id
    FROM dbo.report_references
    WHERE fund_id = @fund_id AND to_date = @eff_date
    ORDER BY report_id DESC;

    DECLARE @fund_1d  DECIMAL(18,8) = 0;
    DECLARE @index_1d DECIMAL(18,8) = 0;

    SELECT @fund_1d = SUM(portfolio_return * portfolio_weight)
    FROM dbo.fund_security_returns
    WHERE fund_id = @fund_id AND report_id = @report_id;

    SELECT @index_1d = SUM(benchmark_return * benchmark_weight)
    FROM dbo.index_security_returns
    WHERE index_id = @index_id AND report_id = @report_id;

    SELECT
        ROUND(ISNULL(@fund_1d,0)*100,4)  AS fund_1d,
        ROUND(ISNULL(@index_1d,0)*100,4) AS index_1d;
END
GO

-- ============================================================
-- SP_API_LAYOUTS
-- ============================================================
IF OBJECT_ID('dbo.SP_API_LAYOUTS', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_LAYOUTS;
GO
CREATE PROCEDURE dbo.SP_API_LAYOUTS
    @user_id   INT,
    @widget_id INT = 19
AS
BEGIN
    SET NOCOUNT ON;
    SELECT layout_id, layout_name, layout_state, layout_string,
           bucket_string, is_default_layout, is_global, created_on, modified_on
    FROM dbo.layout_master
    WHERE (user_id = @user_id OR is_global = 1)
      AND ISNULL(widget_id, @widget_id) = @widget_id
    ORDER BY ISNULL(is_default_layout,0) DESC, layout_name;
END
GO

-- ============================================================
-- SP_API_SAVE_LAYOUT
-- ============================================================
IF OBJECT_ID('dbo.SP_API_SAVE_LAYOUT', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_SAVE_LAYOUT;
GO
CREATE PROCEDURE dbo.SP_API_SAVE_LAYOUT
    @user_id      INT,
    @widget_id    INT = 19,
    @layout_name  NVARCHAR(250),
    @layout_state NVARCHAR(MAX),
    @layout_string NVARCHAR(MAX) = NULL,
    @is_default   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @is_default = 1
        UPDATE dbo.layout_master
        SET is_default_layout = 0
        WHERE user_id = @user_id AND widget_id = @widget_id AND is_default_layout = 1;

    INSERT INTO dbo.layout_master
        (user_id, widget_id, layout_name, layout_state, layout_string, is_default_layout, is_global, created_on, modified_on)
    VALUES
        (@user_id, @widget_id, @layout_name, @layout_state, @layout_string, @is_default, 0, GETDATE(), GETDATE());

    SELECT SCOPE_IDENTITY() AS layout_id;
END
GO

-- ============================================================
-- SP_API_UPDATE_LAYOUT
-- ============================================================
IF OBJECT_ID('dbo.SP_API_UPDATE_LAYOUT', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_UPDATE_LAYOUT;
GO
CREATE PROCEDURE dbo.SP_API_UPDATE_LAYOUT
    @layout_id    INT,
    @user_id      INT,
    @layout_name  NVARCHAR(250) = NULL,
    @layout_state NVARCHAR(MAX) = NULL,
    @layout_string NVARCHAR(MAX) = NULL,
    @is_default   BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @is_default = 1
    BEGIN
        DECLARE @wid INT;
        SELECT @wid = widget_id FROM dbo.layout_master WHERE layout_id = @layout_id;
        UPDATE dbo.layout_master SET is_default_layout = 0
        WHERE user_id = @user_id AND widget_id = @wid AND is_default_layout = 1;
    END
    UPDATE dbo.layout_master SET
        layout_name   = ISNULL(@layout_name, layout_name),
        layout_state  = ISNULL(@layout_state, layout_state),
        layout_string = ISNULL(@layout_string, layout_string),
        is_default_layout = ISNULL(@is_default, is_default_layout),
        modified_on   = GETDATE()
    WHERE layout_id = @layout_id AND user_id = @user_id;
    SELECT @@ROWCOUNT AS rows_affected;
END
GO

-- ============================================================
-- SP_API_LOG_ACTIVITY
-- ============================================================
IF OBJECT_ID('dbo.SP_API_LOG_ACTIVITY', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_API_LOG_ACTIVITY;
GO
CREATE PROCEDURE dbo.SP_API_LOG_ACTIVITY
    @user_id   INT,
    @page_id   INT = 19,
    @fund_id   INT = NULL,
    @from_date DATE = NULL,
    @to_date   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.user_access_logs (activity_time, user_id, page_id, fund_id, from_date, to_date)
    VALUES (GETDATE(), @user_id, @page_id, @fund_id, @from_date, @to_date);
END
GO

PRINT 'All NipEQ API stored procedures created successfully.';
GO
