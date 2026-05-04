procedure SP_MP_Get_Auto_Sec

(

  Var_lstExcSecurityCode in varchar2

  ,Var_searchText in varchar2

  ,Var_LoginID in varchar2

  ,Var_currDate in varchar2

  ,Var_Cur_Res out sys_refcursor

)

as

    --Var_UniMaxDate date;

begin

       --select max(EFFECTIVE_DATE) into Var_UniMaxDate from KM_Investment_universe;

       open Var_Cur_Res for

       select 

          ClntSec.SECURITY_CODE||':'||nvl(ISN.Source_Security_Code,'') code"