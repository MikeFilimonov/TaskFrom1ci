#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanel.Form.SectionSales",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanel.Form.SectionSales" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
