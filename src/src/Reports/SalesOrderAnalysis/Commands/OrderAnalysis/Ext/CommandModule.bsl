&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.SalesOrderAnalysis.Form",
		New Structure("VariantKey, PurposeUseKey, Order, GenerateOnOpen", "Default", CommandParameter, CommandParameter[0], True),
		,
		"SalesOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
