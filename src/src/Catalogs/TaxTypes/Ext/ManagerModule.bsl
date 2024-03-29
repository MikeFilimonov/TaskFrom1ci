﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

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

Procedure FillPredefinedItemsData() Export
	
	VATRef = VAT;
	
	If CommonUse.ObjectAttributeValue(VATRef, "Code") <> "000000001" Then
		Return;
	EndIf;
	
	VATObj = VATRef.GetObject();
	
	VATObj.GLAccount				 = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable");
	VATObj.GLAccountForReimbursement = VATObj.GLAccount;
	
	VATObj.SetNewCode();
	
	InfobaseUpdateDrive.WriteCatalogObject(VATObj);
	
EndProcedure

#EndRegion

#EndIf