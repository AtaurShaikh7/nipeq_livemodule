PROCEDURE SP_FE_LIQUIDATE (RunDate in Date,LOGINID in varchar2,percentliqd in number,NDays in number,ResultSet out SYS_REFCURSOR)

as

percentliq NUMBER(25,10);

BEGIN



INSERT INTO USERSACCESS_LOG (LOGIN_ID,ACTIVITY_DATE,ACTIVITY,PAGE_NAME)

   VALUES (LOGINID,SYSDATE,'Liquidity Report Created for : ' || RunDate , 'LIQUIDITY PAGE');



percentliq :=percentliqd;



 open ResultSet for 

select fh.fund_id,INS.instrument_name as INSTRUMENT_TYPE ,

f.fund_name as FUND_NAME,sm.SECURITY_NAME,S.SECTOR_NAME as SECTOR,

f.FUND_MANAGER_NAME as FUND_MANAGER,

fh.effective_date,fh.mtm_value as MTM ,fh.quantity as QUANTITY,

I.INDEX_NAME AS FUND_INDEX,sdf.AVGVOLUME_3M,percentliq * sdf.AVGVOLUME_3M as VOLUME,

--round(fh.quantity/(percentliq * sdf.avg_Volume),0) as LIQUIDATE_DAYS,

CEIL(fh.quantity/(percentliq * sdf.AVGVOLUME_3M)) as LIQUIDATE_DAYS,

case when round((ndays/(fh.quantity/(percentliq*sdf.AVGVOLUME_3M))),8) > 1  then 1

else round((ndays/(fh.quantity/(percentliq*sdf.AVGVOLUME_3M))),8)

end as LIQUIDITY,

CASE WHEN ((Quantity - (NDays * percentliq * sdf.AVGVOLUME_3M)) * (MTM_VALUE/QUANTITY)) <= 0 THEN 0 ELSE ((Quantity - (NDays * percentliq * sdf.AVGVOLUME_3M)) * (MTM_VALUE/QUANTITY)) END AS AMT_OUTSTANDING,

FN.NAV as AUM

from 

(select * from fund_holdings where trunc(effective_date)=trunc(RunDate) ) fh 

inner join funds f on (fh.fund_id = f.fund_id AND UPPER(f.FUND_TYPE)='EQ')

left join (select * from average_volume where trunc(effective_date)=trunc(RunDate)) sdf 

on fh.security_code = sdf.security_code and fh.effective_date = sdf.effective_date and sdf.exchange_id = f.exchange_id

inner join (select * from FUND_NAV where trunc(value_date)=trunc(RunDate)) FN on (fh.fund_id = FN.fund_id AND TRUNC(FH.EFFECTIVE_DATE)=TRUNC(FN.VALUE_DATE))

inner join security_master sm on sm.security_code = fh.security_code

inner join sectors s on sm.sector_id = s.sector_id

inner join instruments INS on INS.INSTRUMENT_ID = sm.INSTRUMENT_TYPE_ID

inner join indices i on i.index_id = f.Default_index_id

inner join fund_user_mapping fum on UPPER(fum.LOGIN_ID) = UPPER(LOGINID) and fum.FUND_ID = f.FUND_ID

where trunc(fh.effective_date) = trunc(RunDate) AND SDF.AVGVOLUME_3M IS NOT NULL

order by fund_name;



END SP_FE_LIQUIDATE;