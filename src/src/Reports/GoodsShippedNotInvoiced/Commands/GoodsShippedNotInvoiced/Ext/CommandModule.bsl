&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Ref = CommandParameter[0];
	
	ParametersStructure	= New Structure("VariantKey, PurposeUseKey, GenerateOnOpen", "Default", Ref, True);
	FilterStructure		= New Structure("GoodsIssue", Ref);
	
	ParametersStructure.Insert("Filter", FilterStructure);
	
	OpenForm("Report.GoodsShippedNotInvoiced.Form",
		ParametersStructure,
		,
		"GoodsIssue=" + Ref,
		CommandExecuteParameters.Window);
	
EndProcedure
