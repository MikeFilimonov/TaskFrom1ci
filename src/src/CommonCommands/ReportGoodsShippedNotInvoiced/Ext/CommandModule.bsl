&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",	"GoodsShippedNotInvoiced");
	Variant.Insert("VariantKey",	"Default");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
