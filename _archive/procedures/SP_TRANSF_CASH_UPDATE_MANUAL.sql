PROCEDURE sp_transf_cash_update_manual AS



    -- Hard-code your dates here

    v_from_date DATE := TO_DATE('13-Oct-2025','DD-MON-YYYY');

    v_to_date   DATE := TO_DATE('14-OCt-2025','DD-MON-YYYY');



BEGIN

    ------------------------------------------------------------------

    -- Cursor for funds

    ------------------------------------------------------------------

    FOR rec IN (

        SELECT fund_id 

        FROM funds  -- change to your table name if required

        WHERE fund_id in (43)

    ) LOOP



        ------------------------------------------------------------------

        -- DELETE FUND HOLDINGS

        ------------------------------------------------------------------

        DELETE FROM fund_holdings

        WHERE fund_id = rec.fund_id

          AND effective_date BETWEEN v_from_date AND v_to_date

          AND security_code LIKE 'INCA%';



        ------------------------------------------------------------------

        -- DELETE TRANSACTION DATA

        ------------------------------------------------------------------

        DELETE FROM transaction_data

        WHERE fund_id = rec.fund_id

          AND transaction_date BETWEEN v_from_date AND v_to_date

          AND transaction_type_id IN (2,4);



        ------------------------------------------------------------------

        -- RUN 3 PROCEDURES

        ------------------------------------------------------------------

        SP_CASH_HLDS_BATCH_FUND(rec.fund_id, v_from_date, v_to_date);

        SP_DIVIDEND_TXNS_BATCH_FUND(rec.fund_id, v_from_date, v_to_date);

        SP_CASH_TXNS_BATCH_FUND(rec.fund_id, v_from_date, v_to_date);



        COMMIT;



    END LOOP;



END sp_transf_cash_update_manual;