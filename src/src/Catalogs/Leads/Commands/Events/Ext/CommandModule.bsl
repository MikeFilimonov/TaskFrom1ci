#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Contact", CommandParameter);
	OpenForm("Document.Event.ListForm",
				FormParameters,
				CommandExecuteParameters.Source,
				CommandExecuteParameters.Uniqueness,
				CommandExecuteParameters.Window,
				CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion