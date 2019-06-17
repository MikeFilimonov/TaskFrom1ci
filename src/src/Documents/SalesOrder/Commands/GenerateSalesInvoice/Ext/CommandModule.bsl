#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Document.SalesInvoice.ObjectForm",
		New Structure("Basis", CommandParameter),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion