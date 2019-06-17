#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "SalesFunnel");
	Variant.Insert("VariantKey", "SalesFunnel");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure

#EndRegion

#Region Private

#EndRegion
