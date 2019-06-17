﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableProduction(DocumentRefProductionOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	UNDEFINED AS SalesOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Ref", DocumentRefProductionOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 				RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", 		RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", 				RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", 	RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", 		RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", 					RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt.
			TableRowReceipt = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.Products = RowTableInventory.ProductsCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowReceipt.ProductsCorr = RowTableInventory.Products;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.CustomerCorrOrder = Undefined;
			
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
			
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisassembly(DocumentRefProductionOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	UNDEFINED AS SalesOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Ref", DocumentRefProductionOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 				RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", 		RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", 				RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", 	RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", 		RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", 					RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt.
			TableRowReceipt = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.Products = RowTableInventory.ProductsCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowReceipt.ProductsCorr = RowTableInventory.Products;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.CustomerCorrOrder = Undefined;
			
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
			
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefProductionOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(OrderForProductsProduction.Ref.Finish, Day) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	OrderForProductsProduction.Ref AS Order,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	ProductionOrderInventory.LineNumber,
	|	BEGINOFPERIOD(ProductionOrderInventory.Ref.Start, Day),
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	ProductionOrderInventory.Ref.SalesOrder,
	|	ProductionOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OrderForProductsProduction.Ref.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.Ref AS ProductionOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND OrderForProductsProduction.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber,
	|	BEGINOFPERIOD(ProductionOrderInventory.Ref.Start, Day) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	ProductionOrderInventory.Ref.SalesOrder AS SalesOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	ProductionOrderInventory.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OrderForProductsProduction.Ref.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.Ref.SalesOrder AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	OrderForProductsProduction.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND OrderForProductsProduction.Ref.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND OrderForProductsProduction.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ProductionOrderInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.Ref.StructuralUnitReserve AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrderInventory.Ref.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionOrderInventory.Products.InventoryGLAccount
	|		ELSE ProductionOrderInventory.Products.ExpensesGLAccount
	|	END AS GLAccount,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN ProductionOrderInventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionOrderInventory.Ref.SalesOrder
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Reserve
	|		ELSE ProductionOrderInventory.Reserve * ProductionOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND ProductionOrderInventory.Reserve > 0
	|	AND ProductionOrderInventory.Ref.StructuralUnitReserve <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	TableInventory.RecordKindAccountingJournalEntries AS RecordKindAccountingJournalEntries,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.RecordKindAccountingJournalEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderForProductsProduction.Ref.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN OrderForProductsProduction.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OrderForProductsProduction.Ref.SalesOrder
	|	END AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	OrderForProductsProduction.Specification AS Specification,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS QuantityPlan
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefProductionOrder);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", 	NStr("en = 'Inventory reservation'", MainLanguageCode));

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",	Result[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", 		Result[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",		Result[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", 			Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", 				Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", 		Result[6].Unload());
	
	// Calculation of the inventory write-off cost.
	GenerateTableProduction(DocumentRefProductionOrder, StructureAdditionalProperties);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefProductionOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(OrderForProductsProduction.Ref.Finish, Day) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	OrderForProductsProduction.Ref.SalesOrder AS Order,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	ProductionOrderInventory.LineNumber,
	|	BEGINOFPERIOD(ProductionOrderInventory.Ref.Start, Day),
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	ProductionOrderInventory.Ref,
	|	ProductionOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.Ref AS ProductionOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BEGINOFPERIOD(OrderForProductsProduction.Ref.Start, Day) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	OrderForProductsProduction.Ref.SalesOrder AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.Ref.SalesOrder AS SalesOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	ProductionOrderInventory.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND ProductionOrderInventory.Ref.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	OrderForProductsProduction.Ref.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.Ref.StructuralUnitReserve AS StructuralUnit,
	|	CASE
	|		WHEN OrderForProductsProduction.Ref.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN OrderForProductsProduction.Products.InventoryGLAccount
	|		ELSE OrderForProductsProduction.Products.ExpensesGLAccount
	|	END AS GLAccount,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN OrderForProductsProduction.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OrderForProductsProduction.Ref.SalesOrder
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Reserve
	|		ELSE OrderForProductsProduction.Reserve * OrderForProductsProduction.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.ProductionOrder.Products AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.Ref = &Ref
	|	AND OrderForProductsProduction.Reserve > 0
	|	AND OrderForProductsProduction.Ref.StructuralUnitReserve <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	AND (OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Ref.Closed = FALSE
	|			OR OrderForProductsProduction.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	TableInventory.RecordKindAccountingJournalEntries AS RecordKindAccountingJournalEntries,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.RecordKindAccountingJournalEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrderInventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionOrderInventory.Ref.SalesOrder
	|	END AS SalesOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	ProductionOrderInventory.Specification AS Specification,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.MeasurementUnit.Factor
	|	END AS QuantityPlan
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|	AND (ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefProductionOrder);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation",	NStr("en = 'Inventory reservation'", MainLanguageCode));

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",	Result[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders",		Result[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",		Result[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders",				Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory",				Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease",			Result[6].Unload());
	
	// Calculation of the inventory write-off cost.
	GenerateTableInventoryDisassembly(DocumentRefProductionOrder, StructureAdditionalProperties);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefProductionOrder, StructureAdditionalProperties) Export
	
	If DocumentRefProductionOrder.OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		
		InitializeDocumentDataAssembly(DocumentRefProductionOrder, StructureAdditionalProperties);
		
	Else
		
		InitializeDocumentDataDisassembly(DocumentRefProductionOrder, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefProductionOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsProductionOrdersChange",
	// "RegisterRecordsBackordersChange", "RegisterRecordsInventoryDemandChange",
	// "RegisterRecordsInventoryChange" contain records, control products implementation.
	
	If StructureTemporaryTables.RegisterRecordsProductionOrdersChange
		OR StructureTemporaryTables.RegisterRecordsBackordersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.GLAccount) AS GLAccountPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.SalesOrder) AS SalesOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.SalesOrder AS SalesOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsProductionOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.ProductionOrder) AS ProductionOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(ProductionOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsProductionOrdersChange.QuantityChange, 0) + ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS BalanceProductionOrders,
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS QuantityBalanceProductionOrders
		|FROM
		|	RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange
		|		LEFT JOIN AccumulationRegister.ProductionOrders.Balance(
		|				&ControlTime,
		|				(Company, ProductionOrder, Products, Characteristic) In
		|					(SELECT
		|						RegisterRecordsProductionOrdersChange.Company AS Company,
		|						RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
		|						RegisterRecordsProductionOrdersChange.Products AS Products,
		|						RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange)) AS ProductionOrdersBalances
		|		ON RegisterRecordsProductionOrdersChange.Company = ProductionOrdersBalances.Company
		|			AND RegisterRecordsProductionOrdersChange.ProductionOrder = ProductionOrdersBalances.ProductionOrder
		|			AND RegisterRecordsProductionOrdersChange.Products = ProductionOrdersBalances.Products
		|			AND RegisterRecordsProductionOrdersChange.Characteristic = ProductionOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.MovementType) AS MovementTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(InventoryDemandBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		LEFT JOIN AccumulationRegister.InventoryDemand.Balance(
		|				&ControlTime,
		|				(Company, MovementType, SalesOrder, Products, Characteristic) In
		|					(SELECT
		|						RegisterRecordsInventoryDemandChange.Company AS Company,
		|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
		|						RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsInventoryDemandChange.Products AS Products,
		|						RegisterRecordsInventoryDemandChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange)) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
		|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|WHERE
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		LEFT JOIN AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) In
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty() Then
			DocumentObjectProductionOrder = DocumentRefProductionOrder.GetObject()
		EndIf;
		
		// Negative balance of inventories and costs.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by work orders.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region FillingProcedures

// Checks the possibility of input on the basis.
//
Procedure VerifyEnteringAbilityByProductionOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = 'Please select a posted document.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			ErrorText = NStr("en = 'Please select an order that is not completed.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'Generation from orders with ""Open"" status is not available.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName = "")
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProductionOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", 		ObjectsArray);
	Query.SetParameter("Characteristic", 	NStr("en = 'Characteristic:'"));
	Query.Text = 
	"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Number AS Number,
	|	ProductionOrder.Date AS DocumentDate,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.SalesOrder AS Order,
	|	ProductionOrder.Start AS LaunchDate,
	|	ProductionOrder.Finish AS DateOfIssue,
	|	ProductionOrder.StructuralUnit AS Department,
	|	ProductionOrder.Company.Prefix AS Prefix,
	|	ProductionOrder.Products.(
	|		LineNumber AS LineNumber,
	|		Products.DescriptionFull AS Products,
	|		Products.SKU AS SKU,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity
	|	),
	|	ProductionOrder.Inventory.(
	|		LineNumber AS LineNumber,
	|		Products.DescriptionFull AS Material,
	|		Products.SKU AS SKU,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder,
	|	Constants AS Constants
	|WHERE
	|	ProductionOrder.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref,
	|	LineNumber";
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProductionOrder_TemplateWarehouseRequirement";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.ProductionOrder.PF_MXL_TemplateRequirementAtWarehouse");
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;
	
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Request to warehouse #%1 dated %2'"),
			DocumentNumber,
			Format(Header.DocumentDate, "DLF=DD"));
		
		SpreadsheetDocument.Put(TemplateArea);

		// Header.
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		// TS Products.
		StringSelectionProducts = Header.Products.Select();
		
		TemplateArea = Template.GetArea("TableHeaderProduction");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("StringProducts");
		
		While StringSelectionProducts.Next() Do
			TemplateArea.Parameters.Fill(StringSelectionProducts);
			
			TemplateArea.Parameters.Products = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.Products,
											StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
			SpreadsheetDocument.Put(TemplateArea);
		EndDo;
		
		TemplateArea = Template.GetArea("TotalProducts");
		SpreadsheetDocument.Put(TemplateArea);
		
		// TS Inventory.
		StringSelectionProducts = Header.Inventory.Select();
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("String");
		
		While StringSelectionProducts.Next() Do
			TemplateArea.Parameters.Fill(StringSelectionProducts);
			
			TemplateArea.Parameters.Material = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.Material, 
											StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
			SpreadsheetDocument.Put(TemplateArea);
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		SpreadsheetDocument.Put(TemplateArea);
		
		// Signature.
		TemplateArea = Template.GetArea("Signatures");
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "RequestToWarehouse") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "RequestToWarehouse",
			NStr("en = 'Request to warehouse'"),
			PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand 							= PrintCommands.Add();
	PrintCommand.ID 						= "RequestToWarehouse";
	PrintCommand.Presentation 				= NStr("en = 'Request to warehouse'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint 	= False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf
