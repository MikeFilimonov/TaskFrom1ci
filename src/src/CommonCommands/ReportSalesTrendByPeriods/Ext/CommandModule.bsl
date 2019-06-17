&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "NetSales");
	Variant.Insert("VariantKey", "SalesDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
