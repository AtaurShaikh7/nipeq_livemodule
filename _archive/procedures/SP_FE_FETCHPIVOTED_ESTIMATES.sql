PROCEDURE SP_FE_FETCHPIVOTED_ESTIMATES(SECURITY_CODE IN VARCHAR2, RUNDATE IN DATE, RESULTSET OUT SYS_REFCURSOR)

AS

FYEND_DATE DATE;

START_PER DATE;

END_PER DATE;

AggList clob;

SQLQuery clob;

BEGIN



select end_date into FYEND_DATE from KM_FISCAL_YEAR_CAL where RUNDATE between start_Date and end_date;



select add_months(trunc(FYEND_DATE), -12*3),add_months(trunc(FYEND_DATE), 12) into START_PER,END_PER FROM DUAL;



select listagg('''' || FY_YEAR || ''' AS ' || FY_YEAR || '"', ',') within group (order by FY_YEAR) INTO AggList