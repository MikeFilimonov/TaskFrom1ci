#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanel.Form.PurchaseSection",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanel.Form.PurchaseSection" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
