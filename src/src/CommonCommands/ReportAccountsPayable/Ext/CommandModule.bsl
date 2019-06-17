&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "AccountsPayable");
	Variant.Insert("VariantKey", "Statement");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
