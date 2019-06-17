&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.SupplyPlanning.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, New Structure("SalesOrder", CommandParameter), True),
		,
		"SalesOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
