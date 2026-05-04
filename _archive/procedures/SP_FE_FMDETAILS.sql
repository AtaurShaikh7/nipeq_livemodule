PROCEDURE SP_FE_FMDETAILS (PARAMID IN NUMBER,RESULTSET OUT SYS_REFCURSOR)

as

BEGIN



-- for all fund managers

IF PARAMID = 1 THEN 

OPEN RESULTSET FOR



    select f.fund_id,f.fund_name,default_index_id,fm_id,fund_manager_name,nav,

    rank() over (PARTITION BY fund_manager_name ORDER BY nav desc) as rnk,u.email_id

    from funds f

    inner join (select * from fund_nav where value_date = (select max(value_date) from fund_nav)) fn

    on f.fund_id = fn.fund_id

    inner join users u 

    on f.fm_id = u.login_id

    where UPPER(f.fund_category) not in UPPER('Passive') and f.active_inactive_flag = 1

    order by fm_id,nav desc;



--For CIO reports, specific 10 funds.    

ELSIF PARAMID = 2 THEN 

OPEN RESULTSET FOR



    select f.fund_id,f.fund_name,f.fund_manager_name,nav from

    (

      select * from funds where fund_id in ( 1, 2, 3, 4, 5, 18, 10, 20, 28, 34,17)) f 

      inner join (select * from fund_nav where value_date = (select max(value_date) from fund_nav)

    ) fn

    on f.fund_id = fn.fund_id

    order by nav desc;       

    

--Top 10 diversified funds.   

ELSIF PARAMID = 3 THEN

OPEN RESULTSET FOR



      select f.fund_id,f.fund_name,fn.nav as AUM from 

      (select * from funds ) f

      inner join fund_nav fn

      on f.fund_id = fn.fund_id

      where fn.value_date = (select max(value_date) from fund_nav) and f.fund_id in(43,28,10,18,5,20,4,2,3,1)

      order by AUM desc;

    

END IF;

END SP_FE_FMDETAILS;