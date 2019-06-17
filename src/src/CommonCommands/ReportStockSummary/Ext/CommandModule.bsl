&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "StockSummary");
	Variant.Insert("VariantKey", "Statement");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
