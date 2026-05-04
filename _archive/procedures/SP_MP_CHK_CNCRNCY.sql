procedure SP_MP_Chk_Cncrncy

(

    Var_FUND_ID in varchar

    ,Var_SECURITY_CODE in varchar

    ,Var_QUANTITY in number

    ,Var_currDate in DATE

    ,Var_CUR_RES out sys_refcursor      

)

as

  Var_ErrMsg varchar(200):=null;

  --Var_MaxDate date;

  Var_IsRecordUpdated char(1):='0';

  Var_Cnt number:=0;

begin

          --select max(EFFECTIVE_DATE) into Var_MaxDate from FUND_HOLDINGS_MODEL where FUND_ID=Var_FUND_ID; 



          SELECT count(1) into Var_Cnt 

          FROM  FUND_HOLDINGS_MODEL  

          where upper(SECURITY_CODE)=upper(Var_SECURITY_CODE) and round(QUANTITY)=Var_QUANTITY

           and FUND_ID=Var_FUND_ID and TRUNC(EFFECTIVE_DATE)=TRUNC(Var_currDate);



          if(Var_Cnt>0)

          then

              Var_IsRecordUpdated:='0';

          else

              Var_IsRecordUpdated:='1';

          end if;



   dbms_output.put_line('Var_Cnt:- ' || Var_Cnt);



   open Var_CUR_RES for

          select 'success' status,Var_IsRecordUpdated data" from dual;