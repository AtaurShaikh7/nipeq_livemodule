procedure SP_MP_Chk_Cash_Cncrncy

(

     Var_FUND_ID in number

    ,Var_CashMTM in number

    ,Var_currDate in DATE

    ,Var_CUR_RES out sys_refcursor

)

as

  Var_ErrMsg varchar(200):=null;

  --Var_MaxDate date;

  Var_PrevCashMTM number(25,2):=0;

  Var_IsRecordUpdated char(1):='0';

begin

    --select max(EFFECTIVE_DATE) into Var_MaxDate from FUND_HOLDINGS_MODEL where FUND_ID=Var_FUND_ID; 

  

    select ROUND(MTM_VALUE,2) into Var_PrevCashMTM 

    from FUND_HOLDINGS_MODEL 

    where FUND_ID=Var_FUND_ID and rownum=1 and SECURITY_CODE='INCASH000001' 

    and  TRUNC(EFFECTIVE_DATE)=TRUNC(Var_currDate);

      

    if(Var_PrevCashMTM=Var_CashMTM)

    then

          Var_IsRecordUpdated:=0;

    else

          Var_IsRecordUpdated:=1;

    end if;

    

    open Var_CUR_RES for

      select 'success' status,Var_IsRecordUpdated data" from dual;