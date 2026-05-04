PROCEDURE SP_FE_TRENDS_ALPHA(PARAMFUNDID IN NUMBER,PARAMINDEXID IN NUMBER,LOGINID IN VARCHAR2,

    RESULTSET_1MA OUT SYS_REFCURSOR,

     RESULTSET_3MA OUT SYS_REFCURSOR

    )AS

 Validate_Check Number;

      BEGIN

      SELECT COUNT(*) INTO validate_check FROM FUND_USER_MAPPING 

      WHERE fund_id = PARAMFUNDID and upper(login_id) = upper(loginid);

      IF validate_check <> 0    THEN  

      

       OPEN RESULTSET_1MA FOR

          select  rr.to_date , tr.P_RET_NAV-tr.BM_RET_NAV as ALPHA from trend_reports tr,report_references rr

          where tr.report_id in (select report_id from report_references where fund_id = PARAMFUNDID and index_id = PARAMINDEXID)

          and tr.MONTH_END_FLAG=1 --tr.report_id in (select report_id from trend_reports where UPPER(data_level) = 'SECTOR')

          and rr.report_id=tr.report_id and upper(data_level)='FUND' and upper(span)='1 MONTH' ORDER BY TO_DATE;

        OPEN RESULTSET_3MA FOR

          select  rr.to_date, tr.P_RET_NAV-tr.BM_RET_NAV as ALPHA from trend_reports tr,report_references rr

          where tr.report_id in (select report_id from report_references where fund_id = PARAMFUNDID and index_id = PARAMINDEXID)

          and tr.MONTH_END_FLAG=1 --tr.report_id in (select report_id from trend_reports where UPPER(data_level) = 'SECTOR')

          and rr.report_id=tr.report_id and upper(data_level)='FUND' and upper(span)='3 MONTHS' ORDER BY TO_DATE;

      

      END IF;    

END SP_FE_TRENDS_ALPHA;

 

 

 

 

 