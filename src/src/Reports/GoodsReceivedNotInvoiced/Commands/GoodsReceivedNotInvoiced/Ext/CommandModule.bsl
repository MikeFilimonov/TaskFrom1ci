&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Ref = CommandParameter[0];
	
	ParametersStructure	= New Structure("VariantKey, PurposeUseKey, GenerateOnOpen", "Default", Ref, True);
	FilterStructure		= New Structure("GoodsReceipt", Ref);
	
	ParametersStructure.Insert("Filter", FilterStructure);
	
	OpenForm("Report.GoodsReceivedNotInvoiced.Form",
		ParametersStructure,
		,
		"GoodsReceipt=" + Ref,
		CommandExecuteParameters.Window);
	
EndProcedure
