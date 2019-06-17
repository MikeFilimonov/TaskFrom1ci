&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashBalance");
	Variant.Insert("VariantKey", "Analysis of movements in currency");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
