procedure SP_MP_DelSecurity

(

    Var_securityCode in varchar2

    ,Var_FUND_ID in number

    ,Var_cashMTM in number

    ,Var_cashWet in number 

    ,Var_price in number

    ,Var_qty in number 

    ,Var_currDate in DATE

    ,Var_Cur_Res out sys_refcursor

)

as

    Var_ErrMsg varchar(200):='';

    --Var_FndMaxDate date;

begin

      SAVEPOINT SP_MP_DelSecurity;



      --select max(EFFECTIVE_DATE) into Var_FndMaxDate from FUND_HOLDINGS_MODEL;



        update FUND_HOLDINGS_MODEL 

        set MTM_VALUE=Var_cashMTM,PRICE=Var_cashMTM,WEIGHTS=Var_cashWet 

        where FUND_ID=Var_FUND_ID and TRUNC(EFFECTIVE_DATE)=TRUNC(Var_currDate) 

        and SECURITY_CODE='INCASH000001';



        DELETE FROM FUND_HOLDINGS_MODEL 

        WHERE FUND_ID=Var_FUND_ID AND UPPER(SECURITY_CODE)=UPPER(Var_securityCode) AND EFFECTIVE_DATE = TRUNC(Var_currDate);



       insert into TRANSACTION_DATA_MODEL

      (

        FUND_ID,SECURITY_CODE,TRANSACTION_DATE,TRANSACTION_TIME,TRANSACTION_TYPE_ID,SALE_PURCHASE_FLAG,QUANTITY,TRANSACTION_PRICE,CONSIDERATION 

      )

      values

      (

          Var_FUND_ID,Var_securityCode,Var_currDate,SYSDATE,1,0,Var_qty,Var_price,Var_qty*Var_price

      );



      open Var_Cur_Res for

          select 'success' status, '' data" from dual;