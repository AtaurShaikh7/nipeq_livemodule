PROCEDURE SP_ALL_FUND_ESTIMATE_ANALYSIS (FUNDID NUMBER, RES OUT sys_refcursor) AS 

START_PER DATE;

END_PER DATE;

--Added for temporary purpose

GETDATE DATE;

BEGIN

  SELECT MAX(EFFECTIVE_DATE) INTO GETDATE FROM FUND_HOLDINGS WHERE FUND_ID = FUNDID;

  select add_months(trunc(sysdate), -12*2),add_months(trunc(sysdate), 12*3) INTO START_PER,END_PER FROM DUAL;

 OPEN RES FOR 

  SELECT CRFE.FY_YEAR,CRFE.ESTIMATE_ID,CRFE.ESTIMATE_NAME,NVL(FDEPS,0) AS FDEPS,

  NVL(PE,0) AS PE,NVL(EVEBITDA,0) AS EVEBITDA,NVL(ADJPAT,0) AS ADJPAT,NVL(BOOKVALSHARE,0) AS BOOKVALSHARE,NVL(EBITDA,0) AS EBITDA,

  NVL(EBITDAMAR,0) AS EBITDAMAR,

  NVL(FDEPSGR,0) AS FDEPSGR,

  NVL(MCAPSALES,0) AS MCAPSALES, NVL(FDEC,0) AS FDEC,NVL(NETDEBT,0) AS NETDEBT,NVL(ROE,0) AS ROE,NVL(ROCE,0) AS ROCE,

  NVL(NETDEBTEQ,0) AS NETDEBTEQ,NVL(NETSALES,0) AS NETSALES,NVL(PATMAR,0) AS PATMAR,NVL(PRICEBOOK,0) AS PRICEBOOK, 

  EFFECTIVE_DATE FROM 

  (

    SELECT * FROM

    (

      SELECT  CASE WHEN EXTRACT(YEAR FROM END_DATE)+1 >= EXTRACT(YEAR FROM GETDATE)THEN 'FY'|| TO_CHAR(END_DATE,'YY')||'E' ELSE 'FY'|| TO_CHAR(END_DATE,'YY') END AS FY_YEAR 

      FROM KM_FISCAL_YEAR_CAL 

      WHERE END_DATE>= START_PER AND END_DATE<= END_PER

    )

    CROSS JOIN

    (

      SELECT  ESTIMATE_ID,ESTIMATE_NAME FROM KM_ESTIMATE_MASTER

    )

  )CRFE

  LEFT JOIN

  (

    SELECT 

   km.FY_YEAR,km.ESTIMATE_Id,

   (SELECT ESTIMATE_NAME FROM KM_ESTIMATE_MASTER WHERE 

   ESTIMATE_Id = km.ESTIMATE_Id AND ROWNUM=1) Estimate_Type_Name,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.FDEPS),10),0) FDEPS,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.PE),10),0) PE,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.EVEBITDA),10),0) EVEBITDA,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.ADJPAT),10),0) ADJPAT,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.BOOKVALSHARE),10),0) BOOKVALSHARE,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.EBITDA),10),0) EBITDA,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.EBITDAMAR),10),0) EBITDAMAR,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.FDEPSGR),10),0) FDEPSGR,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.MCAPSALES),10),0) MCAPSALES,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.FDEC),10),0)FDEC,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.NETDEBT),10),0) NETDEBT,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.ROE),10),0) ROE,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.ROCE),10),0) ROCE,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.NETDEBTEQ),10),0) NETDEBTEQ,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.NETSALES),10),0) NETSALES,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.PATMAR),10),0) PATMAR,

   NVL(round(SUM((NVL(round(((fh.mtm_value + NVL(fh.accrued_interest,0) )/ fn.nav),8),0))* km.PRICEBOOK),10),0) PRICEBOOK,

   KM.EFFECTIVE_DATE

  FROM 

   FUND_HOLDINGS FH

   LEFT JOIN

   KM_SECURITY_ESTIMATES km

   ON FH.SECURITY_CODE = KM.SECURITY_CODE AND FH.EFFECTIVE_DATE = KM.EFFECTIVE_DATE

   INNER JOIN FUND_NAV FN

   ON FN.FUND_ID = FH.FUND_ID AND FH.EFFECTIVE_DATE = FN.VALUE_DATE

   WHERE km.FY_YEAR in (SELECT  CASE WHEN EXTRACT(YEAR FROM END_DATE)+1 >= EXTRACT(YEAR FROM GETDATE)THEN 'FY'|| TO_CHAR(END_DATE,'YY')||'E' ELSE 'FY'|| TO_CHAR(END_DATE,'YY') END AS FY_YEAR FROM KM_FISCAL_YEAR_CAL WHERE END_DATE>= START_PER AND END_DATE<= END_PER) 

   AND FH.EFFECTIVE_DATE = GETDATE

   AND FH.FUND_ID=FUNDID  

   GROUP BY km.FY_YEAR,km.ESTIMATE_ID,KM.EFFECTIVE_DATE

   )ALLD

   ON CRFE.FY_YEAR = ALLD.FY_YEAR AND CRFE.ESTIMATE_ID = ALLD.ESTIMATE_ID

   order by CRFE.FY_YEAR,CRFE.ESTIMATE_ID; 

   

END SP_ALL_FUND_ESTIMATE_ANALYSIS;

