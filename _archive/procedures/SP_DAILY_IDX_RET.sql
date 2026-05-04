PROCEDURE SP_DAILY_IDX_RET (CURR_DATE IN DATE)

AS

PREV_DATE DATE ;

BEGIN



    -- Delete if there is any existing record

    delete from daily_idx_ret where EFFECTIVE_DATE = CURR_DATE;

    

    SELECT MAX(effective_date) INTO PREV_DATE from BUSINESS_CALENDAR where BUSINESSDAY_FLAG = 1 and EFFECTIVE_DATE < CURR_DATE;

    

    INSERT INTO daily_idx_ret(index_id, effective_date, bm_ret1d)

    SELECT CURR.INDEX_ID,CURR.PRICE_DATE,(NVL(IP_CURR,0)/NVL(IP_PREV,0))-1 AS BM_RET_1D

    FROM

    (

      SELECT INDEX_ID, price_date, closep AS IP_CURR FROM index_prices

      WHERE price_date = CURR_DATE

    )CURR

    INNER JOIN

    (  

      SELECT INDEX_ID, price_date, closep AS IP_PREV FROM index_prices

      WHERE price_date = PREV_DATE 

    )PREV

    ON CURR.INDEX_ID = PREV.INDEX_ID;

END SP_DAILY_IDX_RET;