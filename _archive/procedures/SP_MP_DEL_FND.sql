procedure SP_MP_Del_Fnd

(

    Var_FUND_ID in number

    ,Var_Cur_Res out sys_refcursor

)

as

    Var_ErrMsg varchar(200):=null;

begin

    delete from FUND_HOLDINGS_MODEL 

    where FUND_ID=Var_FUND_ID 

    AND TRUNC(EFFECTIVE_DATE) = (SELECT MAX(EFFECTIVE_DATE) FROM FUND_HOLDINGS_MODEL WHERE FUND_ID = Var_FUND_ID);

    open Var_Cur_Res for 

        select 'success' status,'' data" from dual;