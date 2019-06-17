Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PresentationCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	AccountCurrency = Constants.PresentationCurrency.Get();
	Errors = Undefined;
	
	For Each Line In Expenses Do
		If Line.CalculationMethod = Enums.CostsAmountCalculationMethods.FixedAmount AND Not ValueIsFilled(Line.Currency) Then
			If PresentationCurrency Then
				LineIndex = Expenses.IndexOf(Line);
				CommonUseClientServer.AddUserError(
					Errors, 
					"Expenses.Currency",,
					"Expenses.Currency",
					LineIndex,
					NStr("en = 'Not specified currency in line %1'"),
					LineIndex);
			Else
				Line.Currency = AccountCurrency;
			EndIf; 
		EndIf; 
	EndDo;
	
	If Not Errors = Undefined Then
		CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	EndIf; 
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	// Update requisite ConnectionKey
	
	ConnectionKey = 0;
	For Each Line In Inventory Do
		ConnectionKey = Max(ConnectionKey, Line.ConnectionKey); 
	EndDo; 
	For Each Line In Expenses Do
		ConnectionKey = Max(ConnectionKey, Line.ConnectionKey); 
	EndDo;
	
	For Each Line In Inventory Do
		If Line.ConnectionKey=0 Then
			ConnectionKey = ConnectionKey + 1;
			Line.ConnectionKey = ConnectionKey;
		EndIf; 
	EndDo; 
	For Each Line In Expenses Do
		If Line.ConnectionKey = 0 Then
			ConnectionKey = ConnectionKey + 1;
			Line.ConnectionKey = ConnectionKey;
		EndIf; 
	EndDo; 
	
EndProcedure
