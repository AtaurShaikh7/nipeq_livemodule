PROCEDURE SP_FE_CHECK_COMPLIANCE (FUNDID in number, model_id in number,RUN_DATE in Date,ResultSet out SYS_REFCURSOR)

as

CHECK_EXIST number;

INDEXID1 Number(25,10);

INDEXID2 Number(25,10);

TracErrL1 Number(25,10);

TracErrL2 Number(25,10);

ActSecurityL2 Number(25,10);

ActSectorL2 Number(25,10);

MaxSecurityL Number(25,10);

MaxsectorL Number(25,10);

HvyWtL Number(25,10);

CashL Number(25,10);

PREV_DATE DATE;

ResTracErrL1 Number(25,10);

ResTracErrL2 Number(25,10);

ResActSecurityL2 Number(25,10);

ResActSectorL2 Number(25,10);

ResMaxSecurityL Number(25,10);

ResMaxsectorL Number(25,10);

ResHvyWtL Number(25,10);

ResCashWt Number(25,10);

EQTotalWt Number(25,10);



TracErr1_Typ Number(25,10);

TracErr2_Typ Number(25,10);

ActSecurity_Typ Number(25,10);

ActSector_Typ Number(25,10);

MaxSecurity_Typ Number(25,10);

Maxsector_Typ Number(25,10);

HvyWt_Typ Number(25,10);

Cash_Typ Number(25,10);



BEGIN

  --TrakERROR BM1

  --TrakERROR BM2

  --Act Security WT BM2

  --Act Secto WT BM2

  --Maximum Security WT

  --Maximum Sector WT

  --Heavy Wt Sec

  -- Cash Weight

  SELECT MAX(EFFECTIVE_DATE) INTO PREV_DATE FROM BUSINESS_CALENDAR WHERE businessday_flag=1 

  AND TRUNC(EFFECTIVE_DATE) < TRUNC(RUN_DATE);



  SELECT index_id1, index_id2, track_err_limit1, track_err_limit2, act_security_limit, act_sector_limit, max_security_limit, max_sector_limit, heavy_wt_limit, cash_limit,

  TRACK_ERR1_TYPE,TRACK_ERR2_TYPE,ACT_SECURITY_TYPE,ACT_SECTOR_TYPE,MAX_SECURITY_TYPE,MAX_SECTOR_TYPE,HEAVY_WT_TYPE,CASH_TYPE

  into   indexid1 , indexid2, TracErrL1, TracErrL2, ActSecurityL2, ActSectorL2, MaxSecurityL, MaxsectorL, HvyWtL, CashL, 

  TracErr1_Typ,TracErr2_Typ,ActSecurity_Typ,ActSector_Typ ,MaxSecurity_Typ,Maxsector_Typ,HvyWt_Typ ,Cash_Typ FROM van_funds WHERE fund_id= fundid and model_id=model_id;

  

   --POLULATE TRACK ERROR RESULT WITH BM1  

   select sum(matched_pos) * 100 , sum(FUND_WT) * 100 into ResTracErrL1, EQTotalWt from ( 

   SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid1 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su 

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE);

  

   --POLULATE TRACK ERROR RESULT WITH BM2

   select sum(matched_pos) * 100 into ResTracErrL2 from ( 

   SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid2 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su 

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE);

  

  ----POLULATE NO OF ROWS WHEN SECURITY ACT_WT > SET LIMIT with BM2

  select count(*) into ResActSecurityL2 from (

  SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid2 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE ) where ACT_WT > (ActSecurityL2/100);

  

   ----POLULATE NO OF ROWS WHEN SECTOR ACT_WT > SET LIMIT with BM2

   select count(*) into ResActSectorL2 from (

   select SM.SECTOR_ID, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) AS BM_WT, ABS(SUM(FUND_WT - BM_WT)) as ACT_WT from

   (SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, 

   ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid2 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE) WTS

   INNER JOIN security_master SM on (SM.SECURITY_CODE=WTS.SECURITY_CODE)

   Group by SM.SECTOR_ID ) where ACT_WT > (ActSectorL2/100);

  

  ----POLULATE NO OF ROWS WHEN SECURITY WT > SET MAX LIMIT 

  select count(*) into ResMaxSecurityL from (

  SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid2 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su 

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE)

   WHERE FUND_WT> (MaxSecurityL/100);

  

  

  

  ----POLULATE NO OF ROWS WHEN SECTOR WT > SET MAX LIMIT

  select count(*) into ResMaxsectorL from ( 

  select SM.SECTOR_ID, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) AS BM_WT, ABS(SUM(FUND_WT - BM_WT)) as ACT_WT from

   (SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, 

   ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid2 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su 

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE) WTS

   INNER JOIN security_master SM on (SM.SECURITY_CODE=WTS.SECURITY_CODE)

   Group by SM.SECTOR_ID) where FUND_WT > (MaxsectorL/100);

  

  ----POLULATE SUM OF HEAVY WT STOCKS

  select sum(FUND_WT) * 100 into ResHvyWtL FROM (

  SELECT SECURITY_CODE, SUM(FUND_WT) as FUND_WT, SUM(BM_WT) as BM_WT,

   CASE WHEN SUM(FUND_WT) < SUM(BM_WT) THEN SUM(FUND_WT) else SUM(BM_WT) END as matched_pos, ABS((SUM(FUND_WT) - SUM(BM_WT))) as ACT_WT from

   (

   select case when SU.SECURITY_CODE is NULL then AD.Security_code else SU.Underlier_code end as Security_code, FUND_WT, BM_WT

   --CASE WHEN FUND_WT < BM_WT THEN FUND_WT else BM_WT END as matched_pos, ABS((FUND_WT - BM_WT)) as ACT_WT 

   from 

   (

    select CASE WHEN FUND.SECURITY_CODE IS NULL THEN BM.SECURITY_CODE ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

    CASE WHEN FUND.WEIGHTS IS NULL THEN 0 ELSE FUND.WEIGHTS END as FUND_WT ,

    CASE WHEN BM.WEIGHTS IS NULL THEN 0 ELSE BM.WEIGHTS END as BM_WT from 

    (select * from fund_holdings_model_tmp where fund_id=model_id and trunc(effective_date)=TRUNC(RUN_DATE)) FUND

    full join

    (select * from index_constituents_temp where index_id=indexid2 and trunc(effective_date)=TRUNC(PREV_DATE)) BM 

    on (FUND.security_code=Bm.security_code) 

   ) AD left join (select security_code, underlier_code, underlier_type from security_underliers union all

                    select security_code, underlier_code, underlier_type from security_underliers_SP) su 

   on ad.security_code=su.security_code  

   where (AD.security_code like 'INEQ%' OR AD.security_code like 'INFT%' OR AD.security_code like 'INOP%') 

   and nvl(SU.Underlier_type,'EQUITY')='EQUITY') group by SECURITY_CODE) where FUND_WT>0.05;

  

  ----POLULATE CASH WT

  select  (100 - EQTotalWt) into ResCashWt from Dual;

  

 open ResultSet for 

   

       select 'Tracking Error with Benchmark1' as Constr, case when ((ResTracErrL1/EQTotalWt)*100)<TracErrL1 then 1 else 0 end as ConstrResult, TracErr1_Typ as CONS_TYE  from dual

       UNION ALL

       select 'Tracking Error with Benchmark2' as Constr, case when ((ResTracErrL2/EQTotalWt)*100)<TracErrL2 then 1 else 0 end as ConstrResult, TracErr2_Typ as CONS_TYE from dual

       UNION ALL

       select 'Active Security Weight with Benchmark2' as Constr, case when ResActSecurityL2>0 then 1 else 0 end  as ConstrResult, ActSecurity_Typ as CONS_TYE from dual

       UNION ALL

       select 'Active Sector Weight with Benchmark2' as Constr, case when ResActSectorL2>0 then 1 else 0 end as ConstrResult, ActSector_Typ as CONS_TYE from dual

       UNION ALL

       select 'Max Security Weight' as Constr, case when ResMaxSecurityL>0 then 1 else 0 end as ConstrResult, MaxSecurity_Typ as CONS_TYE from dual

       UNION ALL

       select 'Max Sector Weight' as Constr, case when ResMaxsectorL>0 then 1 else 0 end as ConstrResult, Maxsector_Typ as CONS_TYE from dual

       UNION ALL

       select 'Sum of Heavy Weight Stocks' as Constr, case when ResHvyWtL>HvyWtL then 1 else 0 end as ConstrResult, HvyWt_Typ as CONS_TYE from dual

       UNION ALL

       select 'Cash Weight' as Constr, case when ResCashWt>CashL then 1 else 0 end as ConstrResult, Cash_Typ as CONS_TYE from dual;

       

END SP_FE_CHECK_COMPLIANCE; 

