&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.SalesOrdersAnalysis.Form",
		New Structure("VariantKey, PurposeUseKey, Filter, GenerateOnOpen", "Default", CommandParameter, New Structure("SalesOrder, FilterByOrders", CommandParameter, "NoFilter"), True),
		,
		"SalesOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
