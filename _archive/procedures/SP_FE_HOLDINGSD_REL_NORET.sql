PROCEDURE SP_FE_HOLDINGSD_REL_NORET (RUN_DATE in DATE, ResultSet out SYS_REFCURSOR)

    as

    Begin

    

    OPEN ResultSet FOR 

    select fnd.effective_date as HoldingDate,fnd.fund_id as valueAtFundCode,fnd.fund_name as SchemeName,fnd.fund_manager_name as FundManagerName,

    fnd.index_name as FundBenchmark, fnd.fund_category as TypeOfFund, (fnd.fund_aum/10000000) as AUMincr,

    fnd.security_code as ValueAtScripCode,fnd.source_security_code as ISIN,  fnd.security_name as ScripName, fnd.sector_name as Sector,

    round((nvl(idx.weights,0)*100),6) as ScriptWtInBenchMark, round((nvl(fnd.fundwt,0)*100),6) as ScriptWtInFund, fnd.quantity as Quantity,

    round(nvl(fnd.ammortised_book_cost/fnd.quantity,0),6) as BVinRs,round(nvl(fnd.mtm_value/fnd.quantity,0),6) as EODPriceinRs, nvl(fnd.ammortised_book_cost,0)/10000000 as BVcr,nvl(fnd.mtm_value,0)/10000000 as MVcr

    from

    (select (fh.effective_date),fh.fund_id, fh.security_code, f.fund_name,i.index_id,i.index_name,f.fund_category,sm.security_name,

    sect.sector_name,(fh.mtm_value/aumfnd.fund_aum) as fundwt,round(aumfnd.fund_aum,6) as fund_aum,f.fund_manager_Name, fh.quantity, fh.ammortised_book_cost, fh.mtm_value, bbisn.source_security_code

    from fund_holdings fh

    left join

    (select sum(mtm_value) as fund_aum, fund_id from fund_holdings where TRUNC(effective_date) = TRUNC(RUN_DATE) group by fund_id )AUMFND

    on AUMFND.fund_id = fh.fund_id

    inner join security_master sm on sm.security_code = fh.security_code

    inner join funds f on f.fund_id = fh.fund_id

    inner join Sectors sect on sm.sector_id = sect.sector_id

    inner join Indices I on I.index_id = f.default_index_id

    left join security_code_bbisin_intmdt bbisn on bbisn.bm_code = fh.security_code

    where TRUNC(fh.effective_date) = TRUNC(RUN_DATE) order by fh.fund_id, fh.security_code)FND

    left join (select * from index_constituents where TRUNC(effective_date) = TRUNC(RUN_DATE)) IDX

    on IDX.index_ID = FND.Index_Id and IDX.security_code = FND.security_code;

END SP_FE_HOLDINGSD_REL_NORET;

