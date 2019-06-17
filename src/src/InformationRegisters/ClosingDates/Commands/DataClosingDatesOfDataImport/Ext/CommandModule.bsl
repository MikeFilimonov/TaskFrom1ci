
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("DataClosingDatesOfDataImport", True);
	OpenForm("InformationRegister.ClosingDates.Form.ClosingDates", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
