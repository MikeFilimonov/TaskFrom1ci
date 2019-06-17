#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Checked attributes deletion from structure depending on functional option.
	If Not Constants.UseBudgeting.Get()
		  AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ClosingAccount");
	EndIf;
	
	If Constants.UseBudgeting.Get()
	   AND TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ClosingAccount");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel)
	
	If TypeOfAccount <> Enums.GLAccountsTypes.Revenue
	   AND TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses
	   AND TypeOfAccount <> Enums.GLAccountsTypes.OtherIncome
	   AND TypeOfAccount <> Enums.GLAccountsTypes.OtherExpenses
	   AND TypeOfAccount <> Enums.GLAccountsTypes.LoanInterest Then
		MethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute;
	EndIf;
	
	If TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		ClosingAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	If Not ValueIsFilled(Order) Then
		Order = 1;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf