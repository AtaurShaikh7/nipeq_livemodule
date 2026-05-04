ALTER PROCEDURE dbo.SP_API_LIVE_PORTFOLIO
    @fund_id  INT,
    @index_id INT,
    @run_date DATE,
    @user_id  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @eff_date DATE;
    SELECT @eff_date = MAX(effective_date)
    FROM dbo.fund_holdings
    WHERE fund_id = @fund_id AND effective_date <= @run_date;
    IF @eff_date IS NULL RETURN;

    DECLARE @fund_aum DECIMAL(25,4) = 0;
    SELECT @fund_aum = SUM(ISNULL(mtm_value, 0))
    FROM dbo.fund_holdings
    WHERE fund_id = @fund_id AND effective_date = @eff_date;

    DECLARE @index_short VARCHAR(50) = '';
    SELECT @index_short = ISNULL(index_short_name, index_name)
    FROM dbo.index_master WHERE index_id = @index_id;

    DECLARE @report_id INT;
    SELECT TOP 1 @report_id = report_id
    FROM dbo.report_references
    WHERE fund_id = @fund_id AND to_date = @eff_date
    ORDER BY report_id DESC;

    DECLARE @report_ids TABLE (report_id INT, to_date DATE, rn INT);
    INSERT INTO @report_ids
    SELECT report_id, to_date, ROW_NUMBER() OVER (ORDER BY to_date DESC)
    FROM dbo.report_references
    WHERE fund_id = @fund_id AND to_date <= @eff_date;

    DECLARE @ytd_start DATE = DATEFROMPARTS(YEAR(@eff_date), 1, 1);

    INSERT INTO dbo.user_access_logs (activity_time, user_id, page_id, fund_id, from_date, to_date)
    VALUES (GETDATE(), @user_id, 19, @fund_id, @eff_date, @eff_date);

    ;WITH
    SECTOR_MAP AS (
        SELECT security_id, MAX(level_value_id) AS level_value_id
        FROM dbo.mapping_security_level WHERE level_id = 1
        GROUP BY security_id
    ),
    SIZE_MAP AS (
        SELECT security_id, MAX(level_value_id) AS level_value_id
        FROM dbo.mapping_security_level WHERE level_id = 5
        GROUP BY security_id
    ),
    FH AS (
        SELECT fh.security_id, fh.quantity, fh.mtm_value,
               CASE WHEN @fund_aum > 0 THEN fh.mtm_value / @fund_aum ELSE ISNULL(fh.weight,0) END AS weight,
               fh.ammortised_book_cost,
               ISNULL(fh.long_short_position, 'L') AS position
        FROM dbo.fund_holdings fh
        WHERE fh.fund_id = @fund_id AND fh.effective_date = @eff_date
    ),
    IC AS (
        SELECT security_id, weights
        FROM dbo.index_constituents
        WHERE index_id = @index_id AND effective_date = @eff_date
    ),
    ALLD AS (
        SELECT COALESCE(fh.security_id, ic.security_id) AS security_id,
               fh.quantity, fh.mtm_value, fh.weight AS fund_weight,
               fh.ammortised_book_cost, fh.position, ic.weights AS index_weight
        FROM FH fh FULL OUTER JOIN IC ic ON fh.security_id = ic.security_id
    ),
    R1D  AS (SELECT security_id, portfolio_return AS ret_1d FROM dbo.fund_security_returns WHERE fund_id=@fund_id AND report_id=@report_id),
    R5D  AS (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_5d FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=5 GROUP BY fsr.security_id),
    R1M  AS (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_1m FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=21 GROUP BY fsr.security_id),
    R3M  AS (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_3m FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=63 GROUP BY fsr.security_id),
    R6M  AS (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_6m FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=126 GROUP BY fsr.security_id),
    R1Y  AS (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_1y FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=252 GROUP BY fsr.security_id),
    RYTD AS (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_ytd FROM dbo.fund_security_returns fsr JOIN dbo.report_references rr ON fsr.report_id=rr.report_id WHERE fsr.fund_id=@fund_id AND rr.to_date>=@ytd_start AND rr.to_date<=@eff_date GROUP BY fsr.security_id)

    SELECT
        UPPER(ISNULL(lv.level_value_name, 'UNKNOWN'))        AS sector,
        LEFT(ISNULL(sm.security_name, ''), 60)                AS security_name,
        ISNULL(sm.isin_number, '')                            AS isin_code,
        CASE
            WHEN alld.fund_weight IS NULL AND alld.index_weight IS NOT NULL THEN @index_short
            WHEN im2.instrument_name LIKE '%Future%' THEN 'FUT'
            WHEN im2.instrument_name LIKE '%Option%' THEN 'OPT'
            WHEN sm.instrument_type_id NOT IN (1) AND sm.instrument_type_id IS NOT NULL THEN 'OTH'
            ELSE 'No'
        END                                                   AS index_flag,
        CASE WHEN alld.fund_weight IS NOT NULL THEN 'FUND' ELSE '' END AS fund_flag,
        CASE WHEN alld.position='S' THEN -1*ISNULL(alld.quantity,0) ELSE ISNULL(alld.quantity,0) END AS fund_qty,
        -- Live price: initially set from NSE close price; replaced every 15 min by SP_API_LIVE_PRICES
        ISNULL(cp.closep, ISNULL(cpb.closep, 0))             AS cmp,
        -- EOD Close price: NSE preferred, fallback to BSE
        ISNULL(cp.closep, ISNULL(cpb.closep, 0))             AS close_price,
        ROUND(ISNULL(r1d.ret_1d,0)*100,4)                    AS ret_1d,
        ROUND(ISNULL(r5d.ret_5d,0)*100,4)                    AS ret_5d,
        ROUND(ISNULL(r1m.ret_1m,0)*100,4)                    AS ret_1m,
        ROUND(ISNULL(r3m.ret_3m,0)*100,4)                    AS ret_3m,
        ROUND(ISNULL(r6m.ret_6m,0)*100,4)                    AS ret_6m,
        ROUND(ISNULL(r1y.ret_1y,0)*100,4)                    AS ret_1y,
        ROUND(ISNULL(rytd.ret_ytd,0)*100,4)                  AS ret_ytd,
        CASE WHEN alld.mtm_value IS NOT NULL THEN ROUND(alld.mtm_value/10000000.0,2) ELSE NULL END  AS fund_mtm,
        CASE WHEN alld.mtm_value IS NOT NULL THEN ROUND(alld.mtm_value*ISNULL(r1d.ret_1d,0)/10000000.0,2) ELSE NULL END AS fund_mtm_chg,
        CASE WHEN alld.fund_weight IS NOT NULL THEN ROUND(alld.fund_weight*100,4) ELSE NULL END     AS fund_wts,
        CASE WHEN alld.index_weight IS NOT NULL THEN ROUND(alld.index_weight*100,4) ELSE NULL END   AS index_wts,
        ROUND(@fund_aum/10000000.0,0)                        AS fund_aum,
        ISNULL(df.marketcap,0)                               AS mcap,
        -- Market cap size from mapping_security_level (imported from KotakLife via ISIN)
        CASE lv_size.level_value_name
            WHEN 'Large Cap' THEN 'LC'
            WHEN 'Mid Cap'   THEN 'MC'
            WHEN 'Small Cap' THEN 'SC'
            ELSE ''
        END                                                   AS size,
        ISNULL(df.avg_volume,0)                               AS avg_vol,
        ISNULL(rm.rating,'')                                  AS rating,
        0                                                     AS is_sector_row
    FROM ALLD alld
    INNER JOIN dbo.security_master sm  ON sm.security_id  = alld.security_id
    LEFT  JOIN dbo.instrument_master im2 ON im2.instrument_id = sm.instrument_type_id
    LEFT  JOIN SECTOR_MAP sec_m ON sec_m.security_id = alld.security_id
    LEFT  JOIN dbo.level_value_master lv ON lv.level_value_id = sec_m.level_value_id
    LEFT  JOIN dbo.security_closeprices cp  ON cp.security_id  = alld.security_id AND cp.price_date  = @eff_date AND cp.exchange_id = 1
    LEFT  JOIN dbo.security_closeprices cpb ON cpb.security_id = alld.security_id AND cpb.price_date = @eff_date AND cpb.exchange_id = 2
    LEFT  JOIN dbo.security_dynamic_factors df ON df.security_id = alld.security_id AND df.effective_date = @eff_date
    LEFT  JOIN SIZE_MAP sz_m ON sz_m.security_id = alld.security_id
    LEFT  JOIN dbo.level_value_master lv_size ON lv_size.level_value_id = sz_m.level_value_id
    LEFT  JOIN dbo.security_rating_mapping rm ON rm.security_id = alld.security_id
    LEFT  JOIN R1D r1d   ON r1d.security_id  = alld.security_id
    LEFT  JOIN R5D r5d   ON r5d.security_id  = alld.security_id
    LEFT  JOIN R1M r1m   ON r1m.security_id  = alld.security_id
    LEFT  JOIN R3M r3m   ON r3m.security_id  = alld.security_id
    LEFT  JOIN R6M r6m   ON r6m.security_id  = alld.security_id
    LEFT  JOIN R1Y r1y   ON r1y.security_id  = alld.security_id
    LEFT  JOIN RYTD rytd ON rytd.security_id = alld.security_id

    UNION ALL

    -- Sector summary rows
    SELECT
        UPPER(ISNULL(lv2.level_value_name,'UNKNOWN')) AS sector,
        UPPER(ISNULL(lv2.level_value_name,'UNKNOWN')) AS security_name,
        'Sector' AS isin_code, NULL AS index_flag,
        CASE WHEN SUM(ISNULL(fh2.weight,0))>0 THEN 'FUND' ELSE NULL END AS fund_flag,
        NULL AS fund_qty, NULL AS cmp, NULL AS close_price,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(sr.portfolio_return,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_1d,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(sr5.ret_5d,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_5d,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(sr1m.ret_1m,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_1m,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(sr3m.ret_3m,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_3m,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(sr6m.ret_6m,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_6m,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(sr1y.ret_1y,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_1y,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(srytd.ret_ytd,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0)*100,2) END AS ret_ytd,
        CASE WHEN SUM(ISNULL(fh2.mtm_value,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(fh2.mtm_value,0))/10000000.0,0) END AS fund_mtm,
        CASE WHEN SUM(ISNULL(fh2.mtm_value,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(fh2.mtm_value,0))*ISNULL(SUM(ISNULL(sr.portfolio_return,0)*ISNULL(fh2.weight,0))/NULLIF(SUM(ISNULL(fh2.weight,0)),0),0)/10000000.0,2) END AS fund_mtm_chg,
        CASE WHEN SUM(ISNULL(fh2.weight,0))=0 THEN NULL ELSE ROUND(SUM(ISNULL(fh2.weight,0))*100,2) END AS fund_wts,
        NULL AS index_wts, NULL AS fund_aum, NULL AS mcap,
        NULL AS size, 0 AS avg_vol, NULL AS rating, 1 AS is_sector_row
    FROM dbo.fund_holdings fh2
    INNER JOIN dbo.security_master sm2 ON sm2.security_id = fh2.security_id
    LEFT JOIN SECTOR_MAP sec_m2 ON sec_m2.security_id = fh2.security_id
    LEFT JOIN dbo.level_value_master lv2 ON lv2.level_value_id = sec_m2.level_value_id
    LEFT JOIN dbo.fund_security_returns sr ON sr.security_id=fh2.security_id AND sr.fund_id=@fund_id AND sr.report_id=@report_id
    LEFT JOIN (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_5d FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=5 GROUP BY fsr.security_id) sr5 ON sr5.security_id=fh2.security_id
    LEFT JOIN (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_1m FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=21 GROUP BY fsr.security_id) sr1m ON sr1m.security_id=fh2.security_id
    LEFT JOIN (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_3m FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=63 GROUP BY fsr.security_id) sr3m ON sr3m.security_id=fh2.security_id
    LEFT JOIN (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_6m FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=126 GROUP BY fsr.security_id) sr6m ON sr6m.security_id=fh2.security_id
    LEFT JOIN (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_1y FROM dbo.fund_security_returns fsr JOIN @report_ids ri ON fsr.report_id=ri.report_id WHERE fsr.fund_id=@fund_id AND ri.rn<=252 GROUP BY fsr.security_id) sr1y ON sr1y.security_id=fh2.security_id
    LEFT JOIN (SELECT fsr.security_id, EXP(SUM(LOG(CASE WHEN fsr.portfolio_return<=-1 THEN 0.000001 ELSE 1+fsr.portfolio_return END)))-1 AS ret_ytd FROM dbo.fund_security_returns fsr JOIN dbo.report_references rr ON fsr.report_id=rr.report_id WHERE fsr.fund_id=@fund_id AND rr.to_date>=@ytd_start AND rr.to_date<=@eff_date GROUP BY fsr.security_id) srytd ON srytd.security_id=fh2.security_id
    WHERE fh2.fund_id=@fund_id AND fh2.effective_date=@eff_date
    GROUP BY lv2.level_value_name

    ORDER BY sector, is_sector_row DESC, security_name;
END
