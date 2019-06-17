&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "AccountsPayableTrend");
	Variant.Insert("VariantKey", "DebtDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
