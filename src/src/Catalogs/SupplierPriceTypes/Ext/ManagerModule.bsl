﻿#If Server Or ThickClientOrdinaryApplication Then

#Region ProgramInterface

// Function receives the default counterparty price kind
//
Function CounterpartyDefaultPriceKind(Counterparty) Export
	
	Return ?(ValueIsFilled(Counterparty) AND ValueIsFilled(Counterparty.ContractByDefault),
				Counterparty.ContractByDefault.SupplierPriceTypes,
				Undefined);
	
EndFunction

// Function finds any first price kind of specified counterparty
//
Function FindAnyFirstKindOfCounterpartyPrice(Counterparty) Export
	
	If Not ValueIsFilled(Counterparty) Then
		
		Return Undefined;
		
	EndIf;
	
	Query = New Query("SELECT TOP 1 * FROM Catalog.SupplierPriceTypes AS SupplierPriceTypes WHERE SupplierPriceTypes.Owner = &Counterparty");
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Ref, Undefined);
	
EndFunction

// Function creates a price kind of specified counterparty
//
Function CreateSupplierPriceTypes(Counterparty, SettlementsCurrency) Export
	
	If Not ValueIsFilled(Counterparty)
		OR Not ValueIsFilled(SettlementsCurrency) Then
		
		Return Undefined;
		
	EndIf;
	
	FillStructure = New Structure("Description, Owner, PriceCurrency, PriceIncludesVAT, Comment", 
		Left("Prices for " + Counterparty.Description, 25),
		Counterparty,
		SettlementsCurrency,
		True,
		"Registers the incoming prices. It is created automatically.");
		
	NewSupplierPriceTypes = Catalogs.SupplierPriceTypes.CreateItem();
	FillPropertyValues(NewSupplierPriceTypes, FillStructure);
	NewSupplierPriceTypes.Write();
	
	Return NewSupplierPriceTypes.Ref;
	
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

#EndRegion

#EndIf