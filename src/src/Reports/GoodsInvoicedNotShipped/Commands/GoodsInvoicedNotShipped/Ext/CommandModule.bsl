#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Ref = CommandParameter[0];
	
	ParametersStructure	= New Structure("VariantKey, PurposeUseKey, GenerateOnOpen", "Default", Ref, True);
	FilterStructure		= New Structure("SalesInvoice", Ref);
	
	ParametersStructure.Insert("Filter", FilterStructure);
	
	OpenForm("Report.GoodsInvoicedNotShipped.Form",
		ParametersStructure,
		,
		"SalesInvoice=" + Ref,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion