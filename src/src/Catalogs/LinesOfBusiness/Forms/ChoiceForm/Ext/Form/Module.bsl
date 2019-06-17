#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("GLExpenseAccount") Then
		
		If ValueIsFilled(Parameters.GLExpenseAccount) Then
			
			If Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
			   AND Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
			   AND Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
				
				MessageText = NStr("en = 'Business area is not specified for this account type.'");
				DriveServer.ShowMessageAboutError(, MessageText, , , , Cancel);
				
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'Account is not selected.'");
			DriveServer.ShowMessageAboutError(, MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
