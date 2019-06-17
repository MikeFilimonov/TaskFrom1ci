&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "StockStatement");
	Variant.Insert("VariantKey", "Balance");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
