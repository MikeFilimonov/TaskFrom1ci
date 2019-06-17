
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPaneIIntegration.Form.MobileApplicationSettings",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPaneIIntegration.Form.MobileApplicationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
