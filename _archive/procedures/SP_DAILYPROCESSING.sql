procedure sp_dailyprocessing



begin



--  DValuefyDataLoadProcess  == reports formula with One procedure attribution.xlsx



select *  from all_tab_columns where upper(column_name) like 'TICKER%';

select * from security_master where   security_code like 'INEQ%'   and upper( security_name) like '%HDFC%'  or security_name like '%UPL%' ; ---- AND instrument_type_id=1; --INE192R01011

select * from security_code_mapping_intmdt where source_security_code ='INE192R01011' ;

select * from sectors where sector_name like 'Consumer%';

   

select * from security_sector_mapping where security_code = 'INEQ00004398'; 



select wm_concat(report_id) from report_references  where to_date >='29-OCT-2023' and  report_id in 

(select report_id from security_attribution_data where security_code = 'INEQ00002675') and daily_default_report_flag = 0;



select wm_concat(report_id) from security_attribution_data where security_code = 'INEQ00004126' and

 report_id in (select report_id from report_references where fund_id in (8));



insert into customized_report_references

select distinct rr.report_id,fund_id,index_id from report_references rr, security_attribution_data sad where

sad.report_id=rr.report_id and

daily_default_report_flag=0 and to_date between '10-Aug-2025' and '17-Aug-2025' and fund_id in (1,20)

-- and sad.security_code in 

--('INEQ00003296','INEQ00003259','INEQ00003292','INEQ00003308','INEQ00003310','INEQ00003324','INEQ00003144','INEQ00003301','INEQ00003259')

;



Delete   FROM PORTFOLIO_WEIGHT WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS_SECTOR WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS_SECURITY WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS_SECDD WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS_STYLE WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM PORTFOLIO_WEIGHT WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM DEFAULT_TREND_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM DEFAULT_ATTRIB_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM DEFAULT_ATTRIB_MONTHLY_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM DEFAULT_ROLLING_RETURNS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM SECURITY_DRILLDOWN_ATTRIB_DATA WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM SECURITY_ATTRIBUTION_DATA WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM FUND_ATTRIBUTED_DATA WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM SECTOR_ATTRIBUTED_DATA WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM TREND_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM CUSTOM_REPORTS WHERE REPORT_ID IN (SELECT REPORT_ID  FROM customized_report_references )  ;

  Delete   FROM SECURITY_MERGE_DAILY;





delete from CUSTOM_REPORTS ;

delete from CUSTOM_REPORTS_SECTOR ;

delete from CUSTOM_REPORTS_SECURITY;

delete from CUSTOM_REPORTS_SECDD ;

delete from CUSTOM_REPORTS_STYLE ;

delete from CUSTOM_REPORTS_FUND;

delete from report_references where daily_default_report_flag=2;





select count(*) FROM (

select * from report_references where report_id not in (select report_id from fund_attributed_data) 

AND REPORT_ID  NOT IN (SELECT REPORT_ID FROM REPORT_REF_GROUPS)  AND DAILY_DEFAULT_REPORT_FLAG IN (0) ) ;



 --- NIPPON EQUITY PROCS

execute SP_VALAT_SECRET;

execute SP_VALAT_PORTRET;

execute SP_VALAT_SECTRET;

execute SP_VALAT_SECVALATT;

execute SP_VALAT_SECTATT;

execute SP_VALAT_PORTATT;

execute sp_valat_secdrlatt;

execute SP_VALAT_TRNDATT_DAILY;



delete from CUSTOM_REPORTS ;

delete from CUSTOM_REPORTS_SECTOR ;

delete from CUSTOM_REPORTS_SECURITY;

delete from CUSTOM_REPORTS_SECDD ;

delete from CUSTOM_REPORTS_STYLE ;

delete from CUSTOM_REPORTS_FUND;

delete from report_references where daily_default_report_flag=2;







-- RET CHECK 

   select rr.from_date, rr.to_date, rr.fund_id, rr.index_id, sm.security_name, sad.* from report_references rr		

	join security_attribution_data sad on rr.report_id=sad.report_id	

	join security_master sm on sad.security_code=sm.security_code	

	join funds f on rr.fund_id=f.fund_id 	

	where rr.fund_id in (select fund_id from funds where  active_inactive_flag=1) 	

	and rr.daily_default_report_flag=0 and rr.to_date  >='10-apr-2024' and sad.security_code like '%INEQ%'

  and abs(sad.portfolio_return) >0.2 order by abs(sad.portfolio_return)  desc;

  

  -- Br_Pr

  select rr.to_date,rr.fund_id,fm.fund_name,rr.index_id,ind.index_name,fad.benchmark_return,fad.bm_nav_ret, fad.portfolio_return,fad.p_nav_ret  

from fund_attributed_data fad, report_references rr,funds fm, indices ind

where fad.report_id=rr.report_id and fm.fund_id=rr.fund_id and ind.index_id=rr.index_id and

rr.to_date='23-Sep-2024';

  

  -------------------Cash Recreate -------------------

select * from fund_holdings where fund_id=121 and effective_date between '03-JUL-2023'  and '31-JUL-2023' and security_code like 'INCA%';

select * from transaction_data where fund_id=121 and transaction_date between '03-JUL-2023'  and '31-JUL-2023' and transaction_type_id in (2,4); 

  execute SP_CASH_HLDS_BATCH_FUND (121,'03-JUL-2023','31-JUL-2023');

execute SP_DIVIDEND_TXNS_BATCH_FUND (121,'03-JUL-2023','31-JUL-2023');

execute SP_CASH_TXNS_BATCH_FUND  (121,'03-JUL-2023','31-JUL-2023');



  -- sector update

  select * from security_master where lower(security_name) like '%bupa%';



select * from security_sector_mapping where security_code='INEQ00003522';

select * from sectors;

update security_sector_mapping set sector_id=23 where security_code='INEQ00003522' and sector_class_id=1;

update security_sector_mapping set sector_id=104 where security_code='INEQ00003522' and sector_class_id=3;

update security_master set sector_id=23,sector_id2=104 where security_code='INEQ00003522' ;

  

  

  ---new fno

  

  Insert into security_master (SECURITY_CODE,INSTRUMENT_TYPE_ID,SECURITY_NAME,SECTOR_ID,EXCHANGE_ID,ISIN_NUMBER,NSE_SYMBOL,BSE_SCRIP_CODE,OPTION_TYPE,STRIKEPRICE,SECTOR_ID2,EXPIRY_DATE,CURRENCY_ID) values 

('INFT00018358',3,'PNBHOUSING_29/05/2025',6,1,null,null,null,null,null,6,'29-May-2025',null);

Insert into security_master (SECURITY_CODE,INSTRUMENT_TYPE_ID,SECURITY_NAME,SECTOR_ID,EXCHANGE_ID,ISIN_NUMBER,NSE_SYMBOL,BSE_SCRIP_CODE,OPTION_TYPE,STRIKEPRICE,SECTOR_ID2,EXPIRY_DATE,CURRENCY_ID) values 

('INFT00018359',3,'INOXWIND_29/05/2025',23,1,null,null,null,null,null,23,'29-May-2025',null);



Insert into security_code_mapping_intmdt (SOURCE_SECURITY_CODE,BM_CODE,INSTRUMENT_NAME,SRC_FLAG) values 

('PHFPMAY25','INFT00018358','FUTURES','DB');

Insert into security_code_mapping_intmdt (SOURCE_SECURITY_CODE,BM_CODE,INSTRUMENT_NAME,SRC_FLAG) values 

('INOWMAY25','INFT00018359','FUTURES','DB');



Insert into security_underliers (SECURITY_CODE,UNDERLIER_CODE,UNDERLIER_TYPE) values 

('INFT00018358','INEQ00002010','EQUITY');

Insert into security_underliers (SECURITY_CODE,UNDERLIER_CODE,UNDERLIER_TYPE) values 

('INFT00018359','INEQ00001407','EQUITY');

  

  --Report_creation



  

insert into report_references (fund_id, index_id, date_generated, from_date, to_date, daily_default_report_flag)

 select fn.fund_id,(select funds.DEFAULT_INDEX_ID from funds where funds.FUND_ID = fn.FUND_ID ) as index_id,sysdate,

 (select max(value_date) from fund_nav fn1 where fn1.value_date<fn.value_date and fn.fund_id=fn1.fund_id) as PrevDate,fn.value_date,0

 from fund_nav fn where fn.value_date >'03-jul-2025' and fund_id in (Select fund_id from funds where offshore_flag=0 and fund_id in (126))

order by fn.fund_id, fn.VALUE_DATE;



  

end ;