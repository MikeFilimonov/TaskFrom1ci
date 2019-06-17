&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "StockStatementWithCostLayers");
	Variant.Insert("VariantKey", "Balance");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
