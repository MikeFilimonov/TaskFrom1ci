&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashFlowVarianceAnalysis");
	Variant.Insert("VariantKey", "InCurrency");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
