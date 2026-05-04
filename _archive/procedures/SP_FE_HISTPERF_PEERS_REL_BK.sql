PROCEDURE SP_FE_HISTPERF_PEERS_REL_BK (FUNDID in number,RUN_DATE in Date,REP_TYPE in VARCHAR,ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

INDEXID Number;



BEGIN



if (rep_type <> 'LIVE') then

EFFECT_DATE := RUN_DATE;

else

select max(EFFECTIVE_DATE) into EFFECT_DATE from business_calendar where businessday_flag=1 and trunc(effective_date) < TRUNC(RUN_DATE);

end if;



 SELECT default_index_id into INDEXID FROM FUNDS WHERE fund_id= fundid;

 

open ResultSet for 



select Fund_NAME,FUND_NAV,RET_1D,RET_5D,RET_1M,RET_3M,RET_YTD from(

select F.Short_Name as Fund_Name,nvl(FNR.nav_value,NVL(FN.NAV_PER_UNIT,0)) as FUND_NAV,

NVL(FNR.ret_1d,0) as RET_1D,NVL(FNR.ret_5d,0) as RET_5D,NVL(FNR.ret_1m,0) as RET_1M,NVL(FNR.ret_3m,0) as RET_3M,

NVL(FNR.ret_ytd,0) as RET_YTD

from  funds F

left join (select * from fund_nav_returns  where TRUNC(Effective_date) = TRUNC(EFFECT_DATE))FNR on F.fund_id = FNR.fund_id

left join (select * from fund_nav where  TRUNC(VALUE_DATE) = TRUNC(EFFECT_DATE)) FN ON F.FUND_ID = FN.FUND_ID

where F.fund_id = FUNDID 

union all

/*

select I.INDEX_SHORT_NAME as Fund_Name,nvl(nvl(INR.closing_value,IP.Closep),0) as FUND_NAV,nvl(INR.ret_1d,0) as RET_1D,nvl(INR.ret_5d,0)  as RET_5D,nvl(INR.ret_1m,0)  as RET_1M,nvl(INR.ret_3m,0) as RET_3M,nvl(INR.ret_ytd,0)  as RET_YTD

from indices I

left join (select * from index_returns  where TRUNC(Effective_date) = TRUNC(EFFECT_DATE)) INR on I.index_id = INR.index_id

left join index_prices IP on IP.index_id = I.index_id

where I.index_id = INDEXID and IP.Price_date = TRUNC(EFFECT_DATE)

UNION*/

select I.INDEX_SHORT_NAME as Fund_Name,nvl(nvl(INR.closing_value,IP.Closep),0) as FUND_NAV,nvl(INR.ret_1d,0) 

as RET_1D,nvl(INR.ret_5d,0)  as RET_5D,nvl(INR.ret_1m,0)  as RET_1M,nvl(INR.ret_3m,0) as RET_3M,nvl(INR.ret_ytd,0)  as RET_YTD

from indices I

left join (select * from index_returns  where TRUNC(Effective_date) = TRUNC(EFFECT_DATE)) INR on I.index_id = INR.index_id

left join index_prices IP on IP.index_id = I.index_id

where I.index_id in (

select II.Index_id from INDICES II  where II.index_id = INDEXID

union

select case when II.index_type='COMPOSITE' then CI.Part_INDEX_ID else II.index_id

end from INDICES II inner join (select * from composite_indices where instrument_type_id = 1) CI on ii.index_id=ci.index_id

and ii.index_id=INDEXID)

and IP.Price_date = TRUNC(EFFECT_DATE)





/*union 

select I.INDEX_SHORT_NAME as Fund_Name,nvl(nvl(INR.closing_value,IP.Closep),0) as FUND_NAV,nvl(INR.ret_1d,0) 

as RET_1D,nvl(INR.ret_5d,0)  as RET_5D,nvl(INR.ret_1m,0)  as RET_1M,nvl(INR.ret_3m,0) as RET_3M,nvl(INR.ret_ytd,0)  as RET_YTD

from indices I

left join (select * from index_returns  where TRUNC(Effective_date) = TRUNC(EFFECT_DATE)) INR on I.index_id = INR.index_id

left join index_prices IP on IP.index_id = I.index_id

where I.index_id in (

select case when II.index_type='COMPOSITE' then CI.Part_INDEX_ID else II.index_id

end from INDICES II inner join composite_indices CI on ii.index_id=ci.index_id and ii.index_id=INDEXID)

and IP.Price_date = TRUNC(EFFECT_DATE)*/



union all

select  F.fund_short_name as Fund_Name,nvl(PNR.nav_value,0) as FUND_NAV,nvl(PNR.ret_1d,0) as RET_1D,nvl(PNR.ret_5d,0)  as RET_5D,nvl(PNR.ret_1m,0) as RET_1M,nvl(PNR.ret_3m,0) as RET_3M,nvl(PNR.ret_ytd,0)  as RET_YTD

from funds_peers F

left join (select * from peers_nav_returns where TRUNC(Effective_date) = TRUNC(EFFECT_DATE)) PNR 

on F.fund_id = PNR.fund_id

where F.fund_id in (select peer_fund_id from funds_peers_mapping where fund_id = FUNDID));     





END SP_FE_HISTPERF_PEERS_REL_BK;