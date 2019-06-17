&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "AccountsReceivableTrend");
	Variant.Insert("VariantKey", "DebtDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
