procedure SP_MP_GetLogAnl_ID

(

    Var_loggedInEmail in varchar

    ,Var_Cur_Res out sys_refcursor

)

as

begin

  open Var_Cur_Res for

      select 'success' status, ANALYST_ID data" from KM_ANALYST_MASTER where UPPER(LOGIN_ID)=UPPER(Var_loggedInEmail);