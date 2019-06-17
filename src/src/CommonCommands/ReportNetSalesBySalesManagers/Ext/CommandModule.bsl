&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "NetSales");
	Variant.Insert("VariantKey", "GrossProfitByManagers");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
