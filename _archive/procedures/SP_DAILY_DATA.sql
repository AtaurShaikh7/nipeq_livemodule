PROCEDURE sp_daily_data 

AS

CURR_DATE DATE;



BEGIN



SELECT CURRDATADATE INTO CURR_DATE FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 1';



/*Update Issuer related fields in FI_MASTER*/

MERGE INTO fi_master fim

    USING ( select sm.db_security_code,im.issuer_Id,Sm_map.bm_code,im.fm_issuer_l1,im.fm_issuer_l2,im.fm_issuer_l3,im.fm_issuer_l4

            from CREDENCEIDEAL.da_issuer_master im

            inner join Credenceideal.da_security_master sm on sm.issuer_id = im.issuer_id           

            inner join (select * from security_code_mapping_intmdt where Upper(src_flag) ='DB') SM_Map

            on SM_Map.source_security_code = sm.db_security_code ) CIM

    ON ( fim.security_code = CIM.bm_code )

    WHEN MATCHED THEN 

    UPDATE SET  fim.ISSUER_CODE = CIM.issuer_Id,

                fim.ISSUER_CLASS_GROUP = CIM.fm_issuer_l1,

                fim.ISSUER_CLASS_OWNER = CIM.fm_issuer_l2,

                fim.ISSUER_CLASS_SECTOR = CIM.fm_issuer_l3,

                fim.ISSUER_CLASS_SUBSECTOR = CIM.fm_issuer_l4

                WHERE FIM.ISSUER_CLASS_GROUP IS NULL OR FIM.ISSUER_CLASS_OWNER IS NULL OR FIM.ISSUER_CLASS_SECTOR 

                IS NULL OR FIM.ISSUER_CLASS_SUBSECTOR IS NULL OR FIM.ISSUER_CODE IS NULL;               

                

  

  /*Update SchemeStart & END date*/    

  MERGE INTO FUNDS F

      USING (select sim.schemecode,s.scheme_start_date,s.scheme_end_date from scheme_fund_mapping_intmdt sim

            inner join CREDENCEIDEAL.da_schemes s 

            on sim.fund_short_name = s.db_code) SM

      ON(SM.SCHEMECODE = F.FUND_ID)

      WHEN MATCHED THEN

      UPDATE SET F.SCHEME_START_DATE = SM.SCHEME_START_DATE,

                 F.SCHEME_END_DATE = SM.SCHEME_END_DATE;

    

  /*Update Issuer_rating in fund_holdings_fi*/

  MERGE INTO FUND_HOLDINGS_FI FI

        USING(select sm.db_security_code,ir.rating_value,Sm_map.bm_code

              from CREDENCEIDEAL.da_issuer_rating IR

              inner join Credenceideal.da_security_master sm on sm.issuer_id = IR.issuer_id            

              inner join (select * from security_code_mapping_intmdt where Upper(src_flag) ='DB') SM_Map

              on SM_Map.source_security_code = sm.db_security_code) IRM

        ON(FI.SECURITY_CODE = IRM.BM_CODE

          AND TRUNC(FI.EFFECTIVE_DATE) = TRUNC(CURR_DATE))

        WHEN MATCHED THEN

        UPDATE SET FI.ISSUER_RATING = IRM.RATING_VALUE;

  

  /*Insert into CashFlowTable*/

  INSERT INTO CASHFLOW_DATA 

        select CURR_DATE AS EFFECTIVE_DATE,sm_map.bm_code AS SECURITY_CODE,dac.eventtype AS EVENT_TYPE,dac.eventdescription AS EVENT_DESCRIPTION,

        dac.amounttype AS AMOUNT_TYPE,dac.noticedate AS NOTICE_DATE,dac.amount AS AMOUNT,

        dac.interest AS INTEREST,dac.principal AS PRINCIPAL from CREDENCEIDEAL.da_cashflow_data dac

        inner join CREDENCEIDEAL.da_security_master sm            

        on dac.securitysymbol = sm.security_code

        inner join (select * from security_code_mapping_intmdt where Upper(src_flag) ='DB') SM_Map

        on SM_Map.source_security_code = sm.db_security_code;

  

 END sp_daily_data;