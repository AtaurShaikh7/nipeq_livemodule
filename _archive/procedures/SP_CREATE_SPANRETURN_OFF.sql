PROCEDURE SP_CREATE_SPANRETURN_OFF(T_DATE IN DATE)

AS

FROMDATE DATE;

WDCHK NUMBER;

SPANNAME VARCHAR2(10);

SPANID NUMBER;

RFR NUMBER(25,10);

ERRMSG varchar2(200);

BEGIN



  RFR:=0.06;



      FOR SPN IN (SELECT * FROM SPAN_MASTER)

        LOOP

          IF SPN.SPAN_ID = 10  THEN

            SELECT TRUNC (T_DATE , 'YEAR') INTO FROMDATE FROM DUAL;

          ELSIF SPN.SPAN_ID = 11 THEN

            SELECT Last_Day(ADD_MONTHS(T_DATE,-1))+1 INTO FROMDATE from DUAL; 

          ELSE

            SELECT ADD_MONTHS(T_DATE,-1 * SPN.SPN_MONTHS) INTO FROMDATE from DUAL;

          END IF;

          

         -- delete from temp_span;

          --insert into temp_span(date_value)values(fromdate);

          

          SELECT SPN.SPAN_ID,SPN.SPAN_NAME INTO SPANID,SPANNAME FROM DUAL;

          

          SELECT BUSINESSDAY_FLAG INTO WDCHK FROM BUSINESS_CALENDAR WHERE EFFECTIVE_DATE = FROMDATE;

          

          

          

            IF WDCHK = 0 THEN

              SELECT MIN(EFFECTIVE_DATE) INTO FROMDATE FROM BUSINESS_CALENDAR WHERE EFFECTIVE_DATE > FROMDATE and BUSINESSDAY_FLAG = 1;

            END IF;

            

            

               --IN ORDER TO CHECK QUERY HALTED FOR WHICH DATE  

          delete from SPAN_STAMP;

          insert into SPAN_STAMP(run_date,FROM_DATE,TIME) values(T_DATE,FROMDATE,SYSDATE);

          Commit; 

          

          INSERT INTO SPAN_RETURNS_OFF(

          FUND_ID

          --,SCHEME_CLASS

          ,SPAN_ID

          ,SPAN_NAME

          ,FROM_DATE

          ,TO_DATE

          ,P_RETURN

          ,BM_RETURN

          ,P_VOLATILITY

          ,BM_VOLATILITY

          ,ACTIVE_RISK

          ,BETA

          ,JENSEN_ALPHA

          ,INFORMATION_RATIO

          ,SHARPE_RATIO

          ,BM_SHARPE_RATIO

          ,SORTINO_RATIO

          ,BM_SORTINO_RATIO

          ,TREYNOR_RATIO

          ,P_UPSIDE

          ,BM_UPSIDE

          ,P_DOWNSIDE

          ,BM_DOWNSIDE

          )

          SELECT /*+ parallel(4) */  FUND_ID,SPANID,SPANNAME,FROMDATE,T_DATE

          ,power(PRODUCT(1+NVL(RET_1D,0)),1/SPN.ANN_NUM)-1

          ,power(PRODUCT(1+NVL(BM_RET_1D,0)),1/SPN.ANN_NUM)-1 

          ,Round(STDDEV(RET_1D) * SQRT(252),10) AS P_VOLATILITY

          ,Round(STDDEV(BM_RET_1D) * SQRT(252),10) AS BM_VOLATILITY

          ,Round(STDDEV(RET_1D-BM_RET_1D) * SQRT(252),10) AS ACTIVE_RISK

          ,CASE WHEN (count(BM_RET_1D)*sum(BM_RET_1D*BM_RET_1D) - sum(BM_RET_1D)* sum(BM_RET_1D)) <> 0 THEN 

            Round((count(BM_RET_1D)*sum(RET_1D * BM_RET_1D) - sum(BM_RET_1D)* sum(RET_1D))/(count(BM_RET_1D)*sum(BM_RET_1D*BM_RET_1D) - sum(BM_RET_1D)* sum(BM_RET_1D)),10) 

            ELSE 

            NULL 

            END AS BETA

          ,CASE WHEN (count(BM_RET_1D)*sum(BM_RET_1D*BM_RET_1D) - sum(BM_RET_1D)* sum(BM_RET_1D)) <> 0 THEN

            Round((AVG(RET_1D)-RFR)-((count(BM_RET_1D)*sum(RET_1D * BM_RET_1D) - sum(BM_RET_1D)* sum(RET_1D))/(count(BM_RET_1D)*sum(BM_RET_1D*BM_RET_1D) - sum(BM_RET_1D)* sum(BM_RET_1D))) * (AVG(BM_RET_1D)-RFR),10)

            ELSE

            NULL

            END AS JENSEN_ALPHA

          ,CASE WHEN STDDEV(RET_1D-BM_RET_1D) <> 0 THEN

            Round(AVG(RET_1D-BM_RET_1D)/STDDEV(RET_1D-BM_RET_1D),10) 

            ELSE 

            NULL 

            END AS INFORMATION_RATIO

          ,round(CASE WHEN (AVG(RET_1D)-RFR) > 0 THEN 

                  CASE WHEN (STDDEV(RET_1D) * SQRT(252)) <> 0 THEN

                  (AVG(RET_1D)-RFR)/(STDDEV(RET_1D) * SQRT(252))

                  ELSE NULL

                  END

                ELSE (AVG(RET_1D)-RFR) * (STDDEV(RET_1D) * SQRT(252)) * 100

                END,10) AS SHARPE_RATIO

          ,Round(CASE WHEN (AVG(BM_RET_1D)-RFR) > 0 THEN 

                  CASE WHEN (STDDEV(BM_RET_1D) * SQRT(252)) <> 0 THEN

                    (AVG(BM_RET_1D)-RFR)/(STDDEV(BM_RET_1D) * SQRT(252))

                  ELSE

                    NULL

                  END

                ELSE (AVG(BM_RET_1D)-RFR) * (STDDEV(BM_RET_1D) * SQRT(252)) * 100

                END,10) AS BM_SHARPE_RATIO      

          ,Round(CASE WHEN (AVG(RET_1D)-RFR) > 0 THEN 

                  CASE WHEN STDDEV(CASE WHEN RET_1D < 0 THEN RET_1D END)<>0 THEN (AVG(RET_1D)-RFR)/(STDDEV(CASE WHEN RET_1D < 0 THEN RET_1D END) * SQRT(252))

                  ELSE

                  NULL END

                ELSE (AVG(RET_1D)-RFR)*(STDDEV(CASE WHEN RET_1D < 0 THEN RET_1D END) * SQRT(252))*100

                END,10) AS SORTINO_RATIO

          ,Round(CASE WHEN (AVG(BM_RET_1D)-RFR) > 0 THEN 

                  CASE WHEN STDDEV(CASE WHEN BM_RET_1D < 0 THEN BM_RET_1D END) <>0 THEN (AVG(BM_RET_1D)-RFR)/(STDDEV(CASE WHEN BM_RET_1D < 0 THEN BM_RET_1D END) * SQRT(252))

                  ELSE

                  NULL END

                ELSE (AVG(BM_RET_1D)-RFR)*(STDDEV(CASE WHEN BM_RET_1D < 0 THEN BM_RET_1D END) * SQRT(252))*100

                END,10) AS BM_SORTINO_RATIO      

          ,Round(CASE WHEN (AVG(RET_1D)-RFR) > 0 THEN 

                  (AVG(RET_1D)-RFR)/((count(BM_RET_1D)*sum(RET_1D * BM_RET_1D) - sum(BM_RET_1D)* sum(RET_1D))/NULLIF(count(BM_RET_1D)*sum(BM_RET_1D*BM_RET_1D) - sum(BM_RET_1D)* sum(BM_RET_1D),0))

                ELSE 

                (AVG(RET_1D)-RFR)*((count(BM_RET_1D)*sum(RET_1D * BM_RET_1D) - sum(BM_RET_1D)* sum(RET_1D))/NULLIF(count(BM_RET_1D)*sum(BM_RET_1D*BM_RET_1D) - sum(BM_RET_1D)* sum(BM_RET_1D),0))*100

                END,10) AS TREYNOR_RATIO

          ,Round(PRODUCT(1+CASE WHEN BM_RET_1D > 0 THEN RET_1D END)-1,10) AS P_UPSIDE

          ,Round(PRODUCT(1+CASE WHEN BM_RET_1D > 0 THEN BM_RET_1D END)-1,10) AS BM_UPSIDE

          ,Round(PRODUCT(1+CASE WHEN BM_RET_1D < 0 THEN RET_1D END)-1,10) AS P_DOWNSIDE

          ,Round(PRODUCT(1+CASE WHEN BM_RET_1D < 0 THEN BM_RET_1D END)-1,10) AS BM_DOWNSIDE

          FROM DAILY_NAV_RET_OFF

          WHERE TO_DATE >= FROMDATE AND TO_DATE <= T_DATE

          GROUP BY FUND_ID--,SCHEME_CLASS

          HAVING COUNT(*) > 2 and  CEIL(MONTHS_BETWEEN(T_DATE,MIN(TO_DATE))) >= SPN.SPN_MONTHS and MAX(TO_DATE) = T_DATE;

        END LOOP;

     EXCEPTION WHEN NO_DATA_FOUND THEN

       -- DBMS_OUTPUT.PUT_LINE ('No Data Found');

        -- UPDATE DAILY_PROCESS_STATS SET STATUS = 'Span Return - No Data found' where UPPER(PROCESS_NAME) = 'ETL STAGE 2';

       insert into AUDIT_TABLE(ERROR_NUMBER,ERROR_MESSAGE,error_date,error_flag)

   values(0,'Offshore Span Return - No Data found',sysdate,1); 

    WHEN OTHERS THEN

ERRMSG:=substr(SQLERRM, 1, 200);

--ERRCODE:=SQLCODE;



--UPDATE DAILY_PROCESS_STATS SET STATUS = 'Span Return - '||ERRMSG  where UPPER(PROCESS_NAME) = 'ETL STAGE 2';

insert into AUDIT_TABLE(ERROR_NUMBER,ERROR_MESSAGE,error_date,error_flag)

   values(0,'Offshore Span Return - '||ERRMSG,sysdate,1);

END SP_CREATE_SPANRETURN_OFF;