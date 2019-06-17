#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 OR StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnitPayee.RetailPriceKind);
		Query.SetParameter("ListProducts", Inventory.UnloadColumn("Products"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Products AS Products,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.Products) AS ProductsPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND Products IN (&ListProducts)
		|					AND Characteristic IN (&ListCharacteristic)) AS PricesSliceLast
		|		ON InventoryTransferInventory.Products = PricesSliceLast.Products
		|			AND InventoryTransferInventory.Characteristic = PricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(PricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = StrTemplate(NStr("en = 'For products and services %1 in string %2 of the ""Inventory"" list the retail price is not set.'"),  
								DriveServer.PresentationOfProducts(SelectionOfQueryResult.ProductsPresentation, 
															SelectionOfQueryResult.CharacteristicPresentation, 
															SelectionOfQueryResult.BatchPresentation), 
								String(SelectionOfQueryResult.LineNumber));
								
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"Products",
				Cancel
			);
			
		EndDo;
	 
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills the Inventory tabular section by balances at warehouse.
//
Procedure FillInventoryByInventoryBalances() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryInWarehousesOfBalance.Company AS Company,
	|	InventoryInWarehousesOfBalance.Products AS Products,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesOfBalance.Cell AS Cell,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryInWarehouses.Company AS Company,
	|		InventoryInWarehouses.Products AS Products,
	|		InventoryInWarehouses.Characteristic AS Characteristic,
	|		InventoryInWarehouses.Batch AS Batch,
	|		InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|		InventoryInWarehouses.Cell AS Cell,
	|		InventoryInWarehouses.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND Cell = &Cell) AS InventoryInWarehouses
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryInWarehouses.Company,
	|		DocumentRegisterRecordsInventoryInWarehouses.Products,
	|		DocumentRegisterRecordsInventoryInWarehouses.Characteristic,
	|		DocumentRegisterRecordsInventoryInWarehouses.Batch,
	|		DocumentRegisterRecordsInventoryInWarehouses.StructuralUnit,
	|		DocumentRegisterRecordsInventoryInWarehouses.Cell,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS DocumentRegisterRecordsInventoryInWarehouses
	|	WHERE
	|		DocumentRegisterRecordsInventoryInWarehouses.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryInWarehouses.Period <= &Period
	|		AND DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryInWarehousesOfBalance
	|WHERE
	|	InventoryInWarehousesOfBalance.QuantityBalance > 0
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Company,
	|	InventoryInWarehousesOfBalance.Products,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit,
	|	InventoryInWarehousesOfBalance.Cell,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("Cell", Cell);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Cell AS Cell,
	|	DocumentTable.Inventory.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Inventory.Order AS Order,
	|		Total AS Total,
	|		AmountExpense AS AmountExpense,
	|		Content AS Content,
	|		SerialNumbers AS SerialNumbers,
	|		ConnectionKey AS ConnectionKey
	|	) AS Inventory
	|FROM
	|	Document.SupplierInvoice AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	Inventory.Load(Selection.Inventory.Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
EndProcedure

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN &OrderInHeader
	|			THEN &Order
	|		ELSE CASE
	|				WHEN TableInventory.SalesOrder REFS Document.SalesOrder
	|						AND TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|					THEN TableInventory.SalesOrder
	|				ELSE UNDEFINED
	|			END
	|	END AS SalesOrder,
	|	TableInventory.InventoryGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	OrderInHeader = SalesOrderPosition = Enums.AttributeStationing.InHeader;
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("OrderInHeader", OrderInHeader);
	Query.SetParameter("Order", ?(ValueIsFilled(SalesOrder), SalesOrder, Undefined));
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If Not OrderInHeader Then
			StructureForSearch.Insert("SalesOrder", Selection.SalesOrder);
		EndIf;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Inventory Do
			
			TabularSectionRow.SalesOrder = SalesOrder;
			
		EndDo;
		
	EndIf;	
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each Row In Inventory Do
			If Row.ConsumptionGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses
				AND (OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses
				OR OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation) Then
				
				Row.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
		EndDo;
		
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// IN the event handler of the FillingProcessor document
// - filling the document according to reconciliation of products at the place of storage.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.IntraWarehouseTransfer") Then
		
		Query = New Query( 
		"SELECT
		|	IntraWarehouseTransfer.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	IntraWarehouseTransfer.Company AS Company,
		|	IntraWarehouseTransfer.StructuralUnit AS StructuralUnit,
		|	IntraWarehouseTransfer.Cell AS Cell,
		|	CASE
		|		WHEN IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN IntraWarehouseTransfer.StructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN IntraWarehouseTransfer.StructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	IntraWarehouseTransfer.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity
		|	)
		|FROM
		|	Document.IntraWarehouseTransfer AS IntraWarehouseTransfer
		|WHERE
		|	IntraWarehouseTransfer.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			Inventory.Load(QueryResultSelection.Inventory.Unload());
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Production") 
		AND FillingData.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		Query = New Query(
		"SELECT
		|	Production.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	Production.Company AS Company,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.ProductsStructuralUnit AS StructuralUnit,
		|	Production.ProductsCell AS Cell,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	Production.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Ref.SalesOrder AS SalesOrder,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		CASE
		|			WHEN Production.Products.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|				THEN 0
		|			ELSE Production.Products.Quantity
		|		END AS Reserve,
		|		SerialNumbers AS SerialNumbers,
		|		ConnectionKey AS ConnectionKey
		|	) AS Products,
		|	Production.SerialNumbersProducts.(
		|		SerialNumber AS SerialNumber,
		|		ConnectionKey AS ConnectionKey
		|	) AS SerialNumbersProducts
		|FROM
		|	Document.Production AS Production
		|WHERE
		|	Production.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
			SelectionSerialNumbers = QueryResultSelection.SerialNumbersProducts.Select();
			While SelectionSerialNumbers.Next() Do
				NewRow = SerialNumbers.Add();
				FillPropertyValues(NewRow, SelectionSerialNumbers);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Production")
		AND FillingData.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		Query = New Query(
		"SELECT
		|	Production.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	Production.Company AS Company,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.ProductsStructuralUnit AS StructuralUnit,
		|	Production.ProductsCell AS Cell,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	Production.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		CASE
		|			WHEN Production.Inventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|				THEN 0
		|			ELSE Production.Inventory.Quantity
		|		END AS Reserve,
		|		MeasurementUnit AS MeasurementUnit,
		|		Ref.SalesOrder AS SalesOrder,
		|		SerialNumbers AS SerialNumbers,
		|		ConnectionKey AS ConnectionKey
		|	) AS Inventory,
		|	Production.SerialNumbers.(
		|		SerialNumber AS SerialNumber,
		|		ConnectionKey AS ConnectionKey
		|	) AS SerialNumbers
		|FROM
		|	Document.Production AS Production
		|WHERE
		|	Production.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
			SelectionSerialNumbers = QueryResultSelection.SerialNumbers.Select();
			While SelectionSerialNumbers.Next() Do
				NewRow = SerialNumbers.Add();
				FillPropertyValues(NewRow, SelectionSerialNumbers);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder")
		AND FillingData.OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		
		Query = New Query( 
		"SELECT
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	ProductionOrder.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnitReserve
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	ProductionOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		Ref.SalesOrder AS SalesOrder
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") 
		AND FillingData.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		Query = New Query(
		"SELECT
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	ProductionOrder.Ref.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnitReserve
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	ProductionOrder.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		Ref.SalesOrder AS SalesOrder
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then	
		
		FillByPurchaseInvoice(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		
		Query = New Query(
		"SELECT
		|	WorkOrder.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses) AS OperationKind,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.Ref AS SalesOrder,
		|	WorkOrder.InventoryWarehouse AS StructuralUnit,
		|	WorkOrder.SalesStructuralUnit AS StructuralUnitPayee,
		|	WorkOrder.Materials.(
		|		Ref AS Ref,
		|		LineNumber AS LineNumber,
		|		ConnectionKey AS ConnectionKey,
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		ReserveShipment AS ReserveShipment,
		|		MeasurementUnit AS MeasurementUnit,
		|		SerialNumbers AS SerialNumbers,
		|		ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers
		|	) AS Materials,
		|	WorkOrder.SerialNumbersMaterials.(
		|		Ref AS Ref,
		|		LineNumber AS LineNumber,
		|		SerialNumber AS SerialNumber,
		|		ConnectionKey AS ConnectionKey
		|	) AS SerialNumbersMaterials
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|WHERE
		|	WorkOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionMaterials = QueryResultSelection.Materials.Select();
			While SelectionMaterials.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionMaterials);
			EndDo;
			
			SelectionSerialNumbersMaterials = QueryResultSelection.SerialNumbersMaterials.Select();
			While SelectionSerialNumbersMaterials.Next() Do
				NewRow = SerialNumbers.Add();
				FillPropertyValues(NewRow, SelectionSerialNumbersMaterials);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	If Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		
		For Each StringInventory In Inventory Do
			
			If Not ValueIsFilled(StringInventory.SalesOrder) AND StringInventory.Reserve > 0 Then
				
				DriveServer.ShowMessageAboutError(ThisObject, 
				"The row contains reserve quantity, but order is not specified.",
				"Inventory",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each StringInventory In Inventory Do
			
			If Not ValueIsFilled(SalesOrder) AND StringInventory.Reserve > 0 Then
				
				DriveServer.ShowMessageAboutError(ThisObject, 
				"The row contains reserve quantity, but order is not specified.",
				"Inventory",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get() 
		AND (OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
		OR OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses) Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en = 'In row #%Number% of the ""Inventory"" tabular section, the quantity of items transferred to reserve exceeds the total inventory quantity.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	PerformanceEstimationClientServer.StartTimeMeasurement("InventoryTransferDocumentPostingInitialization");
	
	// Initialization of document data
	Documents.InventoryTransfer.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("InventoryTransferDocumentPostingMovementsCreation");
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);

	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("InventoryTransferDocumentPostingMovementsRecord");
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("InventoryTransferDocumentPostingControl");
	
	// Control
	Documents.InventoryTransfer.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryTransfer.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf
