
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	FormParameters = New Structure(
			"Filter, SettingKey, GenerateOnOpen",
			New Structure("Order", CommandParameter),
			"Order",
			True);
	
	OpenForm("DataProcessor.CounterpartyDocuments.Form.SupplierQuoteDocuments",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);

EndProcedure
