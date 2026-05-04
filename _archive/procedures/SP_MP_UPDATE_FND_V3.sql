procedure SP_MP_Update_Fnd_V3

(

    Var_FUND_ID in varchar2

    ,Var_FndDet_XML in clob

    ,Var_currDate in DATE

    ,Var_Cur_Res out sys_refcursor

)

as

    Var_ErrMsg varchar2(500);

    --Var_FndMaxDate date;

begin

      SAVEPOINT SP_MP_Update_Fnd_V3; 

      

      insert into TRANSACTION_DATA_MODEL

      (

        FUND_ID,SECURITY_CODE,TRANSACTION_DATE,TRANSACTION_TIME,TRANSACTION_TYPE_ID,SALE_PURCHASE_FLAG,QUANTITY,TRANSACTION_PRICE,CONSIDERATION 

      )

      SELECT  Var_FUND_ID,xt.sec,Var_currDate,sysdate,1,xt.slFlg,abs(fd.QUANTITY-xt.qty),xt.price,abs(fd.QUANTITY-xt.qty)*xt.price

              FROM XMLTABLE('/ArrayOfUpMP_DTO/UpMP_DTO'

                   PASSING XMLTYPE(Var_FndDet_XML)

                   COLUMNS 

                     sec VARCHAR2(12)  PATH 'sec'

                     ,qty number PATH 'qty'

                     ,mtm NUMBER(25,10)  PATH 'mtm'

                     ,wet NUMBER(25,10) PATH 'wet'

                     ,slFlg VARCHAR2(2)  PATH 'slFlg'

                     ,price NUMBER(25,10)  PATH 'price'

                   ) xt

      join FUND_HOLDINGS_MODEL fd on xt.sec=fd.SECURITY_CODE

      where xt.sec!='INCASH000001' and fd.effective_date = trunc(Var_currDate) and fd.fund_id = Var_FUND_ID;

      

      

      --select max(EFFECTIVE_DATE) into Var_FndMaxDate from FUND_HOLDINGS_MODEL;

      

      MERGE

      INTO    FUND_HOLDINGS_MODEL MrFd

      USING   (

              SELECT  fd.fund_id,fd.security_code,xt.qty,xt.mtm,xt.wet,xt.price,fd.effective_date

              FROM    FUND_HOLDINGS_MODEL fd 

              inner join XMLTABLE('/ArrayOfUpMP_DTO/UpMP_DTO'

                   PASSING XMLTYPE(Var_FndDet_XML)

                   COLUMNS 

                     sec VARCHAR2(12)  PATH 'sec'

                     ,qty number PATH 'qty'

                     ,mtm NUMBER(25,10)  PATH 'mtm'

                     ,wet NUMBER(25,10) PATH 'wet'

                     ,dt VARCHAR2(12) PATH 'dt'

                     ,price NUMBER(25,10)  PATH 'price'

                   ) xt

                  on xt.sec=fd.SECURITY_CODE 

                  where fd.FUND_ID=Var_FUND_ID and TRUNC(fd.EFFECTIVE_DATE)=TRUNC(Var_currDate)

              ) src

        ON (MrFd.security_code = src.security_code and MrFd.effective_date = src.effective_date and MrFd.fund_id = src.fund_id)

        WHEN MATCHED THEN UPDATE

            SET MrFd.QUANTITY=src.qty,MrFd.MTM_VALUE=src.mtm,MrFd.WEIGHTS=src.wet,MrFd.PRICE=src.price; 

      open Var_Cur_Res for

        select 'success' status,'' data" from dual;