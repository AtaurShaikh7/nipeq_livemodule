PROCEDURE SP_FE_LIVE_DATA_REL_TEST (FUNDID in number,RUN_DATE in Date,REP_TYPE in VARCHAR,ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

INDEXID Number;

CHECK_EXIST number;

TXN_TOL Number(25,10);

FUND_AUM Number(25,10);

IndexName varchar(50);



BEGIN



  if (rep_type <> 'LIVE') then

    EFFECT_DATE := RUN_DATE;

  else

      select max(EFFECTIVE_DATE) into EFFECT_DATE from business_calendar where businessday_flag=1 and trunc(effective_date) < TRUNC(RUN_DATE);      

  end if;

  SELECT default_index_id into INDEXID FROM FUNDS WHERE fund_id= fundid;

  

  SELECT index_short_name into IndexName FROM INDICES WHERE index_id= INDEXID;

  

  select nav into FUND_AUM from fund_nav where fund_id= FUNDID and trunc(value_date)=TRUNC(EFFECT_DATE);

  

  select count(*) into CHECK_EXIST from FUND_HOLDINGS_LIVE where fund_id=FUNDID and TRUNC(effective_date)=TRUNC(EFFECT_DATE);

  

  if (CHECK_EXIST <> 0) then

  

     open ResultSet for 

   

         select UPPER(Sect.SECTOR_SHORT_NAME) as SECTOR, substr(SM.SECURITY_NAME,1,28) as SECURITY_NAME,

         CASE WHEN SU.SECURITY_CODE IS NULL THEN CASE WHEN ALLD.INDEX_WT is NULL THEN 'No' ELSE IndexName END else case when UPPER(substr(SU.SECURITY_CODE,0,4)) = 'INFT' THEN 'FUT' WHEN UPPER(substr(SU.SECURITY_CODE,0,4)) = 'INOP' THEN 'OPT' ELSE 'OTH' END END AS IndexFlag,

         CASE WHEN ALLD.FUND_WT is NULL THEN 'No' ELSE 'RMF' END AS FundFlag, 

         ALLD.FUND_QTY as FUNDQTY,

         nvl(ALLD.closep, NVL(PD.CLOSEP,0)) as CMP ,

         CASE WHEN (rep_type <> 'LIVE') THEN nvl(ROUND(PD.RET_1D,8),0) ELSE 0 END AS RET_1D,nvl(ROUND(PD.RET_5D,8),null) AS RET_5D,

         nvl(ROUND(PD.RET_YTD,8),null) AS RET_YTD,

         CASE WHEN ALLD.FUND_MTM IS NULL THEN null ELSE ALLD.FUND_MTM END AS FUND_MTM,

         CASE WHEN ALLD.FUND_MTM IS NULL THEN null ELSE round(((nvl(ALLD.FUND_MTM,0)*(1+nvl(PD.RET_1D,0)))-nvl(ALLD.FUND_MTM,0))/10000000,1) END AS FUND_MTM_CHG,

         CASE WHEN ALLD.FUND_WT IS NULL THEN null ELSE ALLD.FUND_WT END AS FUND_WTS,

         CASE WHEN ALLD.INDEX_WT IS NULL THEN null ELSE ALLD.INDEX_WT END AS INDEX_WTS,         

         ROUND(FUND_AUM/10000000,0) as FUND_AUM, PD.MARKETCAP as MCAP,

         RANK() OVER (PARTITION BY Sect.SECTOR_SHORT_NAME ORDER BY SM.SECURITY_NAME asc) rnk,nvl(MAPP.SOURCE_SECURITY_CODE,'null') as ISIN,

         ALLD.BOOK_VAL AS BOOK_VALUE,ALLD.BONUS_SPLIT AS BONUS_SPLIT,ALLD.DIVIDEND_PAYOUT AS PAYOUT

        ,SubSect.SECTOR_SHORT_NAME as SUBSECTOR,RANK() OVER (PARTITION BY Sect.SECTOR_SHORT_NAME ORDER BY SubSect.SECTOR_SHORT_NAME asc) rnk1,

        case when SM.SECTOR_ID2 > 100 THEN 0 ELSE 1 END AS NO_SUBSEC

         from

         (  

            select 

            CASE WHEN FUND.SECURITY_CODE IS NULL THEN IDX.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

            CASE WHEN FUND.QUANTITY IS NULL THEN null ELSE

            CASE WHEN NVL(FUND.OPTION_POSITION,'L') = 'S' then -1*FUND.QUANTITY         

            ELSE FUND.QUANTITY END END AS FUND_QTY,

            CASE WHEN FUND.MTM_VALUE IS NULL THEN null ELSE round(FUND.MTM_VALUE,2) END AS FUND_MTM,

            CASE WHEN FUND.MTM_VALUE IS NULL THEN null ELSE round((FUND.MTM_VALUE/FUND_AUM),8) END AS FUND_WT,

            CASE WHEN IDX.WEIGHTS IS NULL THEN null ELSE IDX.WEIGHTS END AS INDEX_WT,

            CASE WHEN FUND.ammortised_book_cost IS NULL THEN null ELSE FUND.ammortised_book_cost END AS BOOK_VAL,

            CASE WHEN MTM_LIVE_BS.numerator IS NOT NULL AND MTM_LIVE_BS.denominator IS NOT NULL

            THEN (MTM_LIVE_BS.DENOMINATOR/MTM_LIVE_BS.NUMERATOR) ELSE 1 END AS BONUS_SPLIT,

            CASE WHEN MTM_LIVE_D.OFFER_PRICE IS NOT NULL THEN round(FUND.QUANTITY * MTM_LIVE_D.OFFER_PRICE/10000000,8) ELSE 0 END AS DIVIDEND_PAYOUT,

            CASE WHEN FUND.MTM_VALUE_P IS NULL THEN IDX.CLOSEP ELSE CASE WHEN NVL(FUND.OPTION_POSITION,'L') = 'S' then round(FUND.MTM_VALUE_P/(-1*FUND.QUANTITY),2) else round(FUND.MTM_VALUE_P/FUND.QUANTITY,2) END END AS CLOSEP

            FROM

            ( 

              SELECT * FROM fund_holdings_live WHERE FUND_ID=FUNDID AND TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)

            ) FUND

            full join

            (

              select * from INDEX_CONSTITUENTS_LIVE where INDEX_ID=INDEXID and TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)

            ) IDX 

            on (FUND.security_code=IDX.security_code)

            full join

            (

              select * from mtm_affecting_cas_live where TRUNC(effective_date) = TRUNC(RUN_DATE) and corporate_action_type_id=1

            ) MTM_LIVE_D

            ON (FUND.security_code = MTM_LIVE_D.SECURITY_CODE)

            full join

            (

              select * from mtm_affecting_cas_live where TRUNC(effective_date) = TRUNC(RUN_DATE) and corporate_action_type_id in (2,3)

            ) MTM_LIVE_BS

            ON (FUND.security_code = MTM_LIVE_BS.SECURITY_CODE)

         ) ALLD

         LEFT JOIN 

         (

            select security_code, underlier_code, underlier_type from security_underliers 

         ) su

         on ALLD.security_code=su.security_code 

         LEFT JOIN         

         (SELECT * FROM SECURITY_RETURNS WHERE TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)) PD

         ON (PD.SECURITY_CODE=ALLD.SECURITY_CODE)

         INNER JOIN 

         security_master SM on (SM.SECURITY_CODE=ALLD.SECURITY_CODE)

        LEFT JOIN 

        security_code_bbisin_intmdt MAPP on (SM.SECURITY_CODE=MAPP.BM_CODE)

         INNER JOIN

         Sectors sect on (SM.Sector_ID=Sect.Sector_id)

         Inner join 

         Sectors SubSect on (SM.Sector_ID2 = SubSect.Sector_id)

         --where upper(Sect.SECTOR_SHORT_NAME) not like 'CASH%'

         --order by Sect.SECTOR_SHORT_NAME, SM.SECURITY_NAME

         UNION ALL

         select UPPER(Sect.SECTOR_SHORT_NAME) as SECTOR, UPPER(Sect.SECTOR_SHORT_NAME) as SECURITY_NAME,

         null AS IndexFlag,CASE WHEN SUM(NVL(ALLD.FUND_WT,0)) > 0 THEN 'RMF' ELSE null END AS FundFlag, 

         NULL AS Qty,NULL AS CLOSEP,

         case when sum(NVL(ALLD.FUND_WT,0)) = 0 then null else Round((sum(NVL(PD.RET_1D,0) * NVL(ALLD.FUND_WT,0))/sum(NVL(ALLD.FUND_WT,0)))*100,1) end as RET_1D,

         case when sum(NVL(ALLD.FUND_WT,0)) = 0 then null else Round((sum(NVL(PD.RET_5D,0) * NVL(ALLD.FUND_WT,0))/sum(NVL(ALLD.FUND_WT,0)))*100,1) end as RET_5D,

         case when sum(NVL(ALLD.FUND_WT,0)) = 0 then null else Round((sum(NVL(PD.RET_YTD,0) * NVL(ALLD.FUND_WT,0))/sum(NVL(ALLD.FUND_WT,0)))*100,1) end as RET_YTD,

         CASE WHEN SUM(NVL(ALLD.FUND_MTM,0)) = 0 THEN null ELSE ROUND((SUM(NVL(ALLD.FUND_MTM,0)))/10000000,0) END AS FUND_MTM,

         --Round((sum(NVL(ALLD.FUND_MTM,0)*(1+nvl(PD.RET_1D/100,0))))/10000000,1) AS FUND_MTM_CHG,

         ROUND(((CASE WHEN SUM(NVL(ALLD.FUND_MTM,0)) = 0 THEN null ELSE SUM(NVL(ALLD.FUND_MTM,0)) END * (1 +

         case when sum(NVL(ALLD.FUND_WT,0)) = 0 then 0 else Round((sum(NVL(PD.RET_1D,0) * NVL(ALLD.FUND_WT,0))/sum(NVL(ALLD.FUND_WT,0))),8) end)) - CASE WHEN SUM(NVL(ALLD.FUND_MTM,0)) = 0 THEN null ELSE SUM(NVL(ALLD.FUND_MTM,0)) END)/10000000,1) as FUND_MTM_CHG,

         CASE WHEN SUM(NVL(ALLD.FUND_WT,0)) = 0 THEN null ELSE round(SUM(NVL(ALLD.FUND_WT,0)),1) END AS FUND_WT,

         CASE WHEN SUM(NVL(ALLD.INDEX_WT,0)) = 0 THEN null ELSE SUM(NVL(ALLD.INDEX_WT,0)) END AS INDEX_WT,

         null as FUND_AUM, null as MCAP , 0 as rnk,'Sector' as ISIN,0 AS BOOK_VALUE,1 AS BONUS_SPLIT,0 AS PAYOUT

         ,Sect.SECTOR_SHORT_NAME as SUBSECTOR,0 as rnk1,1 AS NO_SUBSEC 

         from

         (  

            select 

            CASE WHEN FUND.SECURITY_CODE IS NULL THEN IDX.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

            CASE WHEN FUND.QUANTITY IS NULL THEN null ELSE CASE WHEN NVL(FUND.OPTION_POSITION,'L') = 'S' then -1*FUND.QUANTITY ELSE FUND.QUANTITY END END AS FUND_QTY,

            CASE WHEN FUND.MTM_VALUE IS NULL THEN null ELSE round(FUND.MTM_VALUE,2) END AS FUND_MTM,

            CASE WHEN FUND.MTM_VALUE IS NULL THEN null ELSE round((FUND.MTM_VALUE/FUND_AUM)*100,8) END AS FUND_WT,

            CASE WHEN IDX.WEIGHTS IS NULL THEN null ELSE IDX.WEIGHTS END AS INDEX_WT FROM

            ( 

              SELECT * FROM fund_holdings_live WHERE FUND_ID=FUNDID AND TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)

            ) FUND

            full join

            (

              select * from INDEX_CONSTITUENTS_LIVE where INDEX_ID=INDEXID and TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)

            ) IDX 

            on (FUND.security_code=IDX.security_code)

         ) ALLD

          LEFT JOIN         

         (SELECT * FROM SECURITY_RETURNS WHERE TRUNC(EFFECTIVE_DATE)=TRUNC(EFFECT_DATE)) PD

         ON (PD.SECURITY_CODE=ALLD.SECURITY_CODE)

         INNER JOIN 

         security_master SM on (SM.SECURITY_CODE=ALLD.SECURITY_CODE)         

         INNER JOIN

         Sectors sect on (SM.Sector_ID=Sect.Sector_id)

         Inner join 

         Sectors SubSect on (SM.Sector_ID2 = SubSect.Sector_id)

         INNER JOIN 

         security_code_bbisin_intmdt MAPP on (SM.SECURITY_CODE=MAPP.BM_CODE)

         --where upper(Sect.SECTOR_SHORT_NAME) not like 'CASH%'

         group by Sect.SECTOR_SHORT_NAME

         order by SECTOR,NO_SUBSEC desc,rnk1, rnk;

         

       

  end if;



END SP_FE_LIVE_DATA_REL_TEST;