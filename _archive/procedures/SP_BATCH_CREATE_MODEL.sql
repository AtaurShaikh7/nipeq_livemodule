PROCEDURE SP_BATCH_create_model(FUNDID IN NUMBER, FDATE IN DATE)

AS

--MIN_DATE DATE;

MAX_DATE DATE;

CURR_DATE DATE;

ERROR_STATUS VARCHAR2(500);

err_code number;

err_msg VARCHAR2(500);

BEGIN

 

  SELECT MIN(EFFECTIVE_DATE) INTO CURR_DATE FROM BUSINESS_CALENDAR WHERE TRUNC(EFFECTIVE_DATE) >= TRUNC(FDATE) AND BUSINESSDAY_FLAG = 1;

 

  SELECT MAX(effective_date) INTO MAX_DATE from fund_holdings where fund_id in (88,89,90);

   --SELECT max(effective_date) into MAX_DATE from fund_holdings where effective_date<='31-dec-2017';

 

 -- MIN_DATE := FDATE;  

 -- CURR_DATE := MIN_DATE;

  

  LOOP

    IF CURR_DATE IS NULL THEN

      EXIT;

    END IF;

   

    IF CURR_DATE > MAX_DATE THEN

      EXIT;

    END IF;

    

    select status into ERROR_STATUS from DAILY_PROCESS_STATS where UPPER(PROCESS_NAME) = 'ETL STAGE 2';

    IF ERROR_STATUS IS NOT NULL THEN 

      EXIT;

    END IF;

 

    SP_TRANSF_CREATE_MODELS_DATE(FUNDID, CURR_DATE);

    

    SELECT MIN(EFFECTIVE_DATE) INTO CURR_DATE FROM BUSINESS_CALENDAR WHERE EFFECTIVE_DATE > CURR_DATE AND BUSINESSDAY_FLAG = 1;

   

  COMMIT;

  END LOOP;



INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

	VALUES ('00', 'SP_BATCH_create_model Executed for ' || FUNDID || ' AND FDATE '||FDATE, sysdate,0);

 

 

 

 EXCEPTION

   WHEN OTHERS THEN

   err_code := SQLCODE;

      err_msg := substr(SQLERRM, 1, 500);



      INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

      VALUES ('00', 'SP_BATCH_create_model Failed for ' || FUNDID || ' AND FDATE '||FDATE, sysdate,0);

      INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

      VALUES (err_code, err_msg, sysdate,1);

   commit;

 

 

 

END SP_BATCH_create_model;