&AtServer
Function GetCounterpartiesArray(DocumentArray)
	
	CounterpartiesArray = New Array;
	For Each ArrayElement In DocumentArray Do
		
		CounterpartiesArray.Add(ArrayElement.Counterparty);
		
	EndDo;
	
	Return CounterpartiesArray;
	
EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CounterpartiesArray = GetCounterpartiesArray(CommandParameter);
	
	FormParameters = New Structure("VariantKey, UsePurposeKey, Filter, GenerateOnOpen, ReportVariantsCommandsVisible", 
		"StatementBrieflyContext",
		CounterpartiesArray,
		New Structure("Counterparty", CounterpartiesArray), 
		True, 
		False);
	
	OpenForm("Report.StatementOfAccount.Form",
		FormParameters,
		,
		"Counterparty=" + CounterpartiesArray,
		CommandExecuteParameters.Window
	);
	
EndProcedure
