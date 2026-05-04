procedure SP_Get_Modal_Portfolio

(

    Var_Fnd_ID in NUMBER:=null

    ,Var_Cur_ModProt out sys_refcursor

    ,Var_currDate in date

)

as

    --Var_FndMaxDate date;

    --Var_UniMaxDate date;

    Var_Tmp_Fnd_ID NUMBER;

begin

      if(Var_Fnd_ID is null)

      then

        select FUND_ID into Var_Tmp_Fnd_ID from funds where rownum=1 and nvl(ACTIVE_INACTIVE_FLAG,0)=1 and FUND_TYPE='EQ' order by FUND_NAME;

      else

        Var_Tmp_Fnd_ID:=Var_Fnd_ID;

      end if;

      dbms_output.put_line('Var_Tmp_Fnd_ID:- '||Var_Tmp_Fnd_ID);



      --select max(EFFECTIVE_DATE) into Var_FndMaxDate from FUND_HOLDINGS_MODEL;  

      --select max(EFFECTIVE_DATE) into Var_UniMaxDate from KM_Investment_universe;  



      open Var_Cur_ModProt for

        select  Fnd.FUND_ID                 					  FUND_ID

                ,SecMst.SECURITY_NAME       					  SECURITY_NAME

                ,Fnd.SECURITY_CODE          					  SECURITY_CODE

                ,ISN.Source_Security_Code   					  ISIN

                ,Fnd.QUANTITY               					  QUANTITY

                ,Fnd.MTM_VALUE              					  MTM_VALUE

                ,nvl(Fnd.WEIGHTS,0)          					  WEIGHT

                ,AnlMst.EMAIL               					  LOGIN_ID

                ,AnlMst.ANALYST_ID								      ANALYST_ID

                ,trunc(Fnd.EFFECTIVE_DATE)              EFFECTIVE_DATE

        from FUND_HOLDINGS_MODEL Fnd

          inner join security_master SecMst on SecMst.SECURITY_CODE=Fnd.SECURITY_CODE 

          left join SECURITY_CODE_BBISIN_INTMDT ISN on ISN.BM_Code=Fnd.SECURITY_CODE and ISN.src_Flag='ISIN'

          left join KM_CLIENT_SECURITY_UNIVERSE ClntSec on ClntSec.SECURITY_CODE=Fnd.SECURITY_CODE 

          --left join KM_Investment_universe ClntSec on ClntSec.SECURITY_CODE=Fnd.SECURITY_CODE and to_date(ClntSec.EFFECTIVE_DATE)=to_date(Var_UniMaxDate)

          left join KM_ANALYST_MASTER AnlMst on AnlMst.ANALYST_ID=ClntSec.ANALYST_ID   

        where Fnd.FUND_ID=Var_Tmp_Fnd_ID and trunc(Fnd.EFFECTIVE_DATE)=trunc(Var_currDate)

        order by SECURITY_NAME asc;

end;