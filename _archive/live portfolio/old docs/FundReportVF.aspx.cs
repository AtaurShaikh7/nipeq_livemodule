//CREATED BY MAITHILEE - LIVE SCREEN

using System;
using System.Web;
using System.Data;
using System.Data.OracleClient;
using ValueAT;
using System.Web.Script.Services;
using System.Web.Services;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.HtmlControls;
using System.Net.Mail;
using System.Net;


public partial class FundReportVF : System.Web.UI.Page
{
    static string loginID = "";
    static string fundID = "";
    static string fundIndex = "";
    static string fundName = "";
    static string indexShortName = "";
    static string fundIndexID = "";
    static string effectiveDate = "";
    static string runDate = "";
    static string repType = "";
    static string layoutID = "";
    static string layoutName = "";

    ClsUsers objUser = new ClsUsers();

    protected void Page_Load(object sender, EventArgs e)
    {
        try
        {
            if (Session["LoginID"] != null && Session["LoggedIn"] != null && Session["UserName"] != null)
            {
                if (Convert.ToString(Session["LoginID"]) != "" && Convert.ToString(Session["LoggedIn"]) != "0" && Convert.ToString(Session["UserName"]) != "")
                {
                    HdnUserID.Value = Session["LoginID"].ToString();
                    HdnUserName.Value = Session["UserName"].ToString();
                    loginID = Session["LoginID"].ToString();

                    SetFundList();
                    GetFundParameters(DefaultFundID.Value);
                    SetIndexList();
                    SetLayoutList();
                    FundEffectiveDate.Value = Convert.ToDateTime(effectiveDate).ToString("dd-MMM-yyyy");
                    FundIndex.Value = fundIndex;
                    FundIndexID.Value = fundIndexID.ToString();
                    IndexShortName.Value = indexShortName.ToString();

                    if (Session["SID"] != "")
                    {
                        string Sessionid = Session["SID"].ToString();
                        string Email = Session["UserId"].ToString();
                        string UserSession = objUser.GetSession(Email);
                        if (UserSession != Sessionid)
                        {
                            objUser.InsertUserHistory(Email, "LogOut");
                            Session.Abandon();
                            Session.RemoveAll();
                            Response.Redirect("Login.aspx");
                        }
                    }
                }
                else { Response.Redirect("Login.aspx"); }
            }
            else
            {
                Response.Redirect("Login.aspx");
            }

        }
        catch (System.Threading.ThreadAbortException)
        {
            // Do nothing. ASP.NET is redirecting and throws normal exception.
            // Exception is being swallowed.
        }
        catch (Exception exp)
        {
            //Code for exception
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }

    }

    //Populate fund list select picker 
    protected void SetFundList()
    {

        try
        {
            DataTable dt = CallProcedureLoginID("SP_FE_FUNDLIST", loginID);
            DataRow[] dr = null;
            if (dt != null)
                dr = dt.Select("DEFAULT_FLAG = 1");
            if (dr != null && dr.Length > 0)
            {
                DefaultFundID.Value = dr[0]["FUND_ID"].ToString();

                fundID = DefaultFundID.Value;
                FundID.Value = DefaultFundID.Value;

                fundName = dr[0]["FUND_NAME"].ToString();
                FundName.Value = fundName;
            }
            else
            {
                DefaultLayoutID.Value = dt.Rows[0]["FUND_ID"].ToString();

                fundID = DefaultFundID.Value;
                FundID.Value = DefaultFundID.Value;

                fundName = dt.Rows[0]["FUND_NAME"].ToString();
                FundName.Value = fundName;
            }



            if (dt != null && dt.Rows.Count > 0)
            {
                FundList.DataSource = dt;
                FundList.DataTextField = "FUND_NAME";
                FundList.DataValueField = "FUND_ID";
                FundList.DataBind();

                //CHANGE FOR LIVE - Change the field casting as per the appropriate datatype on production and UAT
                //string IDs = JsonConvert.SerializeObject((dt.AsEnumerable().Select(r => r.Field<decimal>("FUND_ID"))).Select(i => (int)i).ToList());
                string IDs = JsonConvert.SerializeObject((dt.AsEnumerable().Select(r => r.Field<string>("FUND_ID")).ToList()));
                AllFundIDs.Value = IDs;
            }
        }
        catch (Exception exp)
        {
            //Code for exception
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
    }

    //Populate fund list select picker
    protected void SetIndexList()
    {
        try
        {
            DataTable dt = CallProcedure("SP_FE_INDEXLIST");
            if (dt != null && dt.Rows.Count > 0)
            {
                IndexList.DataSource = dt;
                IndexList.DataTextField = "INDEX_NAME";
                IndexList.DataValueField = "INDEX_ID";      //Format: Index ID | Index Short Name
                IndexList.DataBind();

            }
        }
        catch (Exception exp)
        {
            //Code for exception
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
    }

    protected void SetLayoutList()
    {
        try
        {
            DataTable dt = CallProcedureLoginID("SP_FE_LAYOUTLIST", loginID);
            DataRow[] dr = null;
            DataRow[] dlRow = null;
            if (dt != null && dt.Rows.Count > 0)
            {
                dlRow = dt.Select("SYSTEM_DEFAULT_FLAG = 1");
                if (dlRow != null && dlRow.Length > 0)
                {
                    SystemDefaultLayoutID.Value = dlRow[0]["LAYOUT_ID"].ToString();
                    SystemDefaultLayoutUser.Value = dlRow[0]["LOGIN_ID"].ToString();
                }

                dr = dt.Select("DEFAULT_FLAG = 1");
                if (dr != null && dr.Length > 0)
                {
                    DefaultLayoutID.Value = dr[0]["LAYOUT_ID"].ToString();

                    layoutID = DefaultLayoutID.Value;
                    LayoutID.Value = DefaultLayoutID.Value;

                    layoutName = dr[0]["LAYOUT_NAME"].ToString();
                    LayoutName.Value = layoutName;
                }
                else
                {
                    DefaultLayoutID.Value = dt.Rows[0]["LAYOUT_ID"].ToString();

                    layoutID = DefaultLayoutID.Value;
                    LayoutID.Value = DefaultLayoutID.Value;

                    layoutName = dt.Rows[0]["LAYOUT_NAME"].ToString();
                    LayoutName.Value = layoutName;
                }

                LayoutList.DataSource = dt;
                LayoutList.DataTextField = "LAYOUT_NAME";
                LayoutList.DataValueField = "LAYOUT_ID";
                LayoutList.DataBind();
            }
        }
        catch (Exception exp)
        {
            //Code for exception
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
    }

    //Gets the date and index for the fund
    [WebMethod]
    [ScriptMethod]
    public static string GetFundParameters(string fundID)
    {
        string result = "";
        DataTable dt = new DataTable();
        try
        {
            dt = CallProcedureFundID("SP_FE_FR_DATE_INDEX", fundID);
            if (dt != null && dt.Rows.Count > 0)
            {
                effectiveDate = dt.Rows[0][0].ToString();
                fundIndex = dt.Rows[0][1].ToString();
                fundIndexID = dt.Rows[0][2].ToString();
                indexShortName = dt.Rows[0][3].ToString();
                result = Convert.ToDateTime(effectiveDate).ToString("dd-MMM-yyyy") + "|" + fundIndex + "|" + fundIndexID + "|" + indexShortName;
            }
        }
        catch (Exception e)
        {
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        return result;
    }

    #region Table Data
    //Formats the table
    [ScriptMethod]
    [WebMethod]
    public static string GetTableData(string fundID, string fundName, string fundIndexID, string runDate, string repType)
    {
        FundReportVF.fundID = fundID;
        FundReportVF.fundName = fundName;
        FundReportVF.fundIndexID = fundIndexID;
        FundReportVF.runDate = runDate;
        FundReportVF.repType = repType;

        DataTable dt1 = new DataTable();
        DataTable dt2 = new DataTable();
        string result = "";

        try
        {
            //dt1 = FetchTableData("SP_FE_LIVE_DATA_NEW", fundID, fundIndexID, runDate, repType);
            //CHANGE FOR LIVE
            dt1 = FetchTableData("SP_FE_LIVE", fundID, fundIndexID, runDate, repType);
            if (dt1 != null && dt1.Rows.Count > 0)
            {
                DataTable dtFilteredISIN = dt1.AsEnumerable().Where(r => r.Field<string>("ISIN") != "Sector").CopyToDataTable();
                string ISINList = "\'" + string.Join("\',\'", dtFilteredISIN.AsEnumerable().Select(r => r.Field<string>("ISIN")).ToArray()) + "\'";
                dt2 = GetLivePriceDataREL(ISINList);

                if (dt2 != null && dt2.Rows.Count > 0)
                {
                    string priceDate = Convert.ToDateTime(dt2.Rows[0]["PRICE_DATE"]).ToString("dd-MMM-yyyy HH:mm");

                    var data = from table1 in dt1.AsEnumerable()
                               join table2 in dt2.AsEnumerable() on table1.Field<string>("ISIN") equals table2.Field<string>("isincode")
                               into a
                               from b in a.DefaultIfEmpty()
                               select new
                               {
                                   SECTOR = (table1["SECTOR"] == DBNull.Value ? "" : table1.Field<string>("SECTOR")),
                                   SECURITY_NAME = (table1["SECURITY_NAME"] == DBNull.Value ? "" : table1.Field<string>("SECURITY_NAME")),
                                   INDEXFLAG = (table1["INDEXFLAG"] == DBNull.Value ? "" : table1.Field<string>("INDEXFLAG")),
                                   FUNDFLAG = (table1["FUNDFLAG"] == DBNull.Value ? "" : table1.Field<string>("FUNDFLAG")),
                                   FUNDQTY = (table1["FUNDQTY"] == DBNull.Value ? 0 : table1.Field<decimal>("FUNDQTY")),
                                   CMP = (table1["CMP"] == DBNull.Value ? 0 : table1.Field<decimal>("CMP")),
                                   RET_1D = (table1["RET_1D"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_1D")),
                                   RET_5D = (table1["RET_5D"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_5D")),
                                   RET_1M = (table1["RET_1M"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_1M")),
                                   RET_3M = (table1["RET_3M"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_3M")),
                                   RET_6M = (table1["RET_6M"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_6M")),
                                   RET_1Y = (table1["RET_1Y"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_1Y")),
                                   RET_YTD = (table1["RET_YTD"] == DBNull.Value ? 0 : table1.Field<decimal>("RET_YTD")),
                                   FUND_MTM = (table1["FUND_MTM"] == DBNull.Value ? 0 : table1.Field<decimal>("FUND_MTM")),
                                   FUND_MTM_CHG = (table1["FUND_MTM_CHG"] == DBNull.Value ? 0 : table1.Field<decimal>("FUND_MTM_CHG")),
                                   FUND_WTS = (table1["FUND_WTS"] == DBNull.Value ? 0 : table1.Field<decimal>("FUND_WTS")),
                                   INDEX_WTS = (table1["INDEX_WTS"] == DBNull.Value ? 0 : table1.Field<decimal>("INDEX_WTS")),
                                   FUND_AUM = (table1["FUND_AUM"] == DBNull.Value ? 0 : table1.Field<decimal>("FUND_AUM")),
                                   MCAP = (table1["MCAP"] == DBNull.Value ? 0 : table1.Field<decimal>("MCAP")),
                                   RNK = (table1["RNK"] == DBNull.Value ? 0 : table1.Field<decimal>("RNK")),
                                   ISIN = (table1["ISIN"] == DBNull.Value ? "" : table1.Field<string>("ISIN")),
                                   BOOK_VALUE = (table1["BOOK_VALUE"] == DBNull.Value ? 0 : table1.Field<decimal>("BOOK_VALUE")),
                                   BONUS_SPLIT = (table1["BONUS_SPLIT"] == DBNull.Value ? 0 : table1.Field<decimal>("BONUS_SPLIT")),
                                   PAYOUT = (table1["PAYOUT"] == DBNull.Value ? 0 : table1.Field<decimal>("PAYOUT")),
                                   SUBSECTOR = (table1["SUBSECTOR"] == DBNull.Value ? "" : table1.Field<string>("SUBSECTOR")),
                                   RNK1 = (table1["RNK1"] == DBNull.Value ? 0 : table1.Field<decimal>("RNK1")),
                                   NO_SUBSEC = (table1["NO_SUBSEC"] == DBNull.Value ? 0 : table1.Field<decimal>("NO_SUBSEC")),
                                   MCAP_BUCKET = (table1["MCAP_BUCKET"] == DBNull.Value ? "" : table1.Field<string>("MCAP_BUCKET")),
                                   AVGADVT = (table1["AVGADVT"] == DBNull.Value ? 0 : table1.Field<decimal>("AVGADVT")),
                                   AVG_VOL = (table1["AVG_VOL"] == DBNull.Value ? 0 : table1.Field<decimal>("AVG_VOL")),
                                  
                                   Rating = (table1["Rating"] == DBNull.Value ? "" : table1.Field<string>("Rating")),
                                   //Following fields are retrived from DION database

                                   //CHANGE FOR LIVE
                                   //These changes are required because the data type of the fields retrived from DION database can be different
                                   //Use the appropriate datatype casting (decimal or double) when error thrown is 'Specified cast not valid'

                                   //1 - UNCOMMENT THIS FOR LIVE
                                   PRICE = (b == null ? (table1.Field<decimal?>("CMP") == null ? 0 : Convert.ToDouble(table1.Field<decimal>("CMP"))) :
                                   (b.Field<double?>("nse_live_price") != null && b.Field<double>("nse_live_price") != 0 ? b.Field<double>("nse_live_price") :
                                   (b.Field<double?>("bse_live_price") != null && b.Field<double>("bse_live_price") != 0 ? b.Field<double>("bse_live_price") : 0))),
                                   NSEMCAP = (b == null ? 0 : (b.Field<double?>("nse_marketcap") == null ? 0 : (b.Field<double>("nse_marketcap")))),
                                   BSEMCAP = (b == null ? 0 : (b.Field<double?>("bse_marketcap") == null ? 0 : (b.Field<double>("bse_marketcap")))),

                                   //COMMENT FOR LIVE - RANDOM 52week values
                                   //FTW_LOW = (b == null ? 0 : (b.Field<decimal?>("FTW_LOW") == null ? 0 : (b.Field<decimal>("FTW_LOW")))),
                                   //FTW_HIGH = (b == null ? 0 : (b.Field<decimal?>("FTW_HIGH") == null ? 0 : (b.Field<decimal>("FTW_HIGH")))),
                                   //END COMMENT

                                   //UNCOMMENT FOR LIVE - ACTUAL 52week values
                                   FTW_LOW = (b == null ? 0 : (b.Field<decimal?>("nse_fiftytwoweek_low") != null && b.Field<decimal>("nse_fiftytwoweek_low") != 0 ? b.Field<decimal>("nse_fiftytwoweek_low") :
                                   (b.Field<decimal?>("bse_fiftytwoweek_low") != null && b.Field<decimal>("bse_fiftytwoweek_high") != 0 ? b.Field<decimal>("bse_fiftytwoweek_low") : 0))),
                                   FTW_HIGH = (b == null ? 0 : (b.Field<decimal?>("nse_fiftytwoweek_high") != null && b.Field<decimal>("nse_fiftytwoweek_high") != 0 ? b.Field<decimal>("nse_fiftytwoweek_high") :
                                   (b.Field<decimal?>("bse_fiftytwoweek_high") != null && b.Field<decimal>("bse_fiftytwoweek_high") != 0 ? b.Field<decimal>("bse_fiftytwoweek_high") : 0))),
                                   //END COMMENT

                                   NSEPERCHANGE = (b == null ? 0 : (b.Field<double?>("nse_per_change") == null ? 0 : (b.Field<double>("nse_per_change")))),
                                   BSEPERCHANGE = (b == null ? 0 : (b.Field<double?>("bse_per_change") == null ? 0 : (b.Field<double>("bse_per_change"))))
                                   //END 1

                                   //2- COMMENT THIS FOR LIVE
                                   //PRICE = (b == null ? (table1.Field<decimal?>("CMP") == null ? 0 : (double)table1.Field<decimal>("CMP")) :
                                   //(b.Field<double?>("nse_live_price") != null && b.Field<double>("nse_live_price") != 0 ? b.Field<double>("nse_live_price") :
                                   //(b.Field<double?>("bse_live_price") != null && b.Field<double>("bse_live_price") != 0 ? b.Field<double>("bse_live_price") : 0))),
                                   //NSEMCAP = (b == null ? 0 : (b.Field<double?>("nse_marketcap") == null ? 0 : (b.Field<double>("nse_marketcap")))),
                                   //BSEMCAP = (b == null ? 0 : (b.Field<double?>("bse_marketcap") == null ? 0 : (b.Field<double>("bse_marketcap")))),
                                   //FTW_LOW = (b == null ? 0 : (b.Field<double?>("FTW_LOW") == null ? 0 : (b.Field<double>("FTW_LOW")))),
                                   //FTW_HIGH = (b == null ? 0 : (b.Field<double?>("FTW_HIGH") == null ? 0 : (b.Field<double>("FTW_HIGH")))),
                                   //NSEPERCHANGE = (b == null ? 0 : (b.Field<double?>("nse_per_change") == null ? 0 : (b.Field<double>("nse_per_change")))),
                                   //BSEPERCHANGE = (b == null ? 0 : (b.Field<double?>("bse_per_change") == null ? 0 : (b.Field<double>("bse_per_change"))))
                                   //END 2
                               };


                    if (data != null)
                    {
                        result = JsonConvert.SerializeObject(data);
                        result += "|" + priceDate;
                    }

                    //added by dhwani to find missing isin price
                    DataView view = new DataView(dt1);
                    view.RowFilter = "ISIN Not like  '%Sector%' and ISIN Not like  '%Cblo%' and ISIN Not like  '%CASH%'";
                    DataTable filterdata = view.ToTable();

                    DataTable dtOutput = filterdata.Rows.OfType<DataRow>().Where(a => filterdata.Rows.OfType<DataRow>().
                        Select(k => Convert.ToString(k["ISIN"])).Except(dt2.Rows.OfType<DataRow>().Select(k => Convert.ToString(k["isincode"])).ToList())
                        .Contains(Convert.ToString(a["ISIN"]))).CopyToDataTable();
                    FundReportVF fund = new FundReportVF();
                    fund.sendmail(dtOutput);
                    //end

                }
            }
        }
        catch (Exception e)
        {
            
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        return result;
    }


    //SHAILENDRA: FUNCTION TO GET 1 DAY RETURN FOR FUND AND INDEX IN CASE OF EOD
    [ScriptMethod]
    [WebMethod]
    public static string Get_EODFundIdx_Ret(string fund_id, string index_id, string effdate)
    {
        Common objComm = new Common();

        string result = "";
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();
        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = "SP_FE_SPEC_FIDX_RET";
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("FUNDID", OracleType.Number);
                    OracleParameter p2 = new OracleParameter("INDEXID", OracleType.Number);
                    OracleParameter p3 = new OracleParameter("EFF_DATE", OracleType.DateTime);
                    OracleParameter p4 = new OracleParameter("RESULTSET", OracleType.Cursor);
                    p1.Value = fund_id;
                    p2.Value = index_id;
                    p3.Value = effdate;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Input;
                    p3.Direction = ParameterDirection.Input;
                    p4.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);
                    cmd.Parameters.Add(p3);
                    cmd.Parameters.Add(p4);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    if (da != null)
                    {
                        da.Fill(dt);
                    }

                    for (int i = 0; i < dt.Rows.Count; i++)
                    {
                        result = dt.Rows[0]["FUND_1D"].ToString() + ":" + dt.Rows[0]["INDEX_1D"].ToString();
                    }
                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e);
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally
        {
            myConn.Close();

        }
        return result;
    }



    //LIVE using DION Database
    [System.Web.Services.WebMethod(EnableSession = true)]
    public static string GetLiveIndexDataREL(string index_id)
    {
        string IndexSeries = "";
        string ResultString = "0";
        DionCommon objDionComm = new DionCommon();
        Common objComm = new Common();
        string IndexDionCode = "";
        try
        {
            DataTable DtIndexcode = new DataTable();
            DataTable DtEqPrices = new DataTable();

            string IdxQrey = "select NVL(DION_CODE,'000.00001') as DION_CODE from indices where index_id=" + index_id;
            DtIndexcode = objComm.getdatatable(IdxQrey);
            if (DtIndexcode.Rows.Count > 0)
            {
                IndexDionCode = DtIndexcode.Rows[0]["DION_CODE"].ToString();
            }
            else
            {
                IndexDionCode = "0000.0001";
            }

            //string PriceQuery = "select * from dbo.ValueAT_INDICESPRICERETURN where effectivedate>='" + DateValue.ToString("dd-MMM-yy") + "' and IndexCode in ('" + IndexDionCode + "')";
            string PriceQuery = "select * from dbo.ValueAT_INDICESPRICERETURN where IndexCode in ('" + IndexDionCode + "')";

            DtEqPrices = objDionComm.getdatatable(PriceQuery);

            if (DtEqPrices.Rows.Count > 0)
            {
                ResultString = "1";
                for (int i = 0; i < DtEqPrices.Rows.Count; i++)
                {
                    if (i == (DtEqPrices.Rows.Count - 1))
                    {
                        IndexSeries += DtEqPrices.Rows[i]["Indexname"].ToString() + ":" + DtEqPrices.Rows[i]["CURR_CLOSE"].ToString() + ":" + DtEqPrices.Rows[i]["RETURN_1D"].ToString();
                    }
                    else
                    {
                        IndexSeries += DtEqPrices.Rows[i]["Indexname"].ToString() + ":" + DtEqPrices.Rows[i]["CURR_CLOSE"].ToString() + ":" + DtEqPrices.Rows[i]["RETURN_1D"].ToString() + "|";
                    }
                }
            }
            else
            {
                ResultString = "0";
            }
        }
        catch(Exception exp)
        {
            ResultString = "0";
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally
        {
            ResultString += ";" + IndexSeries;
            // Close connection  
        }
        HttpContext.Current.Session["LiveIdxPrices"] = ResultString;
        return ResultString;
    }




    [System.Web.Services.WebMethod(EnableSession = true)]
    public static DataTable GetLivePriceDataREL(string BBISINList)
    {
        DionCommon objDionComm = new DionCommon();
        //CHANGE FOR LIVE - Use the appropriate date string when deploying
        string DatStr = DateTime.Now.ToString("dd-MMM-yyyy");         //Use this for live data
        // string DatStr = "03-Aug-2018";                                  //Use hard coded appropriate date when live data is not available
        DataTable DtEqPrices = new DataTable();
        DataTable DtMaxDate = new DataTable();
        try
        {

            string DateQuery = "select max(PriceDate) as PRICE_DATE from ValueAT_EQUITYLIVEPRICES where ISINCODE in (" + BBISINList + ")";

            //CHANGE FOR LIVE - Use objDionComm.getdatatable when getting data from live dion server on production
            //DtMaxDate = GetQueryDataTable(DateQuery);
            DtMaxDate = objDionComm.getdatatable(DateQuery);
            if (DtMaxDate != null && DtMaxDate.Rows.Count > 0)
            {
                DatStr = DtMaxDate.Rows[0]["PRICE_DATE"].ToString();
                DatStr = Convert.ToDateTime(DatStr).ToString("dd - MMM - yyyy");
            }

            //CHANGE FOR LIVE - Select the appropriate query when deploying

            //Query for Local - random 52w
            //string PriceQuery = "select eq.*, RAND( CHECKSUM( NEWID()))*10000 AS FTW_LOW, RAND( CHECKSUM( NEWID()))*20000 AS FTW_HIGH from ValueAT_EQUITYLIVEPRICES eq where pricedate>='" + DatStr + "' AND ISINCODE in (" + BBISINList + ") ";
            //PriceQuery += " union all ";
            //PriceQuery += " select fno.*, RAND( CHECKSUM( NEWID()))*10000 AS FTW_LOW, RAND( CHECKSUM( NEWID()))*20000 AS FTW_HIGH from ValueAT_FNOLIVEEODPRICES fno where pricedate>='" + DatStr + "' AND ISINCODE in (" + BBISINList + ")";

            //Query using DB Link on LIVE - actual 52w
            //string PriceQuery = "select * from ValueAT_EQUITYLIVEPRICES@\"DION_UAT\" where \"pricedate\">='" + DatStr + "' AND \"ISINCODE\" in (" + BBISINList + ") ";
            //PriceQuery += " union all ";
            //PriceQuery += " select * from ValueAT_FNOLIVEEODPRICES@\"DION_UAT\" where \"pricedate\">='" + DatStr + "' AND \"ISINCODE\" in (" + BBISINList + ")";

            //Query without DB Link on LIVE - random 52w
            //string PriceQuery = "select eq.*,  ROUND(DBMS_RANDOM.VALUE(3000,7000),2) AS FTW_LOW,  ROUND(DBMS_RANDOM.VALUE(7001,15000),2) AS FTW_HIGH from ValueAT_EQUITYLIVEPRICES eq where pricedate>='" + DatStr + "' AND ISINCODE in (" + BBISINList + ") ";
            //PriceQuery += " union all ";
            //PriceQuery += " select fno.*,  ROUND(DBMS_RANDOM.VALUE(3000,7000),2) AS FTW_LOW,  ROUND(DBMS_RANDOM.VALUE(7001,15000),2) AS FTW_HIGH FROM ValueAT_FNOLIVEEODPRICES fno where pricedate>='" + DatStr + "' AND ISINCODE in (" + BBISINList + ")";

            //Query without DB Link on LIVE - actual 52w
            string PriceQuery = "select * from ValueAT_EQUITYLIVEPRICES eq where pricedate>='" + DatStr + "' AND ISINCODE in (" + BBISINList + ") ";
            PriceQuery += " union all ";
            PriceQuery += " select * from ValueAT_FNOLIVEEODPRICES fno where pricedate>='" + DatStr + "' AND ISINCODE in (" + BBISINList + ")";

            WriteErrorLog c = new WriteErrorLog(new Exception("Price Query : " + PriceQuery));
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));

            //CHANGE FOR LIVE - Use objDionComm.getdatatable when getting data from live dion server on production
            DtEqPrices = objDionComm.getdatatable(PriceQuery);
            //DtEqPrices = GetQueryDataTable(PriceQuery);

            if (DtEqPrices != null && DtEqPrices.Rows.Count > 0)
            {
                DtEqPrices.Columns.Add(new DataColumn("PRICE_DATE"));
                if (DtMaxDate != null && DtMaxDate.Rows.Count > 0)
                {
                    DtEqPrices.Rows[0]["PRICE_DATE"] = DtMaxDate.Rows[0]["PRICE_DATE"];
                }
            }

        }
        catch (Exception exp)
        {
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        HttpContext.Current.Session["LiveSecPrices"] = DtEqPrices;
        return DtEqPrices;
    }

    #endregion Table Data

    #region Layout Management

    //Updates an existing layout present for the user ID
    [ScriptMethod]
    [WebMethod]
    public static string UpdateLayout(string layoutID, string layoutName, string defaultFlag, string tableState, string columns, string filters)
    {
        string result = "";
        try
        {
            int dFlag = 0;
            if (defaultFlag.ToLower() == "true")    //If layout has been made default, change other rows having default
            {
                dFlag = 1;
                string updateFlagQuery = "UPDATE LIVESCREEN_LAYOUT_STATE SET DEFAULT_FLAG = 0 WHERE LOGIN_ID=\'" + loginID + "\' AND DEFAULT_FLAG = 1";
                string rows = InsertUpdateIntoTable(updateFlagQuery).ToString();
            }

            string updateQuery = "UPDATE LIVESCREEN_LAYOUT_STATE "
                + "SET LAYOUT_STATE = \'" + tableState + "\', FILTERS= \'" + filters + "\' , COLUMNS= \'" + columns + "\' "
                + ", LAYOUT_NAME = \'" + layoutName + "\', DEFAULT_FLAG =" + dFlag
                + " WHERE LAYOUT_ID = " + layoutID + " AND LOGIN_ID=\'" + loginID + "\'";
            result = InsertUpdateIntoTable(updateQuery).ToString();

        }
        catch (Exception exp)
        {
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }

        return result;
    }

    //Creates a new layout for the user
    [ScriptMethod]
    [WebMethod]
    public static string SaveLayout(string layoutName, string defaultFlag, string tableState, string columns, string filters)
    {
        string result = "";
        try
        {
            int dFlag = 0;
            if (defaultFlag.ToLower() == "true")    //If layout has been made default, change other rows having default
            {
                dFlag = 1;
                string updateFlagQuery = "UPDATE LIVESCREEN_LAYOUT_STATE SET DEFAULT_FLAG = 0 WHERE LOGIN_ID=\'" + loginID + "\' AND DEFAULT_FLAG = 1";
                string rows = InsertUpdateIntoTable(updateFlagQuery).ToString();
            }

            string insertQuery = "INSERT INTO LIVESCREEN_LAYOUT_STATE (LAYOUT_ID, LOGIN_ID, LAYOUT_NAME, LAYOUT_STATE, COLUMNS, FILTERS, DEFAULT_FLAG) " +
                "VALUES (LAYOUT_ID_SEQUENCE.NEXTVAL, \'" + loginID + "\', \'" + layoutName + "\' , \'" + tableState + "\' , \'" + columns + "\' , \'" + filters + "\' ," + dFlag + ")";
            result = InsertUpdateIntoTable(insertQuery).ToString();
        }
        catch (Exception exp)
        {
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        return result;
    }

    //Retrives the layout for the user
    [ScriptMethod]
    [WebMethod]
    public static string LoadLayout(string layoutID)
    {
        string result = "";
        try
        {
            string selectQuery = "SELECT LAYOUT_STATE, COLUMNS, FILTERS FROM LIVESCREEN_LAYOUT_STATE WHERE LAYOUT_ID = " + layoutID;
            DataTable dtLayout = GetQueryDataTable(selectQuery);
            if (dtLayout != null && dtLayout.Rows.Count > 0)
            {
                result = dtLayout.Rows[0]["LAYOUT_STATE"].ToString();
                result += '|';
                result += dtLayout.Rows[0]["COLUMNS"].ToString();
                result += '|';
                result += dtLayout.Rows[0]["FILTERS"].ToString();
            }

        }
        catch (Exception exp)
        {
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }

        return result;
    }

    #endregion Layout Management

    [ScriptMethod]
    [WebMethod]
    public static string GetHistoricalPerformance(string fundID, string runDate, string repType)
    {
        DataTable dt = new DataTable();
        string result = "";
        try
        {
            //CHANGE FOR LIVE - Use SP_FE_HISTPERF_PEERS_REL on live
            dt = FetchTableData("SP_FE_HISTPERF_PEERS_REL", fundID, runDate, repType);
            //dt = FetchTableData("SP_FE_TEMP_HIST", fundID, runDate, repType);
            if (dt != null && dt.Rows.Count > 0)
            {
                result = JsonConvert.SerializeObject(dt);
            }
        }
        catch (Exception e)
        {
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        return result;
    }

    [ScriptMethod]
    [WebMethod]
    public static string GetTurnOverRatio(string fundID, string toDate)
    {
        DataTable dt = new DataTable();
        string result = "";
        try
        {
            dt = FetchTableData("SP_FE_LIVE_TURNOVER_RAT", fundID, toDate);
            if (dt != null && dt.Rows.Count > 0)
            {
                result = dt.Rows[0]["TURNOVER"].ToString();
            }
        }
        catch (Exception e)
        {
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        return result;
    }

    //JSON Serializer for parsing and formatting JSON data
    public string GetSerializedfromDataTable(DataTable dt)
    {
        try
        {
            string data = "";

            if (dt.Rows.Count > 0)
            {
                System.Web.Script.Serialization.JavaScriptSerializer serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
                List<Dictionary<string, object>> rows = new List<Dictionary<string, object>>();
                Dictionary<string, object> row;

                foreach (DataRow dr in dt.Rows)
                {
                    row = new Dictionary<string, object>();
                    foreach (DataColumn col in dt.Columns)
                    {
                        row.Add(col.ColumnName, dr[col]);
                    }
                    rows.Add(row);
                }


                data = serializer.Serialize(rows);
                data = "{ \"data\":" + data.ToString() + "}";

                //retMsg = dt_result.Rows[0]["REPORT_ID"].ToString();
            }

            return data;
        }
        catch (Exception exp)
        {
            //Code for exception
            WriteErrorLog c = new WriteErrorLog(exp.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
            return "";
        }
    }


    #region Code for Common.js
    /*----------------------------------------------------------------------------------------TO BE ADDED TO Common.js---------------------------------------------------------------------------------*/

    //Gets data from database to fill in table
    public static DataTable FetchTableData(string procName, string fundID, string fundIndexID, string runDate, string repType)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();
        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("FUNDID", OracleType.VarChar);
                    OracleParameter p2 = new OracleParameter("INDEXID", OracleType.VarChar);
                    OracleParameter p3 = new OracleParameter("RUN_DATE", OracleType.DateTime);
                    OracleParameter p4 = new OracleParameter("REP_TYPE", OracleType.VarChar);
                    OracleParameter p5 = new OracleParameter("ResultSet", OracleType.Cursor);
                    OracleParameter p6 = new OracleParameter("LOGINID", OracleType.VarChar);
                    p1.Value = fundID;
                    p2.Value = fundIndexID;
                    p3.Value = runDate;
                    p4.Value = repType;
                    p6.Value = loginID;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Input;
                    p3.Direction = ParameterDirection.Input;
                    p4.Direction = ParameterDirection.Input;
                    p5.Direction = ParameterDirection.Output;
                    p6.Direction = ParameterDirection.Input;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);
                    cmd.Parameters.Add(p3);
                    cmd.Parameters.Add(p4);
                    cmd.Parameters.Add(p5);
                    cmd.Parameters.Add(p6);
                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    if (da != null)
                    {
                        da.Fill(dt);
                    }

                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    //Gets data from database to fill in table
    public static DataTable FetchTableData(string procName, string fundID, string runDate, string repType)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();
        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("FUNDID", OracleType.VarChar);
                    OracleParameter p2 = new OracleParameter("RUN_DATE", OracleType.DateTime);
                    OracleParameter p3 = new OracleParameter("REP_TYPE", OracleType.VarChar);
                    OracleParameter p4 = new OracleParameter("ResultSet", OracleType.Cursor);
                    p1.Value = fundID;
                    p2.Value = runDate;
                    p3.Value = repType;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Input;
                    p3.Direction = ParameterDirection.Input;
                    p4.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);
                    cmd.Parameters.Add(p3);
                    cmd.Parameters.Add(p4);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    if (da != null)
                    {
                        da.Fill(dt);
                    }

                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    //Gets data from database to fill in table
    public static DataTable FetchTableData(string procName, string runDate)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();
        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("RUN_DATE", OracleType.DateTime);
                    OracleParameter p2 = new OracleParameter("ResultSet", OracleType.Cursor);
                    p1.Value = runDate;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    if (da != null)
                    {
                        da.Fill(dt);
                    }

                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    //Gets data from database to fill in table
    public static DataTable FetchTableData(string procName, string fundID, string toDate)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();
        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("FUNDID", OracleType.VarChar);
                    OracleParameter p2 = new OracleParameter("TO_DATE", OracleType.DateTime);
                    OracleParameter p3 = new OracleParameter("ResultSet", OracleType.Cursor);
                    p1.Value = fundID;
                    p2.Value = toDate;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Input;
                    p3.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);
                    cmd.Parameters.Add(p3);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    if (da != null)
                    {
                        da.Fill(dt);
                    }

                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }


    //Temp procedure for DION queries when LIVE cannot connect to DION
    public static DataTable GetQueryDataTable(string query)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();
        try
        {
            if (objTrans == null)
            {
                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = query;

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    if (da != null)
                        da.Fill(dt);

                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    public static int InsertUpdateIntoTable(string query)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        int rows = -1;
        try
        {
            if (objTrans == null)
            {
                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = query;

                    rows = cmd.ExecuteNonQuery();

                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return rows;
    }


    public static DataTable CallProcedure(string procName)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();

        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("ResultSet", OracleType.Cursor);
                    p1.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    da.Fill(dt);
                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    public static DataTable CallProcedureLoginID(string procName, string loginID)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();

        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("LoginID", OracleType.VarChar);
                    OracleParameter p2 = new OracleParameter("ResultSet", OracleType.Cursor);
                    p1.Value = loginID;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    da.Fill(dt);
                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    public static DataTable CallProcedureFundID(string procName, string fundID)
    {
        DBConnectivity DB = new DBConnectivity();
        OracleTransaction objTrans = null;
        OracleTransaction objTransaction = DB.GetOraConn("Admin").BeginTransaction();
        OracleConnection myConn = DB.GetOraConn("Admin");
        DataTable dt = new DataTable();

        try
        {
            if (objTrans == null)
            {

                objTrans = objTransaction;
                if (myConn != null)
                {
                    OracleCommand cmd = new OracleCommand();
                    cmd.Connection = myConn;
                    cmd.Transaction = objTrans;
                    cmd.Connection = objTrans.Connection;

                    cmd.CommandText = procName;
                    cmd.CommandType = CommandType.StoredProcedure;
                    OracleParameter p1 = new OracleParameter("FUNDID", OracleType.VarChar);
                    OracleParameter p2 = new OracleParameter("ResultSet", OracleType.Cursor);
                    p1.Value = fundID;
                    p1.Direction = ParameterDirection.Input;
                    p2.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(p1);
                    cmd.Parameters.Add(p2);

                    OracleDataAdapter da = new OracleDataAdapter(cmd);
                    da.Fill(dt);
                    myConn.Close();
                    objTrans.Commit();
                }
            }
        }
        catch (Exception e)
        {
            myConn.Close();
            objTrans.Rollback();
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        finally { myConn.Close(); }

        return dt;
    }

    #endregion Code for Common.js
	
	
	
	  //script method added by dhwani to set html data in session and keep bulk flag in session which will be used while printing pdf 
    [ScriptMethod]
    [WebMethod]
    public static string SetSession(string Data,string flag)
    {
       // DataTable dt = new DataTable();
        string result = "";
        try
        {
            HttpContext.Current.Session["HTMLDATA"] = null;
            HttpContext.Current.Session["HTMLDATA"] = Data;
            HttpContext.Current.Session["BulkFlag"] = flag;//to use on pdf page for printing for specific fund

            result = "1";
        }
        catch (Exception e)
        {
            WriteErrorLog c = new WriteErrorLog(e.GetBaseException());
            c.ErrorLog(HttpContext.Current.ApplicationInstance.Server.MapPath("~/Logs/"));
        }
        return result;
    }

    //end

    public void sendmail(DataTable dt)
    {
        if (dt != null)
        {
            var ms = new System.IO.MemoryStream();

            //Response.AddHeader("content-disposition", "attachment;filename=" + HttpUtility.UrlEncode("OffshorePortfolioReport_" + fd + "_" + td + ".xlsx", System.Text.Encoding.UTF8));
           

            DateTime datetime = System.DateTime.Now;




            using (MailMessage mail = new MailMessage())
            {
                mail.From = new MailAddress("rcam.valueat@reliancemutual.com");

                mail.Subject = "Reliance Live Portfolio Missing ISIN Prices";
                //mail.Body = "Hello";
                //mail.To.Add(dt.Rows[0]["Email_id"].ToString());
                string bodystr = "<html><body><table border='1px solid black'><tr><th>Security Name</th><th>ISIN</th></tr>";
                for (int i = 0; i < dt.Rows.Count; i++)
                {
                    bodystr += "<tr><td>" + dt.Rows[i]["SECURITY_NAME"] + "</td><td>" + dt.Rows[i]["ISIN"] + "</td></tr>";
                    

                }
                bodystr += "</table></body></html>";
                mail.IsBodyHtml = true;
                mail.Body = bodystr;
                
                

                //added for testing
                //mail.To.Add("dikshantk@valuefy.com");
                mail.To.Add("shailendrag@valuefy.com");
                mail.To.Add("shiprak@valuefy.com");
                mail.To.Add("sachins@valuefy.com");
                //mail.To.Add("dhwani.joshi@valuefy.com");
                //end


              

                //SmtpClient smtp = new SmtpClient("smtp.gmail.com", 587);
                SmtpClient smtp = new SmtpClient("10.199.15.24", 25);

                //smtp.EnableSsl = true;
                NetworkCredential networkCredential = new NetworkCredential("rcam.valueat@reliancemutual.com", "pass@123");

                smtp.Credentials = networkCredential;

                smtp.Send(mail);

            }

            // Console.ReadLine();
        }
    }
}