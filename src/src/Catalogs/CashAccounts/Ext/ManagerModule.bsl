﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Gets the default petty cash for the company, or the only petty cash if the default petty cash is not specified.
//
Function GetPettyCashByDefault(Company = Undefined) Export

	PettyCashByDefault = Catalogs.CashAccounts.EmptyRef();
	
	If PettyCashByDefault.IsEmpty() AND Company <> Undefined Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	CashAccounts.Ref AS PettyCashByDefault
		|FROM
		|	Catalog.Companies AS Companies
		|		INNER JOIN Catalog.CashAccounts AS CashAccounts
		|		ON Companies.PettyCashByDefault = CashAccounts.Ref
		|WHERE
		|	Companies.Ref = &Ref";
		
		Query.SetParameter("Ref", Company);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			PettyCashByDefault = Selection.PettyCashByDefault;
		EndIf;
		
	EndIf;
	
	If PettyCashByDefault.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 2
		|	CashAccounts.Ref AS PettyCashByDefault
		|FROM
		|	Catalog.CashAccounts AS CashAccounts
		|WHERE
		|	NOT CashAccounts.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 И Selection.Next() Then
			PettyCashByDefault = Selection.PettyCashByDefault;
		EndIf;
		
	EndIf;
	
	Return PettyCashByDefault;

EndFunction

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