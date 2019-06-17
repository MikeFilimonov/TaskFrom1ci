#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "SalesPipeline");
	Variant.Insert("VariantKey", "Comparison");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure

#EndRegion
