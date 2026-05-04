PROCEDURE SP_VALAT_GETAUM (REPORTID in NUMBER, FUNDID in NUMBER, TODATE in Date, ResultSet out SYS_REFCURSOR)

AS

BEGIN

 

   if TRUNC(TODATE)=TRUNC(SYSDATE) then

    open ResultSet for 

      Select NAV as AUM,NVL(risk_free_interest_rate,0) * 100 as RISK_RATE, NVL(CR.CLOSEP,1) AS CURRENCYP ,cm.currency_icon as currency_icon

      From FUND_NAV fn 

      inner join 

      FUNDS fu 

      ON fn.fund_id = fu.fund_id

      left join 

      currency_master cm

      ON cm.currency_id = fu.investor_currency

      left join 

      currency_prices CR 

      ON UPPER(CR.CURRENCY_ID) = UPPER(fu.INVESTOR_CURRENCY) AND TRUNC(CR.EFFECTIVE_DATE)=TRUNC(TODATE)

      WHERE fn.FUND_ID = FUNDID AND TRUNC(VALUE_DATE) = (Select TRUNC(TO_DATE) from REPORT_REFERENCES where REPORT_ID = REPORTID); 

      

  else

    

    open ResultSet for 

      Select NAV as AUM,NVL(risk_free_interest_rate,0) * 100 as RISK_RATE, NVL(CR.CLOSEP,1) AS CURRENCYP ,cm.currency_icon as currency_icon

      From FUND_NAV fn 

      inner join 

      FUNDS fu 

      ON fn.fund_id = fu.fund_id

      left join 

      currency_master cm

      ON cm.currency_id = fu.investor_currency

      left join 

      currency_prices CR 

      ON UPPER(CR.CURRENCY_ID) = UPPER(fu.INVESTOR_CURRENCY) AND TRUNC(CR.EFFECTIVE_DATE)=TRUNC(TODATE)

      WHERE fn.FUND_ID = FUNDID AND TRUNC(VALUE_DATE) = TRUNC(TODATE); 

  

  end if;

      

END SP_VALAT_GETAUM;