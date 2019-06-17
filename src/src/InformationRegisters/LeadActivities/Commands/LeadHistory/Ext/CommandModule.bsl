#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Filter = New Structure("Lead", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.LeadActivities.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
EndProcedure

#EndRegion