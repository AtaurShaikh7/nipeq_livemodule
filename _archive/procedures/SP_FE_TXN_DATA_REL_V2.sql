PROCEDURE SP_FE_TXN_DATA_REL_V2 (PREV_DATE in Date,CURR_DATE in Date,LOGINID in VARCHAR2, ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

BEGIN

   insert into usersaccess_log(login_id,activity_date,activity,page_name) values(LOGINID,SYSDATE,'Transaction report created :'|| PREV_DATE ||'-'||CURR_DATE,'Transaction Report Page');

    open ResultSet for 

        select ALTD.transaction_date as TXN_DATE, f.short_name as FUND_NAME, f.fund_manager_name as FM_NAME,

        SUBSTR(sm.security_name,0,35) AS SECURITY_NAME, case when sum(ALTD.Amount) >0 then 'Buy' else 'Sell' end as TXNTYPE,

        ROUND(sum(ALTD.QTY))  as QTY,round(sum(ALTD.Amount)/10000000,8) as AMOUNT , 

        case when sum(ALTD.QTY) <> 0 then round(abs(sum(ALTD.Amount)/sum(ALTD.QTY)),8) else 0 end as PRICE 

        , MAPP.SOURCE_SECURITY_CODE AS ISIN from

        (

	        /*select td.transaction_date,td.fund_id,td.security_code, 

	        (case when td.sale_purchase_flag = 0 then -1*td.quantity else td.quantity end) as ogqty,

          ratio,

          (case when td.sale_purchase_flag = 0 then -1*td.quantity else td.quantity end) * NVL(RATIO,1) as qty,

	        case when td.sale_purchase_flag = 0 then -1*Td.consideration else td.consideration end as amount

	        from 

          (

            SELECT * FROM transaction_data

            WHERE TRUNC(transaction_date) >= TRUNC(PREV_DATE)

            and TRUNC(transaction_date) <= TRUNC(CURR_DATE) and transaction_type_id=1

          )td

          LEFT JOIN

          (

            SELECT SECURITY_CODE,SUM(CASE WHEN NVL(NUMERATOR,0) <> 0 THEN NVL(DENOMINATOR,0)/NUMERATOR ELSE 0 END) AS RATIO

            FROM MTM_AFFECTING_CAS

            WHERE CORPORATE_ACTION_TYPE_ID IN (2,3) and (TRUNC(EFFECTIVE_DATE) >= TRUNC(PREV_DATE) AND TRUNC(EFFECTIVE_DATE) <= TRUNC(CURR_DATE))

            GROUP BY SECURITY_CODE

          )CAS

          ON TD.SECURITY_CODE = CAS.SECURITY_CODE*/

          SELECT TRANSACTION_DATE,FUND_ID,SECURITY_CODE,OGQTY,ROUND(OGQTY*NVL(RATIO,1)) AS QTY,RATIO,AMOUNT 

          FROM

          (

            select MAIN_DATA.transaction_date,MAIN_DATA.fund_id,MAIN_DATA.security_code, 

            (case when MAIN_DATA.sale_purchase_flag = 0 then -1*MAIN_DATA.quantity else MAIN_DATA.quantity end) as ogqty,

            --(case when MAIN_DATA.sale_purchase_flag = 0 then -1*MAIN_DATA.quantity else MAIN_DATA.quantity end) * NVL(RATIO,1) as qty,

            case when MAIN_DATA.sale_purchase_flag = 0 then -1*MAIN_DATA.consideration else MAIN_DATA.consideration end as amount,

            (

              SELECT ROUND(EXP(SUM(CASE WHEN NVL(NUMERATOR,0) <> 0 THEN NVL(DENOMINATOR,0)/NUMERATOR ELSE 0 END)),4) FROM MTM_AFFECTING_CAS 

              WHERE CORPORATE_ACTION_TYPE_ID IN (2,3) and EFFECTIVE_DATE >=MAIN_DATA.TRANSACTION_DATE AND EFFECTIVE_DATE <= MAX_CAS_DATE AND SECURITY_CODE = MAIN_DATA.security_code

            )RATIO

            FROM

            (

              SELECT TD.FUND_ID

              ,TD.SECURITY_CODE

              ,TD.TRANSACTION_DATE

              ,TRANSACTION_TYPE_ID

              ,SALE_PURCHASE_FLAG

              ,QUANTITY

              ,CONSIDERATION

              ,(

              SELECT MAX(EFFECTIVE_DATE) FROM MTM_AFFECTING_CAS 

              WHERE SECURITY_CODE = TD.SECURITY_CODE AND corporate_action_type_id IN (2,3) 

              AND TRUNC(EFFECTIVE_DATE) >= TRUNC(TD.TRANSACTION_DATE)

              ) AS MAX_CAS_DATE

              FROM

              (

                SELECT * FROM TRANSACTION_DATA 

                WHERE transaction_data.transaction_type_id = 1 AND TRUNC(transaction_date) >= TRUNC(PREV_DATE) AND TRUNC(transaction_date) <= TRUNC(CURR_DATE)

              )TD

            )MAIN_DATA

          )

        )

        ALTD

        inner join funds f

        on f.fund_id = altd.fund_id

        inner join security_Master sm on sm.security_code = altd.security_code

        inner join fund_user_mapping fmapp on fmapp.fund_id = f.fund_id

        inner join sectors s on s.sector_id = sm.sector_id

        left join SECURITY_CODE_BBISIN_INTMDT MAPP ON MAPP.BM_CODE = SM.SECURITY_CODE

        where f.fund_category <>'Passive' and UPPER(fmapp.login_id) = UPPER(LOGINID) and s.sector_id not in (1,20)

        group by transaction_date,f.SHORT_NAME,f.fund_manager_name, sm.security_name, MAPP.SOURCE_SECURITY_CODE;

  

  END SP_FE_TXN_DATA_REL_V2;