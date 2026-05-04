PROCEDURE SP_FE_TXN_SUMMARY_DATA_REL (PREV_DATE in Date,CURR_DATE in Date,LOGINID in VARCHAR2, ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

BEGIN

    open ResultSet for 

        select SUBSTR(sm.security_name,0,35) AS SECURITY_NAME, case when sum(ALTD.Amount) >0 then 'Buy' else 'Sell' end as TXNTYPE,

        sum(ALTD.QTY) as QTY,round(sum(ALTD.Amount)/10000000,8) as AMOUNT , 

        case when sum(abs(ALTD.QTY)) <> 0 then Round(sum(abs(ALTD.Amount))/sum(abs(ALTD.QTY)),8) else 0 end as PRICE from

        (select td.transaction_date,td.fund_id,td.security_code, 

        case when td.sale_purchase_flag = 0 then -1*td.quantity else td.quantity end as qty,

        case when td.sale_purchase_flag = 0 then -1*Td.consideration else td.consideration end as amount

        from transaction_data td where TRUNC(td.transaction_date) >= TRUNC(PREV_DATE)

        and TRUNC(td.transaction_date) <= TRUNC(curr_date) and td.transaction_type_id=1

        )

        ALTD

        inner join funds f

        on f.fund_id = altd.fund_id and f.fm_id = LOGINID

        inner join security_Master sm on sm.security_code = altd.security_code

        inner join fund_user_mapping fmapp on fmapp.fund_id = f.fund_id

        inner join sectors s on s.sector_id = sm.sector_id

        where UPPER(f.fund_category) <>'PASSIVE' and fmapp.login_id = LOGINID and s.sector_id not in (1,20)

        group by sm.security_name;

  

  END SP_FE_TXN_SUMMARY_DATA_REL;