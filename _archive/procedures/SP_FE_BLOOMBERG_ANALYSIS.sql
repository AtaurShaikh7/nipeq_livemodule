PROCEDURE SP_FE_BLOOMBERG_ANALYSIS (RESULTSET OUT SYS_REFCURSOR) 

AS 

CURRDATE date;

PREVDATE date;

DATE1M date;

DATE6M date;

BEGIN

  

  select max(effective_date) into CURRDATE from km_sec_dy_factors;

  

 select max(km.effective_date) into PREVDATE from km_sec_dy_factors km inner join business_calendar bc on km.effective_date= bc.effective_date

  where km.effective_date < CURRDATE and bc.businessday_flag=1;

 --select max(effective_date) into PREVDATE from business_calendar where effective_date < CURRDATE and businessday_flag=1;

 

 select max(km.effective_date) into DATE1M from km_sec_dy_factors km inner join business_calendar bc on km.effective_date= bc.effective_date

  where km.effective_date<= add_months(CURRDATE,-1) and bc.businessday_flag=1;

  

   select max(km.effective_date) into DATE6M from km_sec_dy_factors km inner join business_calendar bc on km.effective_date= bc.effective_date

  where km.effective_date<= add_months(CURRDATE,-6) and bc.businessday_flag=1;

 

-- select max(effective_date) into DATE1M from business_calendar where effective_date<= add_months(CURRDATE,-1) and businessday_flag=1;

 --select max(effective_date) into DATE6M from business_calendar where effective_date<= add_months(CURRDATE,-6) and businessday_flag=1;

 

 

 OPEN RESULTSET FOR 

 

 select curr.SECURITY_CODE,curr.SECURITY_NAME,nvl(prev.bloom_target_price,0) as PREVIOUS_PRICE,

 nvl(curr.bloom_target_price,0) as CURRENT_PRICE, case when prev.bloom_target_price=0 then null else  nvl(round(((curr.bloom_target_price/prev.bloom_target_price)-1),8),0) end  as DEVIATION,

 case when Month_1M.bloom_target_price=0 then null else nvl(round(((curr.bloom_target_price/Month_1M.bloom_target_price)-1),8),0) end  as DEVIATION_1M,

 --case when Month_1M.bloom_target_price=0 then null else nvl(round(((curr.bloom_target_price/Month_6M.bloom_target_price)-1),8),0) 

 0 as DEVIATION_6M

 from (

 select km.security_code, sm.security_name, km.bloom_target_price from km_sec_dy_factors km 

 inner join  security_master sm on km.security_code= sm.security_code

 where trunc(km.effective_date)=trunc(CURRDATE)

 ) curr 

 inner join 

 (

 select  km.security_code, sm.security_name, km.bloom_target_price from km_sec_dy_factors km 

 inner join  security_master sm on km.security_code= sm.security_code

 where trunc(km.effective_date)= trunc(PREVDATE)

 ) prev 

 on curr.security_code=prev.security_code

 inner join 

  (

 select  km.security_code, sm.security_name, km.bloom_target_price from km_sec_dy_factors km 

 inner join  security_master sm on km.security_code= sm.security_code

where trunc(km.effective_date)= trunc(DATE1M)

 ) Month_1M

 on curr.security_code=Month_1M.security_code

/* inner join 

  (

 select  km.security_code, sm.security_name, km.bloom_target_price from km_sec_dy_factors km 

 inner join  security_master sm on km.security_code= sm.security_code

 where trunc(km.effective_date)= trunc(DATE6M)

 ) Month_6M

 on curr.security_code=Month_6M.security_code*/;

 

  

END SP_FE_BLOOMBERG_ANALYSIS;

