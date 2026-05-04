PROCEDURE SP_FE_VALUEAN_DATA (FUNDID in number,RUN_DATE in Date,ResultSet out SYS_REFCURSOR)

as



MODEL_ID Number;

CHECK_EXIST number;

TXN_TOL Number(25,10);

MODEL_AUM Number(25,10);



BEGIN



  SELECT model_id, nvl(tolerance,0) into MODEL_ID , TXN_TOL FROM van_funds WHERE fund_id= fundid;

  

  select nav into MODEL_AUM from fund_nav_off where fund_id= model_id and trunc(effective_date)=TRUNC(RUN_DATE);

  

  select count(*) into CHECK_EXIST from fund_holdings_model where fund_id=MODEL_ID and TRUNC(effective_date)=TRUNC(RUN_DATE);

  

  if (CHECK_EXIST <> 0) then

  

     open ResultSet for 

   

       select MAPP.source_security_code as ISIN, substr(SM.SECURITY_NAME,1,35) as SECURITY_NAME,

       TXN_TOL as TXN_TOL,MODEL_AUM as MODEL_AUM, ALLD.* from

       (  

          select CASE WHEN FUND.SECURITY_CODE IS NULL THEN 

                   CASE WHEN ModelD.SECURITY_CODE IS NULL THEN 

                      TXN.SECURITY_CODE 

                   ELSE ModelD.SECURITY_CODE END

                 ELSE FUND.SECURITY_CODE END AS SECURITY_CODE,

          case when ModelBOD.Weights is null then 0 else round(ModelBOD.Weights * 100,2) END as ModelBOD_WT,

          case when FUND.Weights is null then 0 else round(FUND.Weights * 100,2) END as FUND_WT,

          case when FUND.Quantity is null then 0 else FUND.Quantity END as FUND_Qty,

          case when FUND.s_quantity is null then 0 else FUND.s_quantity END as FUND_SALE_QTY,

          case when ModelD.Weights is null then 0 else round(ModelD.Weights * 100,2) END as MODEL_WT,

          case when ModelD.Quantity is null then 0 else ModelD.Quantity END as Model_Qty,

          case when ModelD.PRICE is null then 0 else ModelD.PRICE END as EOD_PRICE,

          case when TXN.TXN_QTY is null then 0 else TXN.TXN_QTY END as TXN_Qty,

          case when TXN.TXN_FLAG is null then 0 else TXN.TXN_FLAG END as TXN_FLAG,

          case when FUND.mtm_value is null then 0 else FUND.mtm_value END as FUND_MTM from

          (select security_code, weights, round(quantity*(den/num),0) as quantity, round(SALEABLE_QUANTITY*(den/num),0) as s_quantity,mtm_value from

            (select fho.security_code,fho.quantity,fho.SALEABLE_QUANTITY,fho.weights,case when mac.numerator is null then 1 else mac.numerator end as num 

            ,case when mac.denominator is null then 1 else mac.denominator end as den,fho.mtm_value from fund_holdings_off fho

            left Join 

            mtm_affecting_cas mac 

            ON (mac.security_code=fho.security_code and mac.effective_date=fho.holding_date)

            where fho.fund_id=FUNDID and trunc(fho.effective_date)=trunc(RUN_DATE))

          ) FUND

          full join

          (select * from fund_holdings_model where fund_id=MODEL_ID and trunc(effective_date)=trunc(RUN_DATE)) ModelD 

          on (FUND.security_code=ModelD.security_code)

          full join

          (select * from fund_holdings_model_bod where fund_id=MODEL_ID and trunc(effective_date)=trunc(RUN_DATE)) ModelBOD 

          on (FUND.security_code=ModelBOD.security_code)

          left join

          (

              select security_code, sum(quantity) as TXN_QTY,count(*) as TXN_FLAG from 

              (select security_code, case when sale_purchase_flag = 0 then -1*quantity else quantity end as quantity 

              from TRANSACTION_DATA_MODEL where fund_id=MODEL_ID and trunc(transaction_date)=trunc(RUN_DATE) and active_flag=1) group by security_code

          ) TXN 

          on (TXN.security_code=ModelD.security_code)

          

       ) ALLD

       INNER JOIN 

       security_master SM on (SM.SECURITY_CODE=ALLD.SECURITY_CODE)

       INNER JOIN 

       security_code_bbisin_intmdt MAPP on (SM.SECURITY_CODE=MAPP.BM_CODE)

       order by substr(SM.SECURITY_CODE,1,4), SM.SECURITY_NAME;

       

  end if;





END SP_FE_VALUEAN_DATA; 

