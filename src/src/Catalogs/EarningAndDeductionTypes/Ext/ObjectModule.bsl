#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Type <> Enums.EarningAndDeductionTypes.Tax Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not IsFolder	Then
		GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollExpenses");
	EndIf;
	
EndProcedure
