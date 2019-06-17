
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Filter = New Structure("Products", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.CounterpartyPrices.Form.ProductsForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
