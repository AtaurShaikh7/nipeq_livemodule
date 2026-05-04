PROCEDURE SP_FE_FMANALYST_DATA_REL_TEST (RUN_DATE in Date,LOGINID in VARCHAR2,SORTBYCOL in VARCHAR2, ResultSet out SYS_REFCURSOR)

as

EFFECT_DATE Date;

INDEXID Number;

CHECK_EXIST number;

TXN_TOL Number(25,10);

FUND_AUM Number(25,10);

IndexName varchar(50); 

cnt NUMBER;



BEGIN

    

    DELETE FROM FM_ANL_DATA;

    

    insert into usersaccess_log(login_id,activity_date,activity,page_name) values(LOGINID,SYSDATE,'FMReport Created for:'|| RUN_DATE,'FM PAGE');

        

    Insert into FM_ANL_DATA (FUND_NAME,FM_NAME,IDX_NAME,SECURITY_NAME,SECURITY_CODE,SECTOR_NAME,TOTALQTY,TOTALINVEST,CMP,MCAP,FUNDWGT,MARKETVALUE,SHARES,OU,AUM,ANALYST,RET1D,RET5D,RET1M,RET3M,RET6M,RET1Y,RETYTD,SECURITY_TYPE,BV,PERCHANGE)

    select f.short_name as fund_name

    , f.fund_manager_name as FM_NAME, i.index_name as IDX_NAME

    , substr(sm.security_name,0,35) as SECURITY_NAME,sm.security_code

    , sect.sector_name AS SECTOR_NAME,

    --cast(fhm.TotalQty as number) as TOTALQTY, round(fhm.TotalInv,1) as TOTALINVEST,

    TOTALQTY,TotalInv as TOTALINVEST,

    sr.CLOSEP as CMP,

    sr.marketcap as mcap

    ,fhm.fundwgt AS FUNDWGT

    , round((fhm.mtm_value/10000000),1) as MARKETVALUE, 

    fhm.quantity as SHARES, 

    (nvl(fhm.fundwgt,0) - nvl(ic.weights,0)) as OU,

    AUM

    ,AN.ANALYST_ID AS ANALYST

    ,sr.RET1D as RET1D,sr.RET5D as RET5D, sr.RET1M as RET1M ,sr.RET3M as RET3M,sr.RET6M AS RET6M,

    sr.RET1Y AS RET1Y,sr.RETYTD AS RETYTD,I.INSTRUMENT_NAME as SECURITY_TYPE

    ,BV,PerChange as PERCHANGE

    from

    ( 

      select fund_id, fhs.security_code, quantity, mtm_value, FundWgt, TotalQty,TotalInv, AUM,BV,PerChange from

      (

        select nvl(FHI.fund_id,BSE.fund_id) as fund_id, nvl(fhi.security_code,bse.security_code) as security_code, quantity, mtm_value,FundWgt,nvl(FHI.AUM,BSE.AUM) as AUM ,BV,PerChange  from

        (

          select fh.fund_id as fund_id, fh.security_code as security_code, fh.quantity, fh.mtm_value, round((fh.mtm_value/ fn.nav),8) as FundWgt, to_char(fn.nav/10000000,'99,99,99,99,99,99,999') as AUM

          , round((fh.ammortised_book_cost/fh.quantity),2) as BV, 

          case when nvl(fh.ammortised_book_cost,0) = 0 then 0 else round(fh.mtm_value/ fh.ammortised_book_cost - 1,2) end as PerChange

          from fund_holdings fh, fund_nav fn,fund_user_mapping fmapp where fh.fund_id= fn.fund_id and fh.effective_date= fn.value_date

          and TRUNC(fh.effective_date)= TRUNC(RUN_DATE) and fmapp.login_id=LOGINID and fh.fund_id= fmapp.fund_id

        ) FHI

        full join

        (

          select fm.fund_id, ic.security_code, to_char(fn.nav/10000000,'99,99,99,99,99,99,999') as AUM from index_constituents ic, fund_user_mapping fm, fund_nav fn where ic.index_id=9 and TRUNC(ic.effective_date)=TRUNC(RUN_DATE)

          and fm.login_id=LOGINID and fm.fund_id = fn.fund_id and trunc(fn.value_date) = TRUNC(RUN_DATE)

        ) BSE

        on (FHI.fUND_ID=BSE.funD_ID and FHI.SECURITY_CODE=BSE.SECURITY_CODE)

      ) fhs

      left join 

      (

        select security_code, to_char(sum(quantity),'99,99,99,99,99,99,999') as TotalQty,to_char(sum(mtm_value)/10000000,'99,99,99,99,99,999') as TotalInv from 

        fund_holdings where fund_id in (select fund_Id from funds where upper(fund_category) in ('DIVERSIFIED','HYBRID','SECTOR') and fund_id not in (select base_fund_id from normalized_funds))

        and TRUNC(effective_date)=TRUNC(RUN_DATE)

        group by security_code

      ) fht

      on (fht.security_code=fhs.security_code)

    ) fhm

    inner join funds f on (fhm.fund_id=f.fund_id and f.fund_category <> 'Passive')

    inner join indices i on (f.default_index_id=i.index_id)

    left join (select * from index_constituents where TRUNC(effective_date)=TRUNC(RUN_DATE)) ic

    on (f.default_index_id=ic.index_id and ic.security_code=fhm.security_code)

    left join (select to_char(round((ret_1d)*100,1),'9990.0') as RET1D,to_char(round((ret_5d)*100,1),'9990.0') as RET5D

    ,to_char(round(ret_1m*100,1),'9990.0') as RET1M ,to_char(round(ret_3m*100,1),'9990.0') as RET3M,

    to_char(round(ret_6m*100,1),'9990.0') AS RET6M,

    to_char(round(ret_1y*100,1),'9990') AS RET1Y,to_char(round(ret_YTD*100,1),'9990.0') AS RETYTD,

    to_char(marketcap,'99,99,99,99,99,999') as marketcap,to_char(closep,'99,99,99,99,99,999') as closep,security_code,effective_date

    from security_returns where TRUNC(effective_date)=TRUNC(RUN_DATE)) SR

    on (sr.security_code=fhm.security_code)

    inner join

    SECURITY_MASTER SM on (fhm.security_code=SM.security_code) 

    inner join    

    Instruments I on (SM.INSTRUMENT_TYPE_ID = I.Instrument_ID)

    inner join

    SECTORS SECT on (SM.SECTOR_ID=SECT.SECTOR_ID)

    left join

    (select sm5.security_code as security_code,nvl(amapp.analyst_id,'NA') as analyst_id from security_master sm5 left join analyst_security_mapping amapp 

    on(sm5.security_code=amapp.security_code)) AN ON (SM.SECURITY_CODE = AN.SECURITY_CODE)

    order by security_name;

    

    --order by mcap

           

   IF UPPER(SORTBYCOL) = 'MCAP' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by mcap nulls first, security_name) fad;

    

   ELSIF UPPER(SORTBYCOL) = 'SECTOR_NAME' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by SECTOR_NAME nulls first, security_name) fad;

      

    ELSIF UPPER(SORTBYCOL) = 'TOTALINVEST' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by TOTALINVEST nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RET1D' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RET1D AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RET5D' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RET5D AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RET1M' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RET1M AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RET3M' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RET3M AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RET6M' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RET6M AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RET1Y' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RET1Y AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'RETYTD' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by CAST(RETYTD AS NUMBER) nulls first, security_name) fad;   



    ELSIF UPPER(SORTBYCOL) = 'SECURITY_NAME' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by security_name) fad;  

      

      ELSIF UPPER(SORTBYCOL) = 'ANALYST' THEN

      open ResultSet for 

      

      select fad.*, ROWNUM from (select * from fm_anl_data order by ANALYST) fad; 

      

   END IF;



END SP_FE_FMANALYST_DATA_REL_TEST; 