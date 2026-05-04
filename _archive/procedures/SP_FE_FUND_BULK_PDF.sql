PROCEDURE SP_FE_FUND_BULK_PDF (LOGINID in VARCHAR2,ResultSet out SYS_REFCURSOR)

AS

CHECK_EXISTS NUMBER;

MAX_NAV_DATE DATE;

BEGIN

SELECT COUNT(*) INTO check_exists FROM FUNDS WHERE fm_id = loginid;

SELECT MAX(VALUE_DATE) INTO MAX_NAV_DATE FROM FUND_NAV;



IF(check_exists <> 0) THEN

   open ResultSet for 

   

    SELECT F.FUND_ID FROM FUNDS F

    inner join (select * from fund_nav where TRUNC(value_date) = TRUNC(max_nav_date)) fn on fn.fund_id = f.fund_id

    WHERE upper(F.FM_ID) = upper(LOGINID) and f.fund_category <> 'Passive' and f.fund_id in (select distinct fund_id from fund_user_mapping

    where upper(LOGIN_ID) = upper(LOGINID))

    order by fn.nav desc;

   

   

   ELSE

   open ResultSet for 

   

    SELECT fm.FUND_ID FROM fund_user_mapping fm

    left join funds f on f.fund_id = fm.fund_id

    inner join (select * from fund_nav where TRUNC(value_date) = TRUNC(max_nav_date)) fn on fn.fund_id = f.fund_id

    WHERE upper(fm.login_id) = upper(LOGINID) and f.fund_category <> 'Passive'

    order by fn.nav desc;

   

   END IF;



END SP_FE_FUND_BULK_PDF;