
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Filter = New Structure("CompanyResource", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.CompanyResourceTypes.Form.FormForResources", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
