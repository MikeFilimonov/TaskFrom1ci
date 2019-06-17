&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.PurchaseOrdersStatement.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, New Structure("PurchaseOrder", CommandParameter), True),
		,
		"PurchaseOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
