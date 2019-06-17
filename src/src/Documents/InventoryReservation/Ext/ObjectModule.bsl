#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions
// Procedure of document filling based on sales order.
//
// Parameters:
//  BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
//  FillingData - Structure - Document filling data
//	
Procedure FillBySalesOrderNewPlace(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OperationKind, OrderState, Closed, Posted"));
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		-InventoryBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.SalesOrder = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder = &BasisDocument) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Products.ProductsType AS ProductsType,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrder.StructuralUnitReserve AS NewReservePlace
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON SalesOrderInventory.Ref = SalesOrder.Ref
	|WHERE
	|	SalesOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	
	InventoryTable = ResultsArray[1].Unload();
	
	If BalanceTable.Count() > 0 Then
		FillInventoryBySalesOrderNewPlace(InventoryTable, BalanceTable);
	EndIf;
	
EndProcedure

// Procedure of document filling based on sales order.
//
// Parameters:
//  BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
//  FillingData - Structure - Document filling data
//	
Procedure FillBySalesOrderOriginalPlace(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OrderState, Closed, Posted"));
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.OriginalPlace AS OriginalReservePlace,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	SUM(OrdersBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryBalances.StructuralUnit AS OriginalPlace,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Products.MeasurementUnit AS MeasurementUnit,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.SupplySource,
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		PlacementBalances.Products.MeasurementUnit,
	|		PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.OriginalPlace,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.Batch,
	|	OrdersBalance.MeasurementUnit
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.OperationKind AS OperationKind,
	|	SalesOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(SalesOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE SalesOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor
	|	),
	|	SalesOrder.Materials.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(SalesOrder.Materials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE SalesOrder.Materials.MeasurementUnit.Factor
	|		END AS Factor
	|	)
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	Selection = ResultsArray[1].Select();
	Selection.Next();
	If BalanceTable.Count() > 0 Then
		FillInventoryBySalesOrderOriginalPlace(Selection, BalanceTable, "Inventory");
		For Each RowBalances In BalanceTable Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, RowBalances);
			NewRow.MeasurementUnit = RowBalances.MeasurementUnit;
		EndDo;
	EndIf;
	
EndProcedure

// Procedure of document filling based on sales order.
//
// Parameters:
//  BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
//  FillingData - Structure - Document filling data
//	
Procedure FillByWorkOrderOriginalPlace(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OrderState, Closed, Posted"));
	
	Documents.WorkOrder.CheckAbilityOfEnteringByWorkOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.OriginalPlace AS OriginalReservePlace,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	SUM(OrdersBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryBalances.StructuralUnit AS OriginalPlace,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Products.MeasurementUnit AS MeasurementUnit,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.SupplySource,
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		PlacementBalances.Products.MeasurementUnit,
	|		PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.OriginalPlace,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.Batch,
	|	OrdersBalance.MeasurementUnit
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(WorkOrder.Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE WorkOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor
	|	) AS Inventory,
	|	WorkOrder.Materials.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(WorkOrder.Materials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE WorkOrder.Materials.MeasurementUnit.Factor
	|		END AS Factor
	|	) AS Materials
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	Selection = ResultsArray[1].Select();
	Selection.Next();
	If BalanceTable.Count() > 0 Then
		FillInventoryBySalesOrderOriginalPlace(Selection, BalanceTable, "Inventory");
		FillInventoryBySalesOrderOriginalPlace(Selection, BalanceTable, "Materials");
		For Each RowBalances In BalanceTable Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, RowBalances);
			NewRow.MeasurementUnit = RowBalances.MeasurementUnit;
		EndDo;
	EndIf;
	
EndProcedure

// Procedure for filling the row of the "Inventory based on sales order" tabular section.
//
Procedure FillInventoryBySalesOrderNewPlace(InventoryTable, BalanceTable)
	
	For Each TSRow In InventoryTable Do
		
		If TSRow.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", TSRow.Products);
		StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TSRow);
		
		QuantityToWriteOff = TSRow.Quantity * TSRow.Factor;
		BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
		If BalanceRowsArray[0].QuantityBalance < 0 Then
			
			NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / TSRow.Factor;
			
		EndIf;
		
		If BalanceRowsArray[0].QuantityBalance <= 0 Then
			BalanceTable.Delete(BalanceRowsArray[0]);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure for filling the row of the "Inventory based on sales order" tabular section.
//
Procedure FillInventoryBySalesOrderOriginalPlace(Selection, BalanceTable, TabularSectionName)
	
	For Each TSRow In Selection[TabularSectionName].Unload() Do
		
		If TSRow.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", TSRow.Products);
		StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		For Each RowBalances In BalanceRowsArray Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, RowBalances);
			NewRow.Quantity = RowBalances.Quantity / TSRow.Factor;
			NewRow.MeasurementUnit = TSRow.MeasurementUnit;
			BalanceTable.Delete(RowBalances);
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		
		FillBySalesOrderNewPlace(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND TypeOf(FillingData.FillDocument) = Type("DocumentRef.SalesOrder")
		AND FillingData.RemoveReser Then
		
		FillBySalesOrderOriginalPlace(FillingData.FillDocument);
		
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND TypeOf(FillingData.FillDocument) = Type("DocumentRef.WorkOrder")
		AND FillingData.RemoveReser Then
		
		FillByWorkOrderOriginalPlace(FillingData.FillDocument);
		
	EndIf;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	
EndProcedure

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	For Each InventoryTableRow In Inventory Do
		
		If Not ValueIsFilled(InventoryTableRow.OriginalReservePlace)
		   AND Not ValueIsFilled(InventoryTableRow.NewReservePlace) Then
		   
		   DriveServer.ShowMessageAboutError(ThisObject, 
		   "Initial place of reserve is not specified.",
		   "Inventory",
		   InventoryTableRow.LineNumber,
		   "OriginalReservePlace",
		   Cancel);
		   
		   DriveServer.ShowMessageAboutError(ThisObject, 
		   "New place of reserve is not specified.",
		   "Inventory",
		   InventoryTableRow.LineNumber,
		   "NewReservePlace",
		   Cancel);
		   
		EndIf;
		
	EndDo;	
	
EndProcedure

// The event handler PostingProcessor of a document includes:
// - deletion of document register records,
// - header structure of required attribute document is formed,
// - temporary table is formed by tabular section Products,
// - product receipt in storage places,
// - free balances receipt of products in storage places,
// - product cost receipt in storage places,
// - document posting creation.
//
Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryReservation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryReservation.RunControl(Ref, AdditionalProperties, Cancel);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryReservation.RunControl(Ref, AdditionalProperties, Cancel, True);

EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	AdditionalProperties.Insert("WriteMode", WriteMode);
EndProcedure

#EndRegion

#EndIf
