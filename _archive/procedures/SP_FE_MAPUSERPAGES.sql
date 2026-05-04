procedure SP_FE_MAPUSERPAGES (user_id IN VARCHAR2,resultset out SYS_REFCURSOR)

AS

BEGIN

open resultset for



  select pum.login_id,pm.page_id,page_title,page_name,case when upper(page_type)='ADMIN' THEN 1 ELSE 0 END AS PTYPE,

  case when external_link is null then 0 else 1 end as OpenType, external_link, fa_icon from 

  page_master pm 

  inner join 

  page_user_mapping pum 

  on pm.page_id = pum.page_id

  where upper(login_id) = upper(user_id) order by pm.page_id;

  

End SP_FE_MAPUSERPAGES;

 

 

 

 

 

 

 

 

 

 

 

 

 

 

 

 