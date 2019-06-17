#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanel.Form.PayrollSection",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanel.Form.PayrollSection" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
