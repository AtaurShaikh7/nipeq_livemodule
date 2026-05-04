PROCEDURE SP_TRANSFORM_MAIN_BATCH (STARTDATE IN DATE,ENDDATE IN DATE) 

AS

	STARTPROCFLG NUMBER;

	CURR_DATE DATE;

	STATS VARCHAR2(4000);

	RERUNCNT NUMBER;

BEGIN





CURR_DATE := STARTDATE; 



lOOP 



    IF CURR_DATE IS NULL THEN

      EXIT;

    END IF;

    

    IF TRUNC(CURR_DATE) > TRUNC(ENDDATE) THEN

      EXIT;

    END IF;







	UPDATE DAILY_PROCESS_STATS SET CURRDATADATE = CURR_DATE WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';



	COMMIT;



  SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

  IF STATS IS NULL THEN

  

  --SP_TRANSF_SECMAP_FNO;

  

   /* SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

    IF STATS IS NULL THEN

    

    SP_TRANSF_SECMAP;



    INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

    VALUES ('00', 'SP_TRANSF_SECMAP_FNO Started', sysdate,0);

    

      SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

      IF STATS IS NULL THEN

      

      SP_TRANSF_FUNDNAV_FSRC;

  

      INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

      VALUES ('00', 'SP_TRANSF_FUNDNAV_FSRC Started', sysdate,0);

    

        SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

        IF STATS IS NULL THEN */

        



        

        --  SP_TRANSF_FUNDHOLDINGS;

  /*

          SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

          IF STATS IS NULL THEN 	

  

           INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

         VALUES ('00', 'SP_TRANSF_FUNDHOLDINGS_LIVE Started', sysdate,0);

         

            SP_TRANSF_FUNDHOLDINGS_LIVE;

            

            SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

            IF STATS IS NULL THEN 

 

              INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

              VALUES ('00', 'SP_TRANSF_FUNDSECCLOSEP Started', sysdate,0);    

              

              SP_TRANSF_FUNDSECCLOSEP;

  

              SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

              IF STATS IS NULL THEN 

 

               INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

              VALUES ('00', 'SP_TRANSF_TXNDATA Started', sysdate,0);   

              

                SP_TRANSF_TXNDATA;

                --SP_TRANSF_CREATE_TXN;

                

            /*     SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

              IF STATS IS NULL THEN 

              

              ----SP_TRANSF_FACTOR_APPLY;

               INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

              VALUES ('00', 'SP_TRANSF_FIMASTER Started', sysdate,0);     

              

                SP_TRANSF_FIMASTER;

                

                SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                IF STATS IS NULL THEN 



               INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

              VALUES ('00', 'SP_TRANSF_ACCINT_CALC Started', sysdate,0);        

              

                  SP_TRANSF_ACCINT_CALC;

                  

                  */

                  

                  SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                  IF STATS IS NULL THEN 

                  

                   -- SP_LDG_MODELPORTFOLIO_XLS;

                    

                  

                     SP_TRANSF_SEC_PERFORMANCE;

                    

                    /*

                    SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                    IF STATS IS NULL THEN 

    

                      SP_TRANSF_CASHHOLDINGS_LIVE;

    

                      SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                      IF STATS IS NULL THEN 

    

                        SP_TRANSF_CASHTXN;

  

                        SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                        IF STATS IS NULL THEN 

    

                          SP_TRANSF_INTRADAYPRICES;

                          

                          SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                          IF STATS IS NULL THEN 

      

                            SP_TRANSF_FNO_DION_MAPP;

                            SP_TRANSF_UPDATE_FUNDWT_BMWT (CURR_DATE, 'ETL STAGE 2');

                           SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                           IF STATS IS NULL THEN 

      

                            SP_TRANSF_GROUPING_BATCH(CURR_DATE,CURR_DATE);

                            

  

                            END IF;

                              SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                          IF STATS IS NULL THEN 

      

                            SP_DAILY_IDX_RET(CURR_DATE);

                            

                            END IF;

                              SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                           IF STATS IS NULL THEN 

      

                            SP_DAILY_NAV_RETURN(CURR_DATE);

                            

                            END IF;

                              SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

                           IF STATS IS NULL THEN 

      

                            SP_CREATE_SPANRETURN(CURR_DATE);

                            

                          

                            END IF;

                          END IF;

                        END IF;

                      END IF;

                    END IF;

                  END IF;

                END IF;    

              END IF;

            END IF;		

          END IF;

        END IF;

      END IF;	

    END IF;	*/

  END IF;

END IF;





/*SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';

IF STATS IS NULL THEN 	

 SP_TRANSF_HOLDBAL;

 END IF;

 */



   

  SELECT STATUS INTO STATS FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';



	IF STATS IS NOT NULL THEN 



		select max(dayrunseq) INTO RERUNCNT

		from Process_Logs PL

		inner join Daily_Process_Stats DPS

		on (UPPER(DPS.Process_Name) = UPPER(PL.Process_Name)

		and trunc(pl.rundate) = trunc(sysdate)

		and trunc(pl.lastdatadate) = trunc(dps.lastdatadate)

		and trunc(pl.currdatadate) = trunc(dps.currdatadate))

		where UPPER(pl.Process_Name) = 'ETL STAGE 2';



    INSERT INTO PROCESS_LOGS (PROCESS_NAME, RunDate, LastDataDate, CurrDataDate, Status_Message, DAYRUNSEQ)

		SELECT PROCESS_NAME, sysdate, LastDataDate, CurrDataDate, Status, nvl(RERUNCNT,0)+1 

		FROM DAILY_PROCESS_STATS

		WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';



	--	SP_TRANSF_ROLLBACK;

  

	COMMIT;



END IF;



   INSERT INTO audit_table(error_number, error_message, error_date, error_flag)

   VALUES ('00', 'SP_TRANSFORM_MAIN_BATCH done for- ' || CURR_DATE , sysdate,0);



    SELECT MIN(EFFECTIVE_DATE) INTO CURR_DATE FROM BUSINESS_CALENDAR WHERE TRUNC(EFFECTIVE_DATE) > TRUNC(CURR_DATE) AND BUSINESSDAY_FLAG=1;

    

    COMMIT;

    

  end loop;

END;