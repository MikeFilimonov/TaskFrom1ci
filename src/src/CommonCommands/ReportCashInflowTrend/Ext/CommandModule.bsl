&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashBalance");
	Variant.Insert("VariantKey", "CashReceiptsDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
