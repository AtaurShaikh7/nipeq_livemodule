PROCEDURE SP_TRANSF_TRANSACTION_MODEL AS 



UnmapSecurityCnt number;

UnmapSecurityExc exception;

CURR_DATE date;

ERRMSG varchar2(500);





BEGIN



   SELECT CURRDATADATE INTO CURR_DATE FROM DAILY_PROCESS_STATS WHERE UPPER(PROCESS_NAME) = 'ETL STAGE 2';



   select count(*) into UnmapSecurityCnt from 

   (select security_isin from index_data_model_src where effective_date=CURR_DATE union 

   select security_isin from fund_holdings_src_model where  effective_date=CURR_DATE) a

   where a.security_isin not in(select source_security_code from security_code_mapping_intmdt);

   

   IF UnmapSecurityCnt<>0 THEN

   Raise UnmapSecurityExc;

   

   END IF;

   

   insert into index_constituents (index_id,effective_date,security_code,weights)

   select  case when idc.index_code='Large Cap MP Index' then 51 else 52 end as index_id,idc.effective_date ,

   scmi.bm_code,weightage/100 as weights

   from index_data_model_src idc  

   join security_code_mapping_intmdt scmi

   on(idc.security_isin=scmi.source_security_code)

   where idc.effective_date=CURR_DATE;

   





   insert into fund_holdings(fund_id,effective_date,security_code,quantity,mtm_value,weight) 

   select case when fund_code='Mid Cap MP' then 87 else 86 end as fund_id,fh.effective_date,scmi.bm_code,

   fh.quantity,fh.mtm_value,fh.weightage

   from fund_holdings_src_model fh 

   join security_code_mapping_intmdt scmi

   on(fh.security_isin=scmi.source_security_code)

   where  fh.effective_date=CURR_DATE;

     

   

   

   

EXCEPTION 



WHEN UnmapSecurityExc THEN

UPDATE DAILY_PROCESS_STATS SET STATUS = 'SP_TRANSF_TRANSACTION_MODEL -Isin missing in Security_code_mapping_intmdt table :'   where UPPER(PROCESS_NAME) = 'ETL STAGE 2';



WHEN OTHERS THEN

ERRMSG:=substr(SQLERRM, 1, 200);

--ERRCODE:=SQLCODE;

UPDATE DAILY_PROCESS_STATS SET STATUS = 'SP_TRANSF_TRANSACTION_MODEL - '||ERRMSG || ' ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE where UPPER(PROCESS_NAME) = 'ETL STAGE 2';



COMMIT; 

END SP_TRANSF_TRANSACTION_MODEL;