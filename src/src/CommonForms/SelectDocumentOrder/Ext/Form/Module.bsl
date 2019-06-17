
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.Company.Visible = Not Parameters.Filter.Property("Company");
	
	If Parameters.Filter.Property("Counterparty") Then
		List.Parameters.SetParameterValue("CounterpartyByDefault", Parameters.Filter.Counterparty);
	Else
		List.Parameters.SetParameterValue("CounterpartyByDefault", Catalogs.Counterparties.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Contract") Then
		List.Parameters.SetParameterValue("ContractByDefault", Parameters.Filter.Contract);
	Else
		List.Parameters.SetParameterValue("ContractByDefault", Catalogs.CounterpartyContracts.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Currency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.Currency);
	ElsIf Parameters.Filter.Property("DocumentCurrency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.DocumentCurrency);
	Else
		List.Parameters.SetParameterValue("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseDocument(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		DocumentData = New Structure;
		DocumentData.Insert("Document", CurrentData.Ref);
		DocumentData.Insert("Contract", CurrentData.Contract);
		
		NotifyChoice(DocumentData);
	Else
		Close();
	EndIf;
	
EndProcedure

// The procedure is called when clicking button "Open document".
//
&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormFieldEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	DocumentData = New Structure;
	DocumentData.Insert("Document", CurrentData.Ref);
	DocumentData.Insert("Contract", CurrentData.Contract);
	
	NotifyChoice(DocumentData);
	
EndProcedure

#EndRegion
