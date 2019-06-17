#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Property("GLExpenseAccount") Then
		
		If ValueIsFilled(Parameters.GLExpenseAccount) Then
			
			If Parameters.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses Then
				
				MessageText = NStr("en = 'Business area is not specified for the ""Other expenses"" account type.'");
				DriveServer.ShowMessageAboutError(, MessageText);
				
				StandardProcessing = False;
				
			ElsIf Parameters.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
				  OR Parameters.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses Then
				  
				MessageText = NStr("en = 'Business area is not specified for the ""Unfinished production"" or ""Indirect expenses"" account types.'");
				DriveServer.ShowMessageAboutError(, MessageText);
				
				StandardProcessing = False;
				
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'Account is not selected.'");
			DriveServer.ShowMessageAboutError(, MessageText);
			
			StandardProcessing = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf