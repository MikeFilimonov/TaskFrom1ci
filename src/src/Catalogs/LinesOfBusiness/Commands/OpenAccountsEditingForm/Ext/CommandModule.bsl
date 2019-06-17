
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.LinesOfBusiness.Form.GLAccountsEditForm",
		ParametersStructure,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure

&AtServer
Function GetParametersStructure(CommandParameter)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ProfitGLAccount", CommandParameter.ProfitGLAccount);
	ParametersStructure.Insert("Ref", CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
