#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	BankAccounts.Ref AS Ref
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|WHERE
	|	(BankAccounts.AccountType = ""Current""
	|			OR BankAccounts.AccountType = ""Deposit"")";
	
	DataSelection = Query.Execute().Select();
	While DataSelection.Next() Do
		
		BankAccountObject = DataSelection.Ref.GetObject();
		If BankAccountObject.AccountType = "Current" Then
			BankAccountObject.AccountType = "Transactional";
		ElsIf BankAccountObject.AccountType = "Deposit" Then
			BankAccountObject.AccountType = "Savings";
		EndIf;
		
		Try
			BankAccountObject.Write();
		Except
			TextError = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'An error on writing item: %1'", CommonUseClientServer.MainLanguageCode()),
				DataSelection.Ref);
			WriteLogEvent(TextError, EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;		
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf