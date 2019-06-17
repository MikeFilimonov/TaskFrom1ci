&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashBalance");
	Variant.Insert("VariantKey", "CashExpenseDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
