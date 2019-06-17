
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	FormParameters = New Structure(
			"Filter, SettingKey, GenerateOnOpen",
			New Structure("Counterparty", CommandParameter),
			"Counterparty",
			True);
	
	OpenForm("DataProcessor.CounterpartyDocuments.Form.CounterpartyDocuments",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);

EndProcedure
