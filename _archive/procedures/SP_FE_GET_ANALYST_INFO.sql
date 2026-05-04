PROCEDURE SP_FE_GET_ANALYST_INFO (ResultSet out SYS_REFCURSOR)

as

BEGIN

open resultset for

select u.first_name,u.login_id,u.email_id from users u;

END SP_FE_GET_ANALYST_INFO;