#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanel.Form.SectionService",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanel.Form.SectionService" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
