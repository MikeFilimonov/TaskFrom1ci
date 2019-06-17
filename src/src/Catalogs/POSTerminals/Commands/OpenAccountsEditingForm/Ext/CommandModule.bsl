
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Catalog.POSTerminals.Form.GLAccountsEditForm",
		GetParametersStructure(CommandParameter),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function GetParametersStructure(CommandParameter)
	
	Return New Structure(
		"GLAccount, Ref",
		CommandParameter.GLAccount, CommandParameter.Ref);
	
EndFunction
