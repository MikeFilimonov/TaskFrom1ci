&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CostOfSalesBudget");
	Variant.Insert("VariantKey", "Planfact analysis");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
