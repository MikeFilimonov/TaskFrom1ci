&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Counterparty", CommandParameter);
	
	FormParameters = New Structure("VariantKey, UsePurposeKey, Filter, GenerateOnOpen, ReportVariantsCommandsVisible", 
		"StatementBrieflyContext",
		"StatementBrieflyContextByCounterparty",
		FilterStructure, 
		True, 
		False);
	
	OpenForm("Report.StatementOfAccount.Form",
		FormParameters,
		,
		"Counterparty=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
