Dim xl
Set xl = CreateObject("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False

Set wb = xl.WorkBooks.Open("D:\Valuefy\DataLoadProcess\NEWETLMacros\ETLMACRO.xlsm")
xl.Run "Main"
wb.Close False
xl.Quit

Set wb = Nothing
Set xl = Nothing