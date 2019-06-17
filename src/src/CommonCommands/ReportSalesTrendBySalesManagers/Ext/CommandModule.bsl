&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "NetSales");
	Variant.Insert("VariantKey", "SalesDynamicsByManagers");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
