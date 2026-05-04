PROCEDURE SP_FE_ESTIMATES_NAME(ResultSet out SYS_REFCURSOR) AS

BEGIN

 OPEN ResultSet FOR

select estimate_id,estimate_name from KM_ESTIMATE_MASTER where estimate_id in

(select distinct estimate_id from KM_SECURITY_ESTIMATES)

order by estimate_id;





END SP_FE_ESTIMATES_NAME;

