&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "BudgetedBalanceSheet");
	Variant.Insert("VariantKey", "Planfact analysis");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
