
#Region OverallProceduresAndFunctions

// Procedure fills inventory table.
//
&AtServer
Procedure FillInventoryTable()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	StockTransferredToThirdPartiesBalances.Products AS Products,
	|	CAST(StockTransferredToThirdPartiesBalances.Products.Description AS STRING(50)) AS ProductsDescription,
	|	StockTransferredToThirdPartiesBalances.Characteristic AS Characteristic,
	|	StockTransferredToThirdPartiesBalances.Batch AS Batch,
	|	StockTransferredToThirdPartiesBalances.Order AS SalesOrder,
	|	SUM(StockTransferredToThirdPartiesBalances.QuantityBalance) AS Quantity,
	|	SUM(StockTransferredToThirdPartiesBalances.QuantityBalance) AS Balance
	|FROM
	|	AccumulationRegister.StockTransferredToThirdParties.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract) AS StockTransferredToThirdPartiesBalances,
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &SettlementsCurrency) AS SettlementsCurrencyRate,
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|GROUP BY
	|	StockTransferredToThirdPartiesBalances.Order,
	|	StockTransferredToThirdPartiesBalances.Products,
	|	StockTransferredToThirdPartiesBalances.Characteristic,
	|	StockTransferredToThirdPartiesBalances.Batch,
	|	CAST(StockTransferredToThirdPartiesBalances.Products.Description AS STRING(50))
	|
	|ORDER BY
	|	ProductsDescription";
	
	Query.SetParameter("Company", FilterCompany);
	Query.SetParameter("Counterparty", FilterCounterparty);
	Query.SetParameter("Contract", SelectionContract);
	Query.SetParameter("SettlementsCurrency", SelectionContract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ProcessingDate", DocumentDate);
	
	InventoryTable.Load(Query.Execute().Unload());
	
EndProcedure

// Function places picking results into storage
//
&AtServer
Function PlaceInventoryToStorage()
	
	Inventory = InventoryTable.Unload(, "Selected, Products, Characteristic, Batch, SalesOrder, Quantity, Balance, SettlementsAmount");
	
	RowToDeleteArray = New Array;
	For Each StringInventory In Inventory Do
		
		If Not StringInventory.Selected Then
			RowToDeleteArray.Add(StringInventory);
		EndIf;
		
	EndDo;
	
	For Each LineNumber In RowToDeleteArray Do
		Inventory.Delete(LineNumber);
	EndDo;
	
	InventoryAddressInStorage = PutToTempStorage(Inventory, UUID);
	
	Return InventoryAddressInStorage;
	
EndFunction

#EndRegion

#Region CommandHandlers

// Procedure - command handler SelectStrings.
//
&AtClient
Procedure ChooseStringsExecute()

	For Each TabularSectionRow In InventoryTable Do
		
		TabularSectionRow.Selected = True;
		
	EndDo;
	
EndProcedure

// Procedure - command handler ExcludeStrings.
//
&AtClient
Procedure ExcludeStringsExecute()

	For Each TabularSectionRow In InventoryTable Do
		
		TabularSectionRow.Selected = False
		
	EndDo;
	
EndProcedure

// Procedure - command handler ChooseSelected.
//
&AtClient
Procedure ChooseHighlightedLines(Command)
	
	RowArray = Items.InventoryTable.SelectedRows;
	For Each LineNumber In RowArray Do
		
		TabularSectionRow = InventoryTable.FindByID(LineNumber);
		If TabularSectionRow <> Undefined Then
			TabularSectionRow.Selected = True;
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - command handler ExcludeSelected.
//
&AtClient
Procedure ExcludeSelectedRows(Command)
	
	RowArray = Items.InventoryTable.SelectedRows;
	For Each LineNumber In RowArray Do
		
		TabularSectionRow = InventoryTable.FindByID(LineNumber);
		If TabularSectionRow <> Undefined Then
			TabularSectionRow.Selected = False;
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - command handler TransferToDocument.
//
&AtClient
Procedure MoveIntoDocumentExecute()
	
	InventoryAddressInStorage = PlaceInventoryToStorage();
	NotifyChoice(InventoryAddressInStorage);
	
EndProcedure

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FilterCompany = Parameters.Company;
	FilterCounterparty = Parameters.Counterparty;
	SelectionContract = Parameters.Contract;
	DocumentCurrency = Parameters.DocumentCurrency;
	DocumentDate = Parameters.DocumentDate;
	
	FillInventoryTable();
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

// Procedure - event handler Table part selection InventoryTable.
//
&AtClient
Procedure InventoryTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.InventoryTable.CurrentData <> Undefined Then
		If Field.Name = "InventoryTableSalesOrder" Then
			ShowValue(Undefined, Items.InventoryTable.CurrentData.SalesOrder);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of field Quantity of tabular section InventoryTable.
//
&AtClient
Procedure InventoryTableQuantityOnChange(Item)
	
	TabularSectionRow = Items.InventoryTable.CurrentData;
	TabularSectionRow.Selected = (TabularSectionRow.Quantity <> 0);
	
EndProcedure

#EndRegion
