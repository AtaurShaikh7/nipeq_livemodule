PROCEDURE sp_transf_cash_update_test AS



    -- Hard-coded date range

    v_from_date DATE := TO_DATE('03-JUL-2023','DD-MON-YYYY');

    v_to_date   DATE := TO_DATE('31-JUL-2023','DD-MON-YYYY');



    -- Collection to store fund list

    TYPE fund_list_type IS TABLE OF NUMBER;

    v_funds fund_list_type;



BEGIN

    ------------------------------------------------------------------

    -- Load fund list once (only here you maintain it!)

    ------------------------------------------------------------------

    SELECT fund_id

    BULK COLLECT INTO v_funds

    FROM funds

    WHERE fund_id IN (1,2,3,4);   -- only change here when needed





    ------------------------------------------------------------------

    -- LOOP FOR ALL FUNDS

    ------------------------------------------------------------------

    FOR i IN 1 .. v_funds.COUNT LOOP



        DELETE FROM fund_holdings

        WHERE fund_id = v_funds(i)

          AND effective_date BETWEEN v_from_date AND v_to_date

          AND security_code LIKE 'INCA%';



        DELETE FROM transaction_data

        WHERE fund_id = v_funds(i)

          AND transaction_date BETWEEN v_from_date AND v_to_date

          AND transaction_type_id IN (2,4);



        SP_CASH_HLDS_BATCH_FUND(v_funds(i), v_from_date, v_to_date);

        SP_DIVIDEND_TXNS_BATCH_FUND(v_funds(i), v_from_date, v_to_date);

        SP_CASH_TXNS_BATCH_FUND(v_funds(i), v_from_date, v_to_date);



        COMMIT;

    END LOOP;







    ------------------------------------------------------------------

    -- 🚀 RUN LIST OF QUERIES AFTER LOOP (USING SAME FUND LIST)

    ------------------------------------------------------------------



    ------------------------------------------------------------------

    -- 1) INSERT USING FUND LIST

    ------------------------------------------------------------------

    INSERT INTO customized_report_references

    SELECT DISTINCT rr.report_id, rr.fund_id, rr.index_id

    FROM report_references rr

    WHERE rr.daily_default_report_flag = 0

      AND rr.to_date BETWEEN v_from_date AND v_to_date

      AND rr.fund_id MEMBER OF v_funds;   -- <-- used here







    ------------------------------------------------------------------

    -- 2) DELETE USING customized_report_references

    ------------------------------------------------------------------

    DELETE FROM PORTFOLIO_WEIGHT 

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM CUSTOM_REPORTS 

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM CUSTOM_REPORTS_SECTOR 

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM CUSTOM_REPORTS_SECURITY

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM CUSTOM_REPORTS_SECDD

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM CUSTOM_REPORTS_STYLE

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM DEFAULT_TREND_REPORTS

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM DEFAULT_ATTRIB_REPORTS

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM DEFAULT_ATTRIB_MONTHLY_REPORTS

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM DEFAULT_ROLLING_RETURNS

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM SECURITY_DRILLDOWN_ATTRIB_DATA

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM SECURITY_ATTRIBUTION_DATA

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM FUND_ATTRIBUTED_DATA

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM SECTOR_ATTRIBUTED_DATA

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);



    DELETE FROM TREND_REPORTS

      WHERE REPORT_ID IN (SELECT REPORT_ID FROM customized_report_references);







    ------------------------------------------------------------------

    -- 3) FULL CLEANUP

    ------------------------------------------------------------------

    DELETE FROM SECURITY_MERGE_DAILY;



    DELETE FROM CUSTOM_REPORTS;

    DELETE FROM CUSTOM_REPORTS_SECTOR;

    DELETE FROM CUSTOM_REPORTS_SECURITY;

    DELETE FROM CUSTOM_REPORTS_SECDD;

    DELETE FROM CUSTOM_REPORTS_STYLE;

    DELETE FROM CUSTOM_REPORTS_FUND;



    DELETE FROM report_references

     WHERE daily_default_report_flag = 2;







    ------------------------------------------------------------------

    -- 4) NIPPON EQUITY PROCS

    ------------------------------------------------------------------

    SP_VALAT_SECRET;

    SP_VALAT_PORTRET;

    SP_VALAT_SECTRET;

    SP_VALAT_SECVALATT;

    SP_VALAT_SECTATT;

    SP_VALAT_PORTATT;

    SP_VALAT_SECDRLATT;







    ------------------------------------------------------------------

    -- 5) FINAL CLEANUP

    ------------------------------------------------------------------

    DELETE FROM CUSTOM_REPORTS;

    DELETE FROM CUSTOM_REPORTS_SECTOR;

    DELETE FROM CUSTOM_REPORTS_SECURITY;

    DELETE FROM CUSTOM_REPORTS_SECDD;

    DELETE FROM CUSTOM_REPORTS_STYLE;

    DELETE FROM CUSTOM_REPORTS_FUND;



    DELETE FROM report_references

     WHERE daily_default_report_flag = 2;



    COMMIT;



END sp_transf_cash_update_test;

