PROCEDURE SP_FE_LIVE_DATA (FUNDID in number,RUN_DATE in Date,ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

INDEXID Number;

CHECK_EXIST number;

TXN_TOL Number(25,10);

FUND_AUM Number(25,10);



BEGIN



  select max(EFFECTIVE_DATE) into EFFECT_DATE from business_calendar where businessday_flag=1 and trunc(effective_date) < TRUNC(RUN_DATE);

  

  SELECT default_index_id into INDEXID FROM FUNDS WHERE fund_id= fundid;

  

  select nav into FUND_AUM from fund_nav_live where fund_id= FUNDID and trunc(value_date)=TRUNC(EFFECT_DATE);

  

  select count(*) into CHECK_EXIST from FUND_HOLDINGS_LIVE where fund_id=FUNDID and TRUNC(effective_date)=TRUNC(EFFECT_DATE);

  

  if (CHECK_EXIST <> 0) then

  

     open ResultSet for 

   

         select Sect.SECTOR_SHORT_NAME as SECTOR, MAPP.SOURCE_SECURITY_CODE as ISIN, ALLD.*,FUND_AUM as FUND_AUM,

         CASE WHEN SU.UNDERLIER_CODE IS NULL THEN ALLD.SECURITY_CODE ELSE SU.UNDERLIER_CODE END AS UNDERLIER_CODE,

         CASE WHEN SU.UNDERLIER_CODE IS NULL THEN ALLD.SECURITY_CODE 

            ELSE CASE WHEN SUBSTR(SU.UNDERLIER_CODE,1,2) = 'IN' 

                    THEN SU.UNDERLIER_CODE 

                  ELSE 'IX' END 

           END AS UND_CODE_SORT,

         substr(SM.SECURITY_NAME,1,35) as SECURITY_NAME , substr(SMU.SECURITY_NAME,1,35) AS UNDERLIER_NAME,

         CASE WHEN SU.UNDERLIER_CODE IS NULL THEN 0 ELSE 1 END AS SEC_TYPE

         from

         (  

            select 

            CASE WHEN FUND.SECURITY_CODE IS NULL THEN IDX.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

            CASE WHEN FUND.QUANTITY IS NULL THEN 0 ELSE CASE WHEN NVL(FUND.OPTION_POSITION,'L') = 'S' then -1*FUND.QUANTITY ELSE FUND.QUANTITY END END AS FUND_QTY,

            CASE WHEN FUND.MTM_VALUE IS NULL THEN 0 ELSE round(FUND.MTM_VALUE,2) END AS FUND_MTM,

            CASE WHEN FUND.MTM_VALUE_P IS NULL THEN 0 ELSE round(FUND.MTM_VALUE_P,2) END AS FUND_MTM_P,

            CASE WHEN FUND.MTM_VALUE IS NULL THEN 0 ELSE round((FUND.MTM_VALUE/FUND_AUM)*100,2) END AS FUND_WT,

            CASE WHEN FUND.MTM_VALUE_P IS NULL THEN 0 ELSE round((FUND.MTM_VALUE_P/FUND_AUM)*100,2) END AS FUND_WT_P,

            CASE WHEN FUND.MTM_VALUE_P IS NULL THEN IDX.CLOSEP ELSE CASE WHEN NVL(FUND.OPTION_POSITION,'L') = 'S' then round(FUND.MTM_VALUE_P/(-1*FUND.QUANTITY),2) else round(FUND.MTM_VALUE_P/FUND.QUANTITY,2) END END AS CLOSEP,

            CASE WHEN IDX.WEIGHTS IS NULL THEN 0 ELSE round(IDX.WEIGHTS *100,8) END AS INDEX_WT FROM

            ( 

              SELECT * FROM FUND_HOLDINGS_LIVE WHERE FUND_ID=FUNDID AND TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)

            ) FUND

            full join

            (

              select * from INDEX_CONSTITUENTS_LIVE where INDEX_ID=INDEXID and TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)

            ) IDX 

            on (FUND.security_code=IDX.security_code)

         ) ALLD

         left join 

         (

            select security_code, underlier_code, underlier_type from security_underliers 

            union all

            select security_code, underlier_code, underlier_type from security_underliers_SP

         ) su

         on ALLD.security_code=su.security_code 

         INNER JOIN 

         security_master SM on (SM.SECURITY_CODE=ALLD.SECURITY_CODE)

         INNER JOIN 

         (

            SELECT SECURITY_CODE, SECURITY_NAME FROM SECURITY_MASTER  UNION ALL

            SELECT CAST(INDEX_ID AS VARCHAR2(10)) AS SECURITY_CODE, INDEX_NAME FROM INDICES  

         ) SMU

         on (SMU.SECURITY_CODE = CASE WHEN SU.UNDERLIER_CODE IS NULL THEN ALLD.SECURITY_CODE ELSE SU.UNDERLIER_CODE END)

         INNER JOIN 

         security_code_bbisin_intmdt MAPP on (SM.SECURITY_CODE=MAPP.BM_CODE)

         INNER JOIN 

         Sectors sect on (SM.Sector_ID=Sect.Sector_id)

         order by Sect.SECTOR_SHORT_NAME, UND_CODE_SORT, SEC_TYPE;

       

  end if;



END SP_FE_LIVE_DATA;