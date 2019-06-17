#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanel.Form.FundsSection",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanel.Form.FundsSection" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
