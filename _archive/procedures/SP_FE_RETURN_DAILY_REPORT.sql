PROCEDURE SP_FE_RETURN_DAILY_REPORT(ResultSet out SYS_REFCURSOR)  AS 

rundate date;

Date_3M date;

Date_1Y date;

BEGIN



select currdatadate into rundate from daily_process_stats where process_name='DAILY ATTRIB';

--rundate:='19-Jan-2019';

select min(effective_date) into Date_3m from business_calendar where effective_date > add_months(rundate,-3) and businessday_flag=1;



select max(effective_date) into Date_3m from business_calendar where effective_date < Date_3m and businessday_flag=1;

select min(effective_date) into Date_1y from business_calendar where effective_date > add_months(rundate,-12) and businessday_flag=1;

Select Max(Effective_Date) Into Date_1y From Business_Calendar Where Effective_Date < Date_1y And Businessday_Flag=1;







open resultset for 



select Month3_net_ret.fund_id,

Month3_net_ret.fund_name,

Month3_Net_Ret.Month_3ret ,

Month_3ret.Gross_3m ,

Month_3Ret.Gross_3M-Month3_net_ret.Month_3Ret as diff_3M,

Year_net_ret.Year_1Ret,

Year_grossRet.Gross_1Y,

Year_grossRet.Gross_1Y-Year_net_ret.Year_1Ret as diff_1Y,

rundate as RUN_date

From 

(



    select Retun_3m.fund_id,Retun_3m.Month_3Ret,f.fund_name from

    (

        SELECT rr.fund_id,nvl( round(PRODUCT(1 + NVL(Fd.P_Nav_Ret,0)) - 1,8),0) AS Month_3Ret,rr.index_id

        From Fund_Attributed_Data Fd  

        Inner Join  Report_References Rr

        On 

        (Fd.Report_Id=rr.report_id)

        where 

        Trunc(Rr.To_Date) >= Trunc(Date_3m) And Trunc(Rr.To_Date) <= Trunc(Rundate)

        GROUP BY rr.fund_id,rr.index_id

    ) Retun_3m 

    Inner Join Funds F 

    On 

    (f.fund_id=Retun_3m.fund_id and Retun_3m.index_id=F.Default_Index_Id and  f.normal_flag=0)

    Inner Join Fund_User_Mapping Fm 

    on (fm.fund_id=f.fund_id and fm.login_id ='70093594')     

) Month3_net_ret 

left join 

( 

    select Retun_1Y.fund_id,Retun_1Y.Year_1Ret from

    (

      SELECT f.fund_name,rr.fund_id,nvl( round(PRODUCT(1 + NVL(Fd.P_Nav_Ret,0)) - 1,8),0) AS Year_1Ret,f.default_index_id

      From Fund_Attributed_Data Fd  

      Inner Join Report_References Rr

      On  Fd.Report_Id=Rr.Report_Id

      Inner Join  Funds F

      On (F.Fund_Id=Rr.Fund_Id  And  Rr.Index_Id=F.Default_Index_Id)

      where   

      Trunc(Rr.To_Date) >= Trunc(Date_1y) And Trunc(Rr.To_Date) <= Trunc(Rundate)

      GROUP BY rr.fund_id,f.fund_name,f.default_index_id

    ) Retun_1y 

)Year_net_ret

on (Year_net_ret.fund_id=Month3_net_ret.fund_id)

left join 

(

    SELECT f.fund_name,rr.fund_id,nvl( round(PRODUCT(1 + NVL(fd.portfolio_return,0)) - 1,8),0) AS Gross_3M,f.default_index_id

    From Fund_Attributed_Data Fd  

    Inner Join Report_References Rr

    On Fd.Report_Id=Rr.Report_Id 

    Inner Join Funds F

    On (F.Fund_Id=Rr.Fund_Id  and  Rr.Index_Id=F.Default_Index_Id)

    where    

    TRUNC(rr.to_date) >= trunc(Date_3m) AND TRUNC(rr.to_date) <= trunc(rundate)

    GROUP BY rr.fund_id,f.fund_name,f.default_index_id

) Month_3ret 

on (Month3_net_ret.fund_id=Month_3Ret.fund_id)

left join 

(

    Select F.Fund_Name,Rr.Fund_Id,Nvl( Round(Product(1 + Nvl(Fd.Portfolio_Return,0)) - 1,8),0) As Gross_1y,F.Default_Index_Id

    From Fund_Attributed_Data Fd  

    Inner Join  Report_References Rr 

    On  Fd.Report_Id=Rr.Report_Id

    Inner Join Funds F

    On (F.Fund_Id=Rr.Fund_Id  And Rr.Index_Id=F.Default_Index_Id)

    where   

    Trunc(Rr.To_Date) >= Trunc(Date_1y) And Trunc(Rr.To_Date) <= Trunc(Rundate)

    Group By Rr.Fund_Id,F.Fund_Name,F.Default_Index_Id

) Year_grossRet 

on (Year_grossRet.fund_id=Month3_net_ret.fund_id);









END SP_FE_RETURN_DAILY_REPORT;