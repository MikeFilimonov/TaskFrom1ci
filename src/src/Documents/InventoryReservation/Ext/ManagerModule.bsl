#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackorders(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.StructuralUnit AS SupplySource
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SalesOrder)
	|			AND TableInventory.StructuralUnit <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.StructuralUnit";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.StructuralUnit AS SupplySource,
	|	CASE
	|		WHEN TableInventory.Quantity > ISNULL(BackordersBalances.QuantityBalance, 0)
	|			THEN ISNULL(BackordersBalances.QuantityBalance, 0)
	|		WHEN TableInventory.Quantity <= ISNULL(BackordersBalances.QuantityBalance, 0)
	|			THEN TableInventory.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS QuantityBalance
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				SUM(BackordersBalances.QuantityBalance) AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						&ControlTime,
	|						(Company, SalesOrder, Products, Characteristic, SupplySource) IN
	|							(SELECT
	|								TableInventory.Company AS Company,
	|								TableInventory.SalesOrder AS SalesOrder,
	|								TableInventory.Products AS Products,
	|								TableInventory.Characteristic AS Characteristic,
	|								TableInventory.StructuralUnit AS SupplySource
	|							FROM
	|								TemporaryTableInventorySource AS TableInventory
	|							WHERE
	|								VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SalesOrder)
	|								AND TableInventory.StructuralUnit <> VALUE(Document.SalesOrder.EmptyRef))) AS BackordersBalances
	|			
	|			GROUP BY
	|				BackordersBalances.Company,
	|				BackordersBalances.SalesOrder,
	|				BackordersBalances.Products,
	|				BackordersBalances.Characteristic,
	|				BackordersBalances.SupplySource
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod
	|				AND DocumentRegisterRecordsBackorders.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)) AS BackordersBalances
	|		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableInventory.Company = BackordersBalances.Company
	|			AND TableInventory.Products = BackordersBalances.Products
	|			AND TableInventory.Characteristic = BackordersBalances.Characteristic
	|			AND TableInventory.StructuralUnit = BackordersBalances.SupplySource
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SalesOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.SalesOrder.EmptyRef)";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySource(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
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
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
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
	|	InventoryBalances.SalesOrder AS SalesOrder,
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
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						CASE
	|							WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|									OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|								THEN UNDEFINED
	|							ELSE TableInventory.SalesOrder
	|						END AS SalesOrder
	|					FROM
	|						TemporaryTableInventorySource AS TableInventory
	|					WHERE
	|						VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|						AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
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
	|		DocumentRegisterRecordsInventory.SalesOrder,
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
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventorySource.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventorySource[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
		
		QuantityWanted = RowTableInventory.Quantity;
			
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityWanted Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
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
			TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
					
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityWanted;
				
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
					
		EndIf;
		
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryRecipient(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
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
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.BusinessUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
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
	|	InventoryBalances.SalesOrder AS SalesOrder,
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
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						CASE
	|							WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|									OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|								THEN UNDEFINED
	|							ELSE TableInventory.SalesOrder
	|						END AS SalesOrder
	|					FROM
	|						TemporaryTableInventoryRecipient AS TableInventory
	|					WHERE
	|						VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|						AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
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
	|		DocumentRegisterRecordsInventory.SalesOrder,
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
	|		AND DocumentRegisterRecordsInventory.SalesOrder = UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryRecipient.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryRecipient[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
		
		QuantityWanted = RowTableInventory.Quantity;
			
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityWanted Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
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
			TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
					
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityWanted;
				
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
					
		EndIf;
		
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryReservation, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryReservationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReservationInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReservationInventory.OriginalReservePlace AS StructuralUnit,
	|	InventoryReservationInventory.InventoryGLAccount AS GLAccount,
	|	InventoryReservationInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReservationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReservationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryReservationInventory.Ref.SalesOrder AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryReservationInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryReservationInventory.Quantity
	|		ELSE InventoryReservationInventory.Quantity * InventoryReservationInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventorySource
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
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
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
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
	|	TableInventory.RecordKindAccountingJournalEntries,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReservationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReservationInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReservationInventory.NewReservePlace AS StructuralUnit,
	|	InventoryReservationInventory.InventoryGLAccount AS GLAccount,
	|	InventoryReservationInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReservationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReservationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	InventoryReservationInventory.Ref.SalesOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryReservationInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryReservationInventory.Quantity
	|		ELSE InventoryReservationInventory.Quantity * InventoryReservationInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventoryRecipient
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
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
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
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
	|	TableInventory.RecordKindAccountingJournalEntries,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS SupplySource,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CustomerCorrOrder AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SalesOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.CustomerCorrOrder";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", NStr("en = 'Inventory reservation'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventorySource", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryRecipient", ResultsArray[3].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventorySource.CopyColumns());
	
	// Inventory reservation.
	GenerateTableInventorySource(DocumentRefInventoryReservation, StructureAdditionalProperties);
	GenerateTableInventoryRecipient(DocumentRefInventoryReservation, StructureAdditionalProperties);
	
	// Placement of the orders.
	GenerateTableBackorders(DocumentRefInventoryReservation, StructureAdditionalProperties);
	
	// Complete the table of orders placement.
	ResultsSelection = ResultsArray[4].Select();
	While ResultsSelection.Next() Do
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Add();
		FillPropertyValues(TableRowReceipt, ResultsSelection);
	EndDo;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryReservation, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables
	// "RegisterRecordsBackordersChange", "RegisterRecordsInventoryChange" contain records, it is required to execute the
	// inventory control.
	
	If StructureTemporaryTables.RegisterRecordsBackordersChange
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
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectInventoryReservation = DocumentRefInventoryReservation.GetObject()
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryReservation, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on inventory placement.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectInventoryReservation, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	InventoryReservation.Ref AS Ref
	|FROM
	|	Document.InventoryReservation AS InventoryReservation
	|WHERE
	|	InventoryReservation.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Try
			
			InventoryReservationObject = Selection.Ref.GetObject();
			InventoryReservationObject.SalesOrder = Undefined;
			InventoryReservationObject.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.InventoryReservation,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillNewGLAccounts() Export
	
	DocumentName = "InventoryReservation";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf