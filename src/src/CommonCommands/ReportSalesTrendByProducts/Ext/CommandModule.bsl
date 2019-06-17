&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "NetSales");
	Variant.Insert("VariantKey", "SalesDynamicsByProducts");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
