
#Region OverallProceduresAndFunctions

// Procedure fills inventory table.
//
&AtServer
Procedure FillInventoryTable()
	
	Query = New Query();
	Query.SetParameter("Company",		FilterCompany);
	Query.SetParameter("Counterparty",			FilterCounterparty);
	Query.SetParameter("Contract",			SelectionContract);
	Query.SetParameter("SettlementsCurrency",		SelectionContract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency",	DocumentCurrency);
	Query.SetParameter("SupplierPriceTypes",	SupplierPriceTypes);
	Query.SetParameter("PriceKindCurrency",		SupplierPriceTypes.PriceCurrency);
	Query.SetParameter("PresentationCurrency",		Constants.PresentationCurrency.Get());
	
	Query.SetParameter("BeginOfPeriod",		BegOfDay(FilterStartDate));
	Query.SetParameter("EndOfPeriod",		EndOfDay(FilterEndDate));
	
	Query.Text = 
	"SELECT
	|	SalesTurnovers.Products AS Products,
	|	SalesTurnovers.Characteristic AS Characteristic,
	|	SalesTurnovers.Batch AS Batch,
	|	SalesTurnovers.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesInvoice)
	|				OR VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesOrder)
	|			THEN SalesTurnovers.Document.Counterparty
	|	END AS Customer,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesInvoice)
	|			THEN SalesTurnovers.Document.Date
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesOrder)
	|			THEN SalesTurnovers.Document.Finish
	|	END AS DateOfSale,
	|	SalesTurnovers.QuantityTurnover AS Quantity,
	|	SalesTurnovers.QuantityTurnover AS Balance,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &PresentationCurrency
	|						THEN (SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) / SalesTurnovers.QuantityTurnover
	|					ELSE ISNULL((SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity), 0) / SalesTurnovers.QuantityTurnover
	|				END
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &PresentationCurrency
	|						THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|					ELSE ISNULL((SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity), 0)
	|				END
	|		ELSE 0
	|	END AS Amount,
	|	ISNULL(CASE
	|			WHEN &DocumentCurrency = &PriceKindCurrency
	|				THEN FixedReceiptPrices.Price
	|			ELSE FixedReceiptPrices.Price * PriceKindCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * PriceKindCurrencyRate.Multiplicity)
	|		END, 0) AS ReceiptPrice,
	|	StockReceivedFromThirdPartiesBalances.Order AS PurchaseOrder
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			,
	|			Company = &Company
	|				AND Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|				AND Batch.BatchOwner = &Counterparty) AS SalesTurnovers
	|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract) AS StockReceivedFromThirdPartiesBalances
	|		ON (StockReceivedFromThirdPartiesBalances.Products = SalesTurnovers.Products)
	|			AND (StockReceivedFromThirdPartiesBalances.Characteristic = SalesTurnovers.Characteristic)
	|			AND (StockReceivedFromThirdPartiesBalances.Batch = SalesTurnovers.Batch)
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&EndOfPeriod,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND Actuality) AS FixedReceiptPrices
	|		ON (FixedReceiptPrices.Products = SalesTurnovers.Products)
	|			AND (FixedReceiptPrices.Characteristic = SalesTurnovers.Characteristic)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &SettlementsCurrency) AS SettlementsCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &PresentationCurrency) AS AccountingCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &PriceKindCurrency) AS PriceKindCurrencyRate
	|		ON (TRUE)
	|WHERE
	|	SalesTurnovers.QuantityTurnover > 0
	|
	|ORDER BY
	|	Products,
	|	Characteristic,
	|	Batch";
	
	InventoryTable.Load(Query.Execute().Unload());
	
EndProcedure

// Function places picking results into storage
//
&AtServer
Function PlaceInventoryToStorage()
	
	Inventory = InventoryTable.Unload(, "Selected, Products, Characteristic, Batch, SalesOrder, PurchaseOrder, Customer, DateOfSale, Quantity, Balance, Price, Amount, ReceiptPrice");
	
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

// Procedure fills the period table.
//
Procedure FillPeriodRetail()
	
	Query = New Query();
	Query.Text = 
	"SELECT TOP 1
	|	AccountSalesToConsignor.Date AS Date
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|WHERE
	|	AccountSalesToConsignor.Posted
	|	AND AccountSalesToConsignor.Company = &Company
	|	AND AccountSalesToConsignor.Counterparty = &Counterparty
	|	AND AccountSalesToConsignor.Contract = &Contract
	|	AND AccountSalesToConsignor.Date < &DocumentDate
	|	AND AccountSalesToConsignor.Ref <> &Ref
	|
	|ORDER BY
	|	Date DESC";
	
	Query.SetParameter("Company",	Company);
	Query.SetParameter("Counterparty",		FilterCounterparty);
	Query.SetParameter("Contract",		SelectionContract);
	Query.SetParameter("Ref",			CurrentDocument);
	Query.SetParameter("DocumentDate",	EndOfDay(FilterEndDate));
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		FilterStartDate = Date('00010101');
	Else
		Selection = Result.Select();
		Selection.Next();
		FilterStartDate = Selection.Date;
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - handler of command SetInterval.
//
&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate = FilterStartDate;
	Dialog.Period.EndDate = FilterEndDate;
	
	Dialog.Show(New NotifyDescription("SetIntervalEnd", ThisObject, New Structure("Dialog", Dialog)));
	
EndProcedure

&AtClient
Procedure SetIntervalEnd(Result, AdditionalParameters) Export
	
	Dialog = AdditionalParameters.Dialog;
	
	If ValueIsFilled(Result) Then
		FilterStartDate = Dialog.Period.StartDate;
		FilterEndDate = Dialog.Period.EndDate;
		FillInventoryTable();
	EndIf;
	
EndProcedure

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
	
	FilterCompany = Parameters.ParentCompany;
	Company = Parameters.Company;
	FilterCounterparty = Parameters.Counterparty;
	SelectionContract = Parameters.Contract;
	DocumentCurrency = Parameters.DocumentCurrency;
	SupplierPriceTypes = Parameters.SupplierPriceTypes;
	CurrentDocument = Parameters.CurrentDocument;
	FilterEndDate = Parameters.DocumentDate;
	
	FillPeriodRetail();
	
	FillInventoryTable();
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

// Procedure - event handler OnChange of the field FilterStartDate.
//
&AtClient
Procedure FilterBeginningDateOnChange(Item)
	
	FillInventoryTable();
	
EndProcedure

// Procedure - event handler OnChange of the field FilterEndDate.
//
&AtClient
Procedure FilterEndingDateOnChange(Item)
	
	FillInventoryTable();
	
EndProcedure

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
	TabularSectionRow.Amount = TabularSectionRow.Price * TabularSectionRow.Quantity;
	
EndProcedure

#EndRegion
