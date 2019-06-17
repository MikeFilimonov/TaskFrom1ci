
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	// Insert the handler content.
	FormParameters = New Structure("DocumentAccruals", CommandParameter);
	OpenForm("Document.LoanInterestCommissionAccruals.Form.FormOfEnteringCashFundExpense", 
		FormParameters, 
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window, 
		CommandExecuteParameters.URL);
EndProcedure
