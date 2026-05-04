PROCEDURE SP_FE_LIQUIDATE_MAXDATE(ResultSet out SYS_REFCURSOR) AS

BEGIN

 open ResultSet for 

  Select max(EFFECTIVE_DATE) as MAXDATE from average_volume where AVGVOLUME_3M is not null;

END SP_FE_LIQUIDATE_MAXDATE;