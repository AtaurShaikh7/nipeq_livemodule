PROCEDURE SP_UPDATE_ALERTPRICE (ANALYSTID in varchar2,SECURITYCODE in varchar2,ALERTPRICE in NUMBER,PRICEVALUE in number,FLAG in VARCHAR2)

AS



BEGIN

IF FLAG = 'E' THEN

UPDATE KM_SECPRICE_ALERTS 

SET alert_price = alertprice, price= PRICEVALUE, upper_lower_limit=case when PRICEVALUE > alertprice then 0 else 1 end  , isdelete_flag=0

WHERE UPPER(analyst_id) = UPPER(analystid) AND UPPER(security_code) = UPPER(securitycode);



ELSIF FLAG = 'A' THEN

INSERT INTO km_secprice_alerts (analyst_id, security_code, alert_price, set_date, price, upper_lower_limit, isdelete_flag) 

VALUES(analystid, securitycode, alertprice,SYSDATE, PRICEVALUE,case when PRICEVALUE > alertprice then 0 else 1 end ,0); 



ELSE

DELETE FROM KM_SECPRICE_ALERTS WHERE UPPER(analyst_id) = UPPER(analystid) AND UPPER(security_code) = UPPER(securitycode);



END IF;

END;