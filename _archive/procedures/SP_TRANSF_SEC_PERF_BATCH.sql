PROCEDURE SP_TRANSF_SEC_PERF_BATCH (START_DATE IN DATE,END_DATE IN DATE)

AS



CURR_DATE DATE;

DATAREADY NUMBER;

EQBDFLAG NUMBER;

PREV_DATE DATE;

ERRMSG varchar2(200);

FROMDT_1W date;

FROMDT_1M date;

FROMDT_3M date;

FROMDT_6M date;

FROMDT_1Y date;

FROMDT_3Y date;

FROMDT_5Y date;

FROMDT_YTD date;

SRET_1W number(25,10);

SRET_1M number(25,10);

SRET_3M number(25,10);

SRET_6M number(25,10);

SRET_1Y number(25,10);

SRET_YTD number(25,10);

SRET_3Y number(25,10);

SRET_5Y number(25,10);



CURSOR Security_Cursor is

	SELECT DISTINCT Security_Code FROM DAILY_SECURITY_PRICES 

	WHERE trunc(effective_date) BETWEEN TRUNC(START_DATE) AND TRUNC(END_DATE);



BEGIN



  CURR_DATE := TRUNC(START_DATE);



SELECT MAX(EFFECTIVE_DATE) INTO PREV_DATE FROM BUSINESS_CALENDAR WHERE businessday_flag=1 

AND trunc(EFFECTIVE_DATE) < trunc(CURR_DATE);

  

  LOOP

  

    IF CURR_DATE IS NULL THEN

      EXIT;

    END IF;

    

    IF TRUNC(CURR_DATE) > TRUNC(END_DATE) THEN

      EXIT;

    END IF;

  

  

  SELECT COUNT(*) INTO DATAREADY FROM DAILY_SECURITY_PRICES WHERE trunc(effective_date) = trunc(CURR_DATE);

  

  SELECT MAX(EFFECTIVE_DATE) INTO PREV_DATE FROM BUSINESS_CALENDAR WHERE businessday_flag=1 AND trunc(EFFECTIVE_DATE) < trunc(CURR_DATE);



  SELECT 

	  trunc(CURR_DATE) - 7 + 1,

	  add_months(trunc(CURR_DATE), -1*1) + 1,

	  add_months(trunc(CURR_DATE), -1*3) + 1,

	  add_months(trunc(CURR_DATE), -1*6) + 1,

	  trunc(CURR_DATE) - to_yminterval(cast(1 as varchar(2))||'-00') + 1,

	  trunc(CURR_DATE) - to_yminterval(cast(3 as varchar(2))||'-00') + 1,

	  trunc(CURR_DATE) - to_yminterval(cast(5 as varchar(2))||'-00') + 1,

	  TRUNC(trunc(CURR_DATE),'YEAR') 

  into 

	FROMDT_1W ,FROMDT_1M ,FROMDT_3M ,FROMDT_6M ,FROMDT_1Y ,FROMDT_3Y,FROMDT_5Y,FROMDT_YTD

  from dual   ; 



  IF DATAREADY > 0 THEN 

    

    For SMC in Security_Cursor

    Loop



      SRET_1W := 1;      SRET_1M := 1;

      SRET_3M := 1;      SRET_6M := 1;

      SRET_1Y := 1;      SRET_YTD := 1;

	  SRET_3Y := 1;		 SRET_5Y := 1;

  

      SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_1W FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_1W) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

      

      SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_1M FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_1M) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

      

      SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_3M FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_3M) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;



      SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_6M FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_6M) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

      

      SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_1Y FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_1Y) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

	  

	   SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_3Y FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_3Y) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

	  

	   SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_5Y FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_5Y) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

      

      SELECT Product(1 + NVL(NSE_PERCHG,NVL(BSE_PERCHG,0))) into SRET_YTD FROM DAILY_SECURITY_PRICES 

      WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FROMDT_YTD) and TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

 

--1) below lines are commented not to insert the data---

/* 

      INSERT INTO SECURITY_RETURNS (effective_date, security_code, closep , marketcap, ret_1d, ret_5d, ret_1m, ret_3m, ret_6m, ret_1y, ret_ytd,ret_3y,ret_5y)

      SELECT effective_date, security_code,case when nse_closep is null then bse_closep else nse_closep end,

      case when nse_marketcap is null then bse_marketcap else nse_marketcap end,

      case when nse_perchg is null then bse_perchg else nse_perchg end,SRET_1W - 1,SRET_1M - 1,SRET_3M - 1,SRET_6M - 1,SRET_1Y - 1,SRET_YTD - 1,SRET_3Y - 1,SRET_5Y - 1

      from DAILY_SECURITY_PRICES where TRUNC(effective_date)=TRUNC(CURR_DATE) AND Security_Code = SMC.Security_Code;

*/

  

	Merge into SECURITY_RETURNS S

	using(

		SELECT effective_date, security_code, case when nse_closep is null then bse_closep else nse_closep end AS CLOSEP

			, case when nse_marketcap is null then bse_marketcap else nse_marketcap end AS MARKETCAP

			, case when nse_perchg is null then bse_perchg else nse_perchg end AS SRET_1D,(SRET_1W - 1) as SRET_1W

			, (SRET_1M - 1) as SRET_1M,(SRET_3M - 1) as SRET_3M,(SRET_6M - 1) as SRET_6M,(SRET_1Y - 1) as SRET_1Y

			, (SRET_YTD - 1) as SRET_YTD,(SRET_3Y - 1) as SRET_3Y,(SRET_5Y - 1) as SRET_5Y

		FROM DAILY_SECURITY_PRICES 

		WHERE TRUNC(effective_date)=TRUNC(CURR_DATE) 

			AND Security_Code = SMC.Security_Code

	) D

	ON (S.effective_date = D.effective_date and S.security_code=D.security_code)

	when matched then UPDATE 

		SET S.CLOSEP = D.CLOSEP, S.MARKETCAP=D.MARKETCAP, S.RET_1D=D.SRET_1D, S.RET_5D=D.SRET_1W, S.RET_1M=D.SRET_1M, S.RET_3M=D.SRET_3M, S.RET_6M=D.SRET_6M

			, S.RET_1Y=D.SRET_1Y, S.RET_YTD=D.SRET_YTD, S.RET_3Y = D.SRET_3Y, S.RET_5Y = D.SRET_5Y;

	

    END Loop;    

	      

  ELSE 

  

    --UPDATE DAILY_PROCESS_STATS SET STATUS = 'SECURITY RETURNS UPDATE - No data for ' || CAST(TRUNC(CURR_DATE) AS VARCHAR2(10)) where UPPER(PROCESS_NAME) = 'ETL STAGE 2';

	

	  INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

	  VALUES ('1', 'SECURITY RETURNS UPDATE No data for : ' || CURR_DATE, sysdate,0);

  

  END IF;



  

      INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

	  VALUES ('1', 'SECURITY RETURNS UPDATE : ' || CURR_DATE, sysdate,0);

    

    SELECT MIN(EFFECTIVE_DATE) INTO CURR_DATE FROM BUSINESS_CALENDAR WHERE TRUNC(EFFECTIVE_DATE) > TRUNC(CURR_DATE) AND BUSINESSDAY_FLAG=1;

    

    COMMIT;

    

  END LOOP;

  



EXCEPTION 

WHEN OTHERS THEN

ERRMSG:=substr(SQLERRM, 1, 200);

--ERRCODE:=SQLCODE;

--UPDATE DAILY_PROCESS_STATS SET STATUS = 'SECURITY RETURNS UPDATE - '||ERRMSG  where UPPER(PROCESS_NAME) = 'ETL STAGE 2';



  INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

  VALUES ('1', 'SECURITY RETURNS UPDATE : ' || ERRMSG || '  '  || CURR_DATE, sysdate,0);



END SP_TRANSF_SEC_PERF_BATCH;