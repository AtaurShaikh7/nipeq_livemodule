PROCEDURE SP_FE_TXN_TRANSACTION_ANALYSER (PREVDATE in DATE,CURRDATE IN DATE,LOGINID IN VARCHAR2,

RESULTSET OUT SYS_REFCURSOR,PriceFlag Number)

AS

PriceDate Date;

BEGIN



  if(priceflag =1) then

    

    select MAX(price_date) into PriceDate from security_closeprices;

  

  else

  

    select max(price_date) into PriceDate from security_closeprices where price_date <= currdate;

  

  end if;

  

    Delete from fund_holdings_cp_temp;

    

    insert into fund_holdings_cp_temp

    select fsc.fund_id, fsc.security_code,max(price_date) as pdate

    from fund_security_closeprices fsc

    where fsc.price_date <= PriceDate

    group by fsc.fund_id, fsc.security_code;

    

  

 insert into usersaccess_log(login_id,activity_date,activity,page_name) values(LOGINID,SYSDATE,'Transaction Analyser report created :'|| PREVDATE ||'-'||CURRDATE,'Transaction Analyser Page');

  open resultset for

      

      

      select TXN_DATE,FUND_NAME,SECURITY_NAME,TXNTYPE,QTY,AMOUNT,CPRICE,ISIN,round(LATEST_PRICE/nvl(fac_latest.factor,1),2) as LATEST_PRICE from (

      select ALTD.transaction_date as TXN_DATE, f.short_name as FUND_NAME, f.fund_manager_name as FM_NAME,

      SUBSTR(sm.security_name,0,35) AS SECURITY_NAME, case when nvl(ALTD.sale_purchase_flag,0) <> 0 then 'Buy' else 'Sell' end as TXNTYPE,

      sum(ALTD.QTY) * nvl(fac.factor,1) as QTY ,round(sum(ALTD.Amount)/10000000,8) as AMOUNT , 

      case when sum(ALTD.QTY) <> 0 then round(abs(sum(ALTD.Amount)/sum(ALTD.QTY * nvl(fac.factor,1))),8) else 0 end as CPRICE,

      MAPP.SOURCE_SECURITY_CODE AS ISIN,sm.security_code,NVL(NSEP.CLOSEP,NVL(BSEP.CLOSEP,FSECP.CLOSEP)) as LATEST_PRICE

      ,NVL(NSEP.price_date,NVL(BSEP.price_date,FSECP.price_date)) as LATEST_PRICE_DATE,FAC.FACTOR,ALTD.sale_purchase_flag

      from

      (

          select td.transaction_date,td.fund_id,td.security_code, 

          case when td.sale_purchase_flag = 0 then -1*td.quantity else td.quantity end as qty,

          case when td.sale_purchase_flag = 0 then -1*Td.consideration else td.consideration end as amount,

          td.sale_purchase_flag

          from transaction_data td

          where TRUNC(td.transaction_date) >= trunc(PREVDATE)

          and TRUNC(td.transaction_date) <= trunc(CURRDATE) and td.transaction_type_id=1

      )

      ALTD

      inner join funds f

      on f.fund_id = altd.fund_id

      inner join security_Master sm on sm.security_code = altd.security_code

      inner join fund_user_mapping fmapp on fmapp.fund_id = f.fund_id

      inner join sectors s on s.sector_id = sm.sector_id

      left join 

      (

        select sc.security_code as security_code,sc.closep as closep, gsc.price_date from

        (

        select security_code,max(price_date) as price_date from security_closeprices 

        where price_date <= Pricedate

        group by security_code

        )gsc

        inner join 

        security_closeprices sc

        on gsc.security_code = sc.security_code

        where sc.price_date = gsc.price_date and sc.exchange_id=1

      )NSEP

      on NSEP.security_code = sm.security_code

      left join

      (

        select sc.security_code as security_code, sc.closep as closep, gsc.price_date from

        (

        select security_code,max(price_date) as price_date from security_closeprices 

        where price_date <= Pricedate

        group by security_code

        )gsc

        inner join 

        security_closeprices sc

        on gsc.security_code = sc.security_code

        where sc.price_date = gsc.price_date and sc.exchange_id=2

      )BSEP

      on BSEP.security_code=sm.security_code

      left join

      (

        select fsc.fund_id as fund_id,fsc.security_code as security_code,fsc.price_date as price_date,fsc.closep as closep from

        (

          select fund_id, security_code,pdate

         from fund_holdings_cp_temp

        )GCP

        inner join fund_security_closeprices fsc

        on fsc.security_code = GCP.security_code and fsc.fund_id = GCP.fund_id

        where fsc.price_date = gcp.pdate

      )FSecP

      on FSecP.fund_id = f.fund_id and FsecP.security_code = sm.security_code

      left join SECURITY_CODE_BBISIN_INTMDT MAPP ON MAPP.BM_CODE = SM.SECURITY_CODE

      left join 

      (

        select  bc.effective_date,MTM.SECURITY_CODE,round(exp(sum(ln(mtm.denominator/ mtm.numerator))),3) as factor

        from  business_calendar bc left join mtm_affecting_cas mtm 

        on TRUNC(mtm.EFFECTIVE_DATE)> TRUNC(bc.effective_date) 

        where TRUNC(bc.Effective_date)>= trunc(PREVDATE) and mtm.corporate_action_type_id in (2,3)

        group by bc.effective_date,MTM.SECURITY_CODE

      ) fac

      ON FAC.SECURITY_CODE = SM.SECURITY_CODE AND TRUNC(ALTD.transaction_date) = TRUNC(FAC.EFFECTIVE_DATE)

      where f.fund_category <>'Passive' and UPPER(fmapp.login_id) = UPPER(loginid) and s.sector_id not in (1,20)

      group by transaction_date,ALTD.sale_purchase_flag,f.SHORT_NAME,NSEP.closep,FSecP.closep,BSEP.closep,NSEP.price_date,FSecP.price_date,BSEP.price_date,

      f.fund_manager_name,sm.security_name, MAPP.SOURCE_SECURITY_CODE,fac.factor,sm.security_code

      ) ALTDD

      left join 

      (

        select  bc.effective_date,MTM.SECURITY_CODE,round(exp(sum(ln(mtm.denominator/ mtm.numerator))),3) as factor

        from  business_calendar bc left join mtm_affecting_cas mtm 

        on TRUNC(mtm.EFFECTIVE_DATE)> TRUNC(bc.effective_date) 

        where TRUNC(bc.Effective_date)>=trunc(PREVDATE) and mtm.corporate_action_type_id in (2,3)

        group by bc.effective_date,MTM.SECURITY_CODE

      ) fac_latest

      on fac_latest.effective_date = altdd.latest_price_date and fac_latest.security_code = altdd.security_code;

end SP_FE_TXN_TRANSACTION_ANALYSER;