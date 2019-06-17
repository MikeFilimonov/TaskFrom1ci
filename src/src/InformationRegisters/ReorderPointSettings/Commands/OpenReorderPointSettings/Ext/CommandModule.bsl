
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure("Products", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.ReorderPointSettings.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
