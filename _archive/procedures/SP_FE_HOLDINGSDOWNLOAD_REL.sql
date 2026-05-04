PROCEDURE SP_FE_HOLDINGSDOWNLOAD_REL (RUN_DATE in DATE, ResultSet out SYS_REFCURSOR)

    as

    Begin

    

    OPEN ResultSet FOR 

    

        select fnd.effective_date as HoldingDate,fnd.fund_id as valueAtFundCode,fnd.fund_name as SchemeName,fnd.fund_manager_name as FundManagerName,

        fnd.index_name as FundBenchmark, fnd.fund_category as TypeOfFund, (fnd.fund_aum/10000000) as AUMincr,

        fnd.security_code as ValueAtScripCode,fnd.source_security_code as ISIN,  fnd.security_name as ScripName, fnd.sector_name as Sector,

        round((nvl(idx.weights,0)*100),6) as ScriptWtInBenchMark, round((nvl(fnd.fundwt,0)*100),6) as ScriptWtInFund, fnd.quantity as Quantity,

        round(nvl(fnd.ammortised_book_cost/fnd.quantity,0),6) as BVinRs,round(nvl(fnd.mtm_value/fnd.quantity,0),6) as EODPriceinRs, nvl(fnd.ammortised_book_cost,0)/10000000 as BVcr,nvl(fnd.mtm_value,0)/10000000 as MVcr

        ,fnd.fnd1d as FundRet_1D,fnd.fnd1w as FundRet_1W,fnd.fnd1m as FundRet_1M,fnd.fnd3m as FundRet_3M,fnd.fnd1y as FundRet_1Y

        ,fnd.secret1d as ScripRet_1D,fnd.secret1w as ScripRet_1W,fnd.secret1m as ScripRet_1M,fnd.secret3m as ScripRet_3M,fnd.secret1y as ScripRet_1Y,nvl(fnd.MCAP,0) as MCAP

        from

        (select (fh.effective_date),fh.fund_id, f.fund_name,i.index_id,i.index_name,f.fund_category,

        bbisn.source_security_code,

        fh.security_code,

        case when sect.sector_Id=20 then sect.sector_name else sm.security_name end as security_name,

        sect.sector_name,(fh.mtm_value/aumfnd.fund_aum) as fundwt,round(aumfnd.fund_aum,6) as fund_aum,f.fund_manager_Name, fh.quantity, fh.ammortised_book_cost, fh.mtm_value

        , secret.closep,secret.ret_1d * 100 as secret1d, secret.ret_5d*100 as secret1w, secret.ret_1m*100 as secret1m, secret.ret_3m*100 as secret3m

        ,secret.ret_1y*100 as secret1Y,fndnav.ret_1d*100 as fnd1d,fndnav.ret_5d*100 as fnd1w,fndnav.ret_1m*100 as fnd1m,fndnav.ret_3m*100 as fnd3m,fndnav.ret_1y*100 as fnd1y,secret.marketcap as MCAP

        from 

        (--select * from fund_holdings where TRUNC(effective_date) = TRUNC(RUN_DATE)

          select fh1.fund_id , fh1.effective_date, fh1.security_code, fh1.quantity, fh1.mtm_value,fh1.option_position, fh1.pur_value, fh1.ammortised_book_cost, 

          fh1.accrued_interest from fund_holdings_LIVE fh1 , security_master sm1, sectors sect1 where TRUNC(fh1.effective_date) = TRUNC(RUN_DATE)

          and sm1.security_code= fh1.security_code and sm1.sector_id= sect1.sector_id and sect1.sector_id not in (20)

          union all

          select fh2.fund_id as FUND_ID, fh2.effective_date as EFFECTIVE_DATE, 'CASHEQ000001' as SECURITY_CODE, sum(fh2.quantity) as QUANTITY, 

          sum(fh2.mtm_value) as MTM_VALUE,max(fh2.option_position) as OPTION_POSITION, sum(fh2.pur_value) AS PUR_VALUE, sum(fh2.ammortised_book_cost) as ammortised_book_cost, 

          sum(fh2.accrued_interest) as accrued_interest from fund_holdings_LIVE fh2 , security_master sm2, sectors sect2 where TRUNC(fh2.effective_date) = TRUNC(RUN_DATE)

          and sm2.security_code= fh2.security_code and sm2.sector_id= sect2.sector_id and sect2.sector_id in (20) group by fh2.fund_id,fh2.effective_date, sect2.sector_id

        ) fh

        left join

        (select sum(mtm_value) as fund_aum, fund_id from fund_holdings_LIVE where TRUNC(effective_date) = TRUNC(RUN_DATE) group by fund_id )AUMFND

        on AUMFND.fund_id = fh.fund_id

        inner join security_master sm on sm.security_code = fh.security_code

        inner join (select * from funds where fund_id not in (57,61,73,72)

        and fund_id not in(select FUND_ID from funds where upper(fund_name) like '%ETF%')-- to avoid ETF funds, changes made by Tina, as requested by client

        and fund_id not in( select fund_id from fund_user_mapping where login_id='70280867')-- to remove all funds managed by Payal Wadhwa, as requested by client. Tina again.

        ) f on f.fund_id = fh.fund_id

        inner join Sectors sect on sm.sector_id = sect.sector_id

        inner join Indices I on I.index_id = f.default_index_id

        left join security_code_bbisin_intmdt bbisn on bbisn.bm_code = fh.security_code

        left join (select * from fund_nav_returns where TRUNC(effective_date) = TRUNC(RUN_DATE)) FNDNAV on FNDNAV.fund_id = fh.fund_id

        left join (select * from security_returns where TRUNC(effective_date) = TRUNC(RUN_DATE)) secret on secret.security_code = fh.security_code

        where f.fund_id not in (select base_fund_id from normalized_funds) order by fh.fund_id, fh.security_code )FND

        left join (select * from index_constituents where TRUNC(effective_date) = TRUNC(RUN_DATE)) IDX

        on IDX.index_ID = FND.Index_Id and IDX.security_code = FND.security_code;

        

END SP_FE_HOLDINGSDOWNLOAD_REL;