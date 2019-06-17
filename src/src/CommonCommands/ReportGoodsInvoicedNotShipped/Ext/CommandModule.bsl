#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",	"GoodsInvoicedNotShipped");
	Variant.Insert("VariantKey",	"Default");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure

#EndRegion