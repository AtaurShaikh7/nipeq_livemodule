PROCEDURE SP_FE_KM_SECURITY_DATA 

(SECURITYCODE in VARCHAR2,RESULTSET OUT SYS_REFCURSOR)

AS

BEGIN

 open resultset for

 select Effective_date ,NVL(Target_price,0) as Target_price,NVL(Bloom_target_price,0) as Bloom_target_price ,nvl(PRICE,0) as PRICE

 from km_sec_dy_factors 

 where security_code= securitycode

 order by EFFECTIVE_DATE;

 

END SP_FE_KM_SECURITY_DATA;

