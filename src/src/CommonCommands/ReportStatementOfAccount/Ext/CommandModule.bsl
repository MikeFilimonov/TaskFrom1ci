&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "StatementOfAccount");
	Variant.Insert("VariantKey", "Statement in currency (briefly)");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
