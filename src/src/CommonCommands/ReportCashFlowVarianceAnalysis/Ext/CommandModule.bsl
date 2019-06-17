&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashFlowVarianceAnalysis");
	Variant.Insert("VariantKey", "Planfact analysis (cur.)");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
