PROCEDURE SP_DAILY_NAV_RETURN_OFF (CURR_DATE IN DATE)

AS

PREV_DATE DATE ;

ERRMSG varchar2(200);

BEGIN

  SELECT MAX(effective_date) INTO PREV_DATE from BUSINESS_CALENDAR where BUSINESSDAY_FLAG = 1 and EFFECTIVE_DATE < CURR_DATE;

  delete from DAILY_NAV_RET_OFF where TO_DATE = CURR_DATE;

  -- Calculation for standard index

  INSERT INTO DAILY_NAV_RET_OFF(FUND_ID,INDEX_ID,FROM_DATE,TO_DATE,RET_1D, bm_ret_1d)

  SELECT FUND_DATA.FUND_ID,FUND_DATA.INDEX_ID,FUND_DATA.PREV_DATE,FUND_DATA.CURR_DATE,FUND_DATA.RET_1D,nvl(bm_ret1d,0)

  FROM

  (

    SELECT CURR_DATA.fund_id

          ,CURR_DATA.INDEX_ID

          ,PREV_DATE

          ,CURR_DATE

          ,((NVL(CURR_NAV,0) + NVL(DIV_RATE_PER_UNIT,0))/NVL(PREV_NAV,0))-1  AS RET_1D

    FROM

    (

      select FNSO.fund_id, f.default_index_id as INDEX_ID,value_date, --scheme_class, 

      nav_per_unit as CURR_NAV

      from fund_nav FNSO

      INNER JOIN FUNDS F

      ON FNSO.fund_id = f.fund_id

      where f.offshore_flag=1 and f.active_inactive_flag=1 and --scheme_class in ('U','P','I','M','C','J','G','S','E') AND 

      TRUNC(VALUE_DATE) = CURR_DATE  and  fnso.fund_id not  in (157,163,162) 

    )CURR_DATA

    INNER JOIN

    (

      select FNSO.fund_id,f.default_index_id as INDEX_ID,value_date, --scheme_class, 

      nav_per_unit AS PREV_NAV

      from fund_nav FNSO

      INNER JOIN FUNDS F

      ON FNSO.fund_id = f.fund_id

      where f.offshore_flag=1 and  f.active_inactive_flag=1 and--scheme_class in ('U','P','I','M','C','J','G','S','E') AND 

      TRUNC(VALUE_DATE) = PREV_DATE and fnso.fund_id not in (157,163,162) 

    )PREV_DATA

    ON CURR_DATA.fund_id = PREV_DATA.fund_id --AND CURR_DATA.scheme_class = PREV_DATA.scheme_class

    LEFT JOIN 

    (

      select f.FUND_ID,SCHEME_CLASS,RECORD_DATE,DIV_RATE_PER_UNIT from DIVIDEND_DATA dd 

      inner join funds f on

      dd.fund_id = f.FUND_ID 

      where f.offshore_flag=1  and  f.active_inactive_flag=1 and f.fund_id not in (157,163,162)  -- SCHEME_CLASS in ('U','P','I','M','C','J','G','S','E')

    )DIV_DATA

    ON CURR_DATA.VALUE_DATE = DIV_DATA.RECORD_DATE AND CURR_DATA.FUND_ID = DIV_DATA.FUND_ID --AND CURR_DATA.SCHEME_CLASS = DIV_DATA.SCHEME_CLASS

  )FUND_DATA

  LEFT JOIN 

  daily_idx_ret DIR

  ON DIR.INDEX_ID = FUND_DATA.INDEX_ID AND FUND_DATA.CURR_DATE = DIR.EFFECTIVE_DATE;

  

    EXCEPTION

          WHEN ZERO_DIVIDE

   THEN

   

   --UPDATE DAILY_PROCESS_STATS SET STATUS = 'Nav Return - Cannot be divided by zero..Previous day nav of some funds is not present or 0' where UPPER(PROCESS_NAME) = 'ETL STAGE 2';

   insert into AUDIT_TABLE(ERROR_NUMBER,ERROR_MESSAGE,error_date,error_flag)

   values(0,'Offshore Nav Return - Cannot be divided by zero..Previous day nav of some funds is not present or 0',sysdate,1); 

    WHEN OTHERS THEN

ERRMSG:=substr(SQLERRM, 1, 200);

--ERRCODE:=SQLCODE;

insert into AUDIT_TABLE(ERROR_NUMBER,ERROR_MESSAGE,error_date,error_flag)

   values(0,'Offshore Nav Return - '||ERRMSG,sysdate,1);

  

END SP_DAILY_NAV_RETURN_OFF;