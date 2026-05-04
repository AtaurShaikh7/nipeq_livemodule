PROCEDURE SP_FE_LOGINID_FN_EML (ResultSet out SYS_REFCURSOR)

AS

BEGIN

OPEN ResultSet for

SELECT LOGIN_ID,FIRST_NAME, EMAIL_ID 

FROM USERS where login_id in (select distinct fm_id from funds);

END SP_FE_LOGINID_FN_EML;