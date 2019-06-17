
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Volume", CommandParameter);
	
	OpenForm("CommonForm.FilesLocation",
	             FormParameters,
	             CommandExecuteParameters.Source,
	             CommandExecuteParameters.Uniqueness,
	             CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
