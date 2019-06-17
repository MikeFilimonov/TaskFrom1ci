
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.Products.Form.ObsoleteGLAccountsEditForm",
		ParametersStructure,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure

&AtServer
Function GetParametersStructure(CommandParameter)
	
	ParametersStructure = New Structure(
		"InventoryGLAccount, ExpensesGLAccount, ProductsType, Ref",
		CommandParameter.InventoryGLAccount, CommandParameter.ExpensesGLAccount, CommandParameter.ProductsType, CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
