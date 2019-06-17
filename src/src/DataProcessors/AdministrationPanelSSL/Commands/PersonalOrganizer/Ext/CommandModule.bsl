
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelSSL.Form.PersonalOrganizer",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelSSL.Form.PersonalOrganizer" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
