&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "NetSales");
	Variant.Insert("VariantKey", "SalesDynamicsByProductsCategories");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
