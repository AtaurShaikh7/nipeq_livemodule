PROCEDURE SP_FE_EMAIL_USERS(ResultSet out SYS_REFCURSOR) AS 

BEGIN

  open resultset for 

  select distinct email_id,to_cc from report_email_users;

END SP_FE_EMAIL_USERS;