PROCEDURE SP_FE_TXN_DATA_REL_BKP (PREV_DATE in Date,CURR_DATE in Date,LOGINID in VARCHAR2, ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

BEGIN

   insert into usersaccess_log(login_id,activity_date,activity,page_name) values(LOGINID,SYSDATE,'Transaction report created :'|| PREV_DATE ||'-'||CURR_DATE,'Transaction Report Page');

    open ResultSet for 

        select ALTD.transaction_date as TXN_DATE, f.short_name as FUND_NAME, f.fund_manager_name as FM_NAME,

        SUBSTR(sm.security_name,0,35) AS SECURITY_NAME, case when sum(ALTD.Amount) >0 then 'Buy' else 'Sell' end as TXNTYPE,

        sum(ALTD.QTY) as QTY,round(sum(ALTD.Amount)/10000000,8) as AMOUNT , 

        case when sum(ALTD.QTY) <> 0 then round(abs(sum(ALTD.Amount)/sum(ALTD.QTY)),8) else 0 end as PRICE 

        , MAPP.SOURCE_SECURITY_CODE AS ISIN from

        (select td.transaction_date,td.fund_id,td.security_code, 

        case when td.sale_purchase_flag = 0 then -1*td.quantity else td.quantity end as qty,

        case when td.sale_purchase_flag = 0 then -1*Td.consideration else td.consideration end as amount

        from transaction_data td where TRUNC(td.transaction_date) >= TRUNC(PREV_DATE)

        and TRUNC(td.transaction_date) <= TRUNC(curr_date) and td.transaction_type_id=1

        )

        ALTD

        inner join funds f

        on f.fund_id = altd.fund_id

        inner join security_Master sm on sm.security_code = altd.security_code

        inner join fund_user_mapping fmapp on fmapp.fund_id = f.fund_id

        inner join sectors s on s.sector_id = sm.sector_id

        left join SECURITY_CODE_BBISIN_INTMDT MAPP ON MAPP.BM_CODE = SM.SECURITY_CODE

        where f.fund_category <>'Passive' and fmapp.login_id = LOGINID and s.sector_id not in (1,20)

        group by transaction_date,f.SHORT_NAME,f.fund_manager_name, sm.security_name, MAPP.SOURCE_SECURITY_CODE;

  

  END SP_FE_TXN_DATA_REL_BKP;