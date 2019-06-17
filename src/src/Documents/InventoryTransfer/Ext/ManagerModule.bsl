#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	TableInventory.OperationKind AS OperationKind,
	|	TableInventory.CurrencyPricesRecipient AS CurrencyPricesRecipient,
	|	TableInventory.ExpenseAccountType AS ExpenseAccountType,
	|	TableInventory.CorrActivityDirection AS CorrActivityDirection,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
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
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	TableInventory.CorrGLAccount AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	TableInventory.RetailTransfer AS RetailTransfer,
	|	TableInventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	TableInventory.ReturnFromRetailEarningAccounting AS ReturnFromRetailEarningAccounting,
	|	TableInventory.MarkupGLAccount AS MarkupGLAccount,
	|	TableInventory.FinancialAccountInRetailRecipient AS FinancialAccountInRetailRecipient,
	|	TableInventory.MarkupGLAccountRecipient AS MarkupGLAccountRecipient,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailEarningAccounting
	|				THEN -TableInventory.Quantity
	|			ELSE TableInventory.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailEarningAccounting
	|				THEN -TableInventory.Reserve
	|			ELSE TableInventory.Reserve
	|		END) AS Reserve,
	|	SUM(CASE
	|			WHEN NOT &FillAmount
	|				THEN 0
	|			WHEN TableInventory.ReturnFromRetailEarningAccounting
	|				THEN -TableInventory.Cost
	|			ELSE TableInventory.Amount
	|		END) AS Amount,
	|	FALSE AS FixedCost
	|INTO SourceTable
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.TransferInRetailEarningAccounting
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.OperationKind,
	|	TableInventory.CurrencyPricesRecipient,
	|	TableInventory.ExpenseAccountType,
	|	TableInventory.CorrActivityDirection,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.FinancialAccountInRetailRecipient,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.MarkupGLAccountRecipient,
	|	TableInventory.RetailTransferEarningAccounting,
	|	TableInventory.RetailTransfer,
	|	TableInventory.ReturnFromRetailEarningAccounting,
	|	TableInventory.MarkupGLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SourceTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SourceTable.Period AS Period,
	|	SourceTable.OperationKind AS OperationKind,
	|	SourceTable.CurrencyPricesRecipient AS CurrencyPricesRecipient,
	|	SourceTable.ExpenseAccountType AS ExpenseAccountType,
	|	SourceTable.CorrActivityDirection AS CorrActivityDirection,
	|	SourceTable.Company AS Company,
	|	SourceTable.PlanningPeriod AS PlanningPeriod,
	|	SourceTable.StructuralUnit AS StructuralUnit,
	|	SourceTable.StructuralUnitCorr AS StructuralUnitCorr,
	|	SourceTable.GLAccount AS GLAccount,
	|	SourceTable.CorrGLAccount AS CorrGLAccount,
	|	SourceTable.Products AS Products,
	|	SourceTable.ProductsCorr AS ProductsCorr,
	|	SourceTable.Characteristic AS Characteristic,
	|	SourceTable.CharacteristicCorr AS CharacteristicCorr,
	|	SourceTable.Batch AS Batch,
	|	SourceTable.BatchCorr AS BatchCorr,
	|	SourceTable.SalesOrder AS SalesOrder,
	|	SourceTable.CustomerCorrOrder AS CustomerCorrOrder,
	|	SourceTable.SourceDocument AS SourceDocument,
	|	SourceTable.CorrSalesOrder AS CorrSalesOrder,
	|	SourceTable.AccountDr AS AccountDr,
	|	SourceTable.AccountCr AS AccountCr,
	|	SourceTable.RetailTransfer AS RetailTransfer,
	|	SourceTable.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	SourceTable.ReturnFromRetailEarningAccounting AS ReturnFromRetailEarningAccounting,
	|	SourceTable.MarkupGLAccount AS MarkupGLAccount,
	|	SourceTable.FinancialAccountInRetailRecipient AS FinancialAccountInRetailRecipient,
	|	SourceTable.MarkupGLAccountRecipient AS MarkupGLAccountRecipient,
	|	SourceTable.Content AS Content,
	|	SourceTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SourceTable.Quantity AS Quantity,
	|	SourceTable.Reserve AS Reserve,
	|	SourceTable.Amount AS Amount,
	|	SourceTable.FixedCost AS FixedCost,
	|	FALSE AS OfflineRecord
	|FROM
	|	SourceTable AS SourceTable
	|
	|UNION ALL
	|
	|SELECT
	|	SourceTable.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	SourceTable.Period,
	|	SourceTable.OperationKind,
	|	SourceTable.CurrencyPricesRecipient,
	|	SourceTable.ExpenseAccountType,
	|	SourceTable.CorrActivityDirection,
	|	SourceTable.Company,
	|	SourceTable.PlanningPeriod,
	|	SourceTable.StructuralUnitCorr,
	|	SourceTable.StructuralUnit,
	|	SourceTable.CorrGLAccount,
	|	SourceTable.GLAccount,
	|	SourceTable.Products,
	|	SourceTable.ProductsCorr,
	|	SourceTable.Characteristic,
	|	SourceTable.CharacteristicCorr,
	|	SourceTable.Batch,
	|	SourceTable.BatchCorr,
	|	SourceTable.SalesOrder,
	|	SourceTable.CustomerCorrOrder,
	|	SourceTable.SourceDocument,
	|	SourceTable.CorrSalesOrder,
	|	SourceTable.AccountDr,
	|	SourceTable.AccountCr,
	|	SourceTable.RetailTransfer,
	|	SourceTable.RetailTransferEarningAccounting,
	|	SourceTable.ReturnFromRetailEarningAccounting,
	|	SourceTable.MarkupGLAccount,
	|	SourceTable.FinancialAccountInRetailRecipient,
	|	SourceTable.MarkupGLAccountRecipient,
	|	SourceTable.Content,
	|	SourceTable.ContentOfAccountingRecord,
	|	SourceTable.Quantity,
	|	SourceTable.Reserve,
	|	SourceTable.Amount,
	|	SourceTable.FixedCost,
	|	FALSE
	|FROM
	|	SourceTable AS SourceTable
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON SourceTable.StructuralUnit = BusinessUnits.Ref
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnitsCorr
	|		ON SourceTable.StructuralUnitCorr = BusinessUnitsCorr.Ref
	|WHERE
	|	NOT &FillAmount
	|	AND SourceTable.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|	AND BusinessUnitsCorr.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|	AND BusinessUnits.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.Company,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.CorrSalesOrder,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.RetailTransferEarningAccounting,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If FillAmount Then
		FillAmountInInventoryTable(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure FillAmountInInventoryTable(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
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
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|		AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|		AND TableInventory.SalesOrder <> UNDEFINED
	|		AND NOT TableInventory.TransferInRetailEarningAccounting
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		NOT TableInventory.TransferInRetailEarningAccounting) AS TableInventory
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
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|						AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|						AND TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
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
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
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
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
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
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	IsEmptyStructuralUnit = Catalogs.BusinessUnits.EmptyRef();
	EmptyAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyProducts = Catalogs.Products.EmptyRef();
	EmptyCharacteristic = Catalogs.ProductsCharacteristics.EmptyRef();
	EmptyBatch = Catalogs.ProductsBatches.EmptyRef();
    EmptySalesOrder = Undefined;

	RetailTransferEarningAccounting = False;
	ReturnFromRetailEarningAccounting = False;	
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		If RowTableInventory.ReturnFromRetailEarningAccounting Then
			ReturnFromRetailEarningAccounting = True;
			
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			TableRowExpense.StructuralUnit = TableRowExpense.StructuralUnitCorr;
			TableRowExpense.StructuralUnitCorr = Undefined;
			TableRowExpense.CorrGLAccount = Undefined;
			TableRowExpense.ProductsCorr = Undefined;
			TableRowExpense.CharacteristicCorr = Undefined;
			TableRowExpense.BatchCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = Undefined;
			TableRowExpense.FixedCost = True;

			RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
			RowTableAccountingJournalEntries.Amount = RowTableInventory.Amount;
			RowTableAccountingJournalEntries.AccountDr = RowTableInventory.GLAccount;
			
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

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
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses
				OR RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.OtherExpenses
			 	OR RowTableInventory.RetailTransferEarningAccounting Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsCorr = EmptyProducts;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				TableRowExpense.SourceDocument = DocumentRefInventoryTransfer;
				TableRowExpense.CorrSalesOrder = RowTableInventory.SalesOrder;
				
			Else
				
				If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
				   AND RowTableInventory.RetailTransfer Then
				   TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				ElsIf Not RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
				   	    AND Not RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				EndIf;
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
					TableRowExpense.ProductsCorr = EmptyProducts;
					TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
					TableRowExpense.BatchCorr = EmptyBatch;
				EndIf;
				
			EndIf;
			
			If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsCorr = EmptyProducts;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				TableRowExpense.FixedCost = True;
				
			EndIf;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				
				If RowTableInventory.RetailTransferEarningAccounting Then
					RowTableAccountingJournalEntries.AccountDr = RowTableInventory.FinancialAccountInRetailRecipient;
				EndIf;
				
			EndIf;
			
			If RowTableInventory.RetailTransferEarningAccounting Then
				
				StringTablePOSSummary = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary.Add();
				FillPropertyValues(StringTablePOSSummary, RowTableInventory);
				StringTablePOSSummary.Cost = AmountToBeWrittenOff;
				StringTablePOSSummary.RecordType = AccumulationRecordType.Receipt;
				StringTablePOSSummary.Currency = RowTableInventory.CurrencyPricesRecipient;
				StringTablePOSSummary.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				StringTablePOSSummary.Company = RowTableInventory.Company;
				StringTablePOSSummary.Amount = 0;
				StringTablePOSSummary.AmountCur = 0;
				
				RetailTransferEarningAccounting = True;
							
			ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredReserve > 0 Then // Receipt.
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses
					OR RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.OtherExpenses Then
					
					StringTablesTurnover = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(StringTablesTurnover, RowTableInventory);
					StringTablesTurnover.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					StringTablesTurnover.BusinessLine = RowTableInventory.CorrActivityDirection;
					StringTablesTurnover.SalesOrder = RowTableInventory.CustomerCorrOrder;
					StringTablesTurnover.AmountExpense = AmountToBeWrittenOff;
					StringTablesTurnover.GLAccount = RowTableInventory.CorrGLAccount;
					
				Else // These are costs.
					
					TableRowReceipt = TemporaryTableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.Company = RowTableInventory.Company;
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
					AND Not RowTableInventory.RetailTransfer Then
						TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					ElsIf RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
						TableRowReceipt.Products = EmptyProducts;
						TableRowReceipt.Characteristic = EmptyCharacteristic;
						TableRowReceipt.Batch = EmptyBatch;
					Else
						TableRowReceipt.SalesOrder = EmptySalesOrder;
					EndIf;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
					TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.Products;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventory.Batch;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation
					 OR RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
						TableRowReceipt.Quantity = 0;
					Else
						TableRowReceipt.Quantity = QuantityRequiredReserve;
					EndIf;
					
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
						
						TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
						TableRowReceipt.CorrGLAccount = EmptyAccount;
						TableRowReceipt.ProductsCorr = EmptyProducts;
						TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
						TableRowReceipt.BatchCorr = EmptyBatch;
						TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;
						TableRowReceipt.FixedCost = True;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("SalesOrder", EmptySalesOrder);
			
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
			TableRowExpense.SalesOrder = EmptySalesOrder;
			
			If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses
				OR RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.OtherExpenses
				 OR RowTableInventory.RetailTransferEarningAccounting Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsCorr = EmptyProducts;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				TableRowExpense.SourceDocument = DocumentRefInventoryTransfer;
				TableRowExpense.CorrSalesOrder = RowTableInventory.SalesOrder;
				
			Else
				If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
				   AND RowTableInventory.RetailTransfer Then
				   TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				ElsIf Not RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
				   	   AND Not RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				EndIf;
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
					TableRowExpense.ProductsCorr = EmptyProducts;
					TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
					TableRowExpense.BatchCorr = EmptyBatch;
				EndIf;
				
			EndIf;
			
			If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsCorr = EmptyProducts;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
				TableRowExpense.FixedCost = True;
				
			EndIf;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				
				If RowTableInventory.RetailTransferEarningAccounting Then
					RowTableAccountingJournalEntries.AccountDr = RowTableInventory.FinancialAccountInRetailRecipient;
				EndIf;
				
			EndIf;
			
			If RowTableInventory.RetailTransferEarningAccounting Then
				
				StringTablePOSSummary = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary.Add();
				FillPropertyValues(StringTablePOSSummary, RowTableInventory);
				StringTablePOSSummary.RecordType = AccumulationRecordType.Receipt;
				StringTablePOSSummary.Cost = AmountToBeWrittenOff;
				StringTablePOSSummary.Currency = RowTableInventory.CurrencyPricesRecipient;
				StringTablePOSSummary.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				StringTablePOSSummary.Amount = 0;
				StringTablePOSSummary.AmountCur = 0;
				
				RetailTransferEarningAccounting = True;
			
			ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredAvailableBalance > 0 Then // Receipt
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses
					OR RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.OtherExpenses Then
					
					StringTablesTurnover = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(StringTablesTurnover, RowTableInventory);
					StringTablesTurnover.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					StringTablesTurnover.BusinessLine = RowTableInventory.CorrActivityDirection;
					StringTablesTurnover.SalesOrder = RowTableInventory.CustomerCorrOrder;
					StringTablesTurnover.AmountIncome = AmountToBeWrittenOff;
					StringTablesTurnover.AmountExpense = AmountToBeWrittenOff;
					StringTablesTurnover.GLAccount = RowTableInventory.CorrGLAccount;
					
				Else // These are costs.
					
					TableRowReceipt = TemporaryTableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.Company = RowTableInventory.Company;
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
					AND Not RowTableInventory.RetailTransfer Then
						TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					ElsIf RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
						TableRowReceipt.Products = EmptyProducts;
						TableRowReceipt.Characteristic = EmptyCharacteristic;
						TableRowReceipt.Batch = EmptyBatch;
					Else
						TableRowReceipt.SalesOrder = EmptySalesOrder;
					EndIf;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
					TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.Products;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventory.Batch;
					TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation
					 OR RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
						TableRowReceipt.Quantity = 0;
					Else
						TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
					EndIf;
					
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
						
						TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
						TableRowReceipt.CorrGLAccount = EmptyAccount;
						TableRowReceipt.ProductsCorr = EmptyProducts;
						TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
						TableRowReceipt.BatchCorr = EmptyBatch;
						TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;
						TableRowReceipt.FixedCost = True;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// If it is a passing to operation, transfer at zero cost and classify
		// the cost itself as recipient-subdepartments costs.
		If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then

			// It should be added, then receipt is only by
			// quantity with an empty mail for the correct account in quantitative terms.
			TableRowReceipt = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);

			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;

			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;

			TableRowReceipt.SalesOrder = EmptySalesOrder;
			  	   
			TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
			TableRowReceipt.CorrGLAccount = EmptyAccount;
			TableRowReceipt.ProductsCorr = EmptyProducts;
			TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
			TableRowReceipt.BatchCorr = EmptyBatch;
			TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;

			TableRowReceipt.Amount = 0;
			TableRowReceipt.FixedCost = True;

		EndIf;
			
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
	// Retail markup (amount accounting).
	If RetailTransferEarningAccounting
	 OR ReturnFromRetailEarningAccounting Then
		
		SumCost = TemporaryTableInventory.Total("Amount");
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	SUM(ISNULL(TemporaryTablePOSSummary.Amount, 0)) AS Amount
		|FROM
		|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		If SelectionOfQueryResult.Next() Then
			SumInSalesPrices = SelectionOfQueryResult.Amount;
		Else
			SumInSalesPrices = 0;
		EndIf;
		
		AmountMarkup = SumInSalesPrices - SumCost;
		
		If AmountMarkup <> 0 Then
			
			If TemporaryTableInventory.Count() > 0 Then
				TableRow = TemporaryTableInventory[0];
			ElsIf StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary.Count() > 0 Then
				TableRow = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary[0];
			Else
				TableRow = Undefined;
			EndIf;
			
			If TableRow <> Undefined Then
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, TableRow);
				RowTableAccountingJournalEntries.AccountDr = ?(RetailTransferEarningAccounting, TableRow.FinancialAccountInRetailRecipient, TableRow.GLAccount);
				RowTableAccountingJournalEntries.AccountCr = ?(RetailTransferEarningAccounting, TableRow.MarkupGLAccountRecipient, TableRow.MarkupGLAccount);
				RowTableAccountingJournalEntries.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				RowTableAccountingJournalEntries.Content = NStr("en = 'Retail markup'");
				RowTableAccountingJournalEntries.Amount = AmountMarkup;
			EndIf;
			
		EndIf;
	
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.ReturnFromRetailEarningAccounting
	|	AND NOT TableInventory.TransferInRetailEarningAccounting
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.CorrCell,
	|	TableInventory.Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|	AND NOT TableInventory.RetailTransferEarningAccounting
	|	AND NOT TableInventory.TransferInRetailEarningAccounting";
    		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",							DocumentRefInventoryTransfer);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefInventoryTransfer);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailTransfer",		NStr("en = 'Move to retail'", MainLanguageCode));
	Query.SetParameter("RetailTransfer",		NStr("en = 'Movement in retail'", MainLanguageCode));
	Query.SetParameter("ReturnAndRetail",		NStr("en = 'Return from retail'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.RetailPriceKind AS RetailPriceKind,
	|	DocumentTable.Products AS Products,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.SalesOrder AS SalesOrder,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	DocumentTable.Amount AS AmountForBalance,
	|	DocumentTable.AmountCur AS AmountCurForBalance,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Date,
	|		VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|		DocumentTable.LineNumber AS LineNumber,
	|		DocumentTable.Company AS Company,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.RetailPriceKind
	|			ELSE DocumentTable.RetailPriceKindRecipient
	|		END AS RetailPriceKind,
	|		DocumentTable.Products AS Products,
	|		DocumentTable.Characteristic AS Characteristic,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.StructuralUnit
	|			ELSE DocumentTable.StructuralUnitCorr
	|		END AS StructuralUnit,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.PriceCurrency
	|			ELSE DocumentTable.CurrencyPricesRecipient
	|		END AS Currency,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.GLAccount
	|			ELSE DocumentTable.FinancialAccountInRetailRecipient
	|		END AS GLAccount,
	|		DocumentTable.SalesOrder AS SalesOrder,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity) / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS Amount,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS AmountCur,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity) / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS SumForBalance,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS AmountCurForBalance,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -DocumentTable.Cost
	|			ELSE 0
	|		END AS Cost,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN &ReturnAndRetail
	|			ELSE &RetailTransfer
	|		END AS ContentOfAccountingRecord
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKindRecipient,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesRecipientSliceLast
	|			ON DocumentTable.Products = PricesRecipientSliceLast.Products
	|				AND DocumentTable.RetailPriceKindRecipient = PricesRecipientSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesRecipientSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesSliceLast
	|			ON DocumentTable.Products = PricesSliceLast.Products
	|				AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.PresentationCurrency
	|						FROM
	|							Constants AS Constants)) AS ManagExchangeRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|			ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|	WHERE
	|		(DocumentTable.RetailTransferEarningAccounting
	|				OR DocumentTable.ReturnFromRetailEarningAccounting)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Period,
	|		VALUE(AccumulationRecordType.Expense),
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKind,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.PriceCurrency,
	|		DocumentTable.GLAccount,
	|		DocumentTable.SalesOrder,
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		-SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		-SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		DocumentTable.Cost,
	|		&RetailTransfer
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesSliceLast
	|			ON DocumentTable.Products = PricesSliceLast.Products
	|				AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.PresentationCurrency
	|						FROM
	|							Constants AS Constants)) AS ManagExchangeRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|	WHERE
	|		DocumentTable.TransferInRetailEarningAccounting
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKind,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.PriceCurrency,
	|		DocumentTable.GLAccount,
	|		DocumentTable.SalesOrder,
	|		DocumentTable.Cost
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Period,
	|		VALUE(AccumulationRecordType.Receipt),
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKindRecipient,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnitCorr,
	|		DocumentTable.CurrencyPricesRecipient,
	|		DocumentTable.FinancialAccountInRetailRecipient,
	|		DocumentTable.SalesOrder,
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity / (CurrencyPriceExchangeRateRecipient.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity / (CurrencyPriceExchangeRateRecipient.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		DocumentTable.Cost,
	|		&RetailTransfer
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesSliceLast
	|			ON DocumentTable.Products = PricesSliceLast.Products
	|				AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.PresentationCurrency
	|						FROM
	|							Constants AS Constants)) AS ManagExchangeRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|			ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|	WHERE
	|		DocumentTable.TransferInRetailEarningAccounting
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKindRecipient,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnitCorr,
	|		DocumentTable.CurrencyPricesRecipient,
	|		DocumentTable.FinancialAccountInRetailRecipient,
	|		DocumentTable.SalesOrder,
	|		DocumentTable.Cost) AS DocumentTable
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block 				= New DataLock;
	LockItem 			= Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPOSSummary(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("MoveToRIMContent",				NStr("en = 'Retail markup'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",							DocumentRefInventoryTransfer);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.FinancialAccountInRetailRecipient,
	|	DocumentTable.MarkupGLAccountRecipient,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity) / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|	&MoveToRIMContent,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&PointInTime,
	|				(PriceKind, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.RetailPriceKindRecipient,
	|						TemporaryTableInventory.Products,
	|						TemporaryTableInventory.Characteristic
	|					FROM
	|						TemporaryTableInventory)) AS PricesRecipientSliceLast
	|		ON DocumentTable.Products = PricesRecipientSliceLast.Products
	|			AND DocumentTable.RetailPriceKindRecipient = PricesRecipientSliceLast.PriceKind
	|			AND DocumentTable.Characteristic = PricesRecipientSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|		ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|		ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|WHERE
	|	DocumentTable.RetailTransferEarningAccounting
	|	AND NOT &FillAmount
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.FinancialAccountInRetailRecipient,
	|	DocumentTable.MarkupGLAccountRecipient
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.MarkupGLAccount,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate) / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|	&MoveToRIMContent,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&PointInTime,
	|				(PriceKind, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.RetailPriceKind,
	|						TemporaryTableInventory.Products,
	|						TemporaryTableInventory.Characteristic
	|					FROM
	|						TemporaryTableInventory)) AS PricesRecipientSliceLast
	|		ON DocumentTable.Products = PricesRecipientSliceLast.Products
	|			AND DocumentTable.RetailPriceKind = PricesRecipientSliceLast.PriceKind
	|			AND DocumentTable.Characteristic = PricesRecipientSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|		ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|WHERE
	|	DocumentTable.ReturnFromRetailEarningAccounting
	|	AND NOT &FillAmount
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.MarkupGLAccount,
	|	DocumentTable.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryTransfer, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryTransferInventory.LineNumber AS LineNumber,
	|	InventoryTransferInventory.ConnectionKey AS ConnectionKey,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryTransferInventory.Ref.Date AS Period,
	|	InventoryTransferInventory.Ref.OperationKind AS OperationKind,
	|	InventoryTransferInventory.Products.ProductsType AS ProductsType,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransferEarningAccounting,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.Retail)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransfer,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ReturnFromRetailEarningAccounting,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS TransferInRetailEarningAccounting,
	|	InventoryTransferInventory.Ref.StructuralUnit.MarkupGLAccount AS MarkupGLAccount,
	|	InventoryTransferInventory.Ref.StructuralUnit.RetailPriceKind AS RetailPriceKind,
	|	InventoryTransferInventory.Ref.StructuralUnit.RetailPriceKind.PriceCurrency AS PriceCurrency,
	|	InventoryTransferInventory.InventoryGLAccount AS FinancialAccountInRetailRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.MarkupGLAccount AS MarkupGLAccountRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.RetailPriceKind AS RetailPriceKindRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.RetailPriceKind.PriceCurrency AS CurrencyPricesRecipient,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|					AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount.TypeOfAccount
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN InventoryTransferInventory.InventoryToGLAccount.TypeOfAccount
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount.TypeOfAccount
	|	END AS ExpenseAccountType,
	|	InventoryTransferInventory.BusinessLine AS CorrActivityDirection,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	InventoryTransferInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee AS StructuralUnitCorr,
	|	InventoryTransferInventory.Ref.Cell AS Cell,
	|	InventoryTransferInventory.Ref.CellPayee AS CorrCell,
	|	CASE
	|		WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|		ELSE CASE
	|				WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|					THEN InventoryTransferInventory.InventoryGLAccount
	|				ELSE CASE
	|						WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|								OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|								OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|							THEN InventoryTransferInventory.InventoryGLAccount
	|						ELSE InventoryTransferInventory.ConsumptionGLAccount
	|					END
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|			THEN CASE
	|					WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|						THEN InventoryTransferInventory.ConsumptionGLAccount
	|					ELSE CASE
	|							WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|										AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|										AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|										AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryToGLAccount
	|							WHEN InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryToGLAccount
	|							ELSE InventoryTransferInventory.ConsumptionGLAccount
	|						END
	|				END
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|						THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|					ELSE CASE
	|							WHEN InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryGLAccount
	|							ELSE InventoryTransferInventory.ConsumptionGLAccount
	|						END
	|				END
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount
	|	END AS CorrGLAccount,
	|	InventoryTransferInventory.Products AS Products,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN InventoryTransferInventory.Products
	|		ELSE VALUE(Catalog.Products.EmptyRef)
	|	END AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryTransferInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN &UseCharacteristics
	|						THEN InventoryTransferInventory.Characteristic
	|					ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				END
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryTransferInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN &UseBatches
	|						THEN InventoryTransferInventory.Batch
	|					ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|				END
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryTransferInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryTransferInventory.Quantity
	|		ELSE InventoryTransferInventory.Quantity * InventoryTransferInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|			THEN CASE
	|					WHEN VALUETYPE(InventoryTransferInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|						THEN InventoryTransferInventory.Reserve
	|					ELSE InventoryTransferInventory.Reserve * InventoryTransferInventory.MeasurementUnit.Factor
	|				END
	|		ELSE 0
	|	END AS Reserve,
	|	0 AS Amount,
	|	InventoryTransferInventory.Amount AS Cost,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|						THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|					ELSE CASE
	|							WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|										AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|										AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|										AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryToGLAccount
	|							WHEN InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryToGLAccount
	|							ELSE InventoryTransferInventory.ConsumptionGLAccount
	|						END
	|				END
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|		ELSE CASE
	|				WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|					THEN InventoryTransferInventory.InventoryGLAccount
	|				ELSE CASE
	|						WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|								OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|								OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|							THEN InventoryTransferInventory.InventoryGLAccount
	|						ELSE InventoryTransferInventory.ConsumptionGLAccount
	|					END
	|			END
	|	END AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	InventoryTransferInventory.Amount AS AmountReturnCur
	|INTO TemporaryTableInventory
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|WHERE
	|	InventoryTransferInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransferSerialNumbers.ConnectionKey AS ConnectionKey,
	|	InventoryTransferSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.InventoryTransfer.SerialNumbers AS InventoryTransferSerialNumbers
	|WHERE
	|	InventoryTransferSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", 					DocumentRefInventoryTransfer);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseStorageBins", 	StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseBatches", 			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'", MainLanguageCode));
	
	ResultsArray = Query.Execute();

	// Creation of document postings.
	GenerateTableInventoryInWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTablePOSSummary(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefInventoryTransfer, StructureAdditionalProperties);
		
	// Calculation of the inventory write-off cost.
	GenerateTableInventory(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
		"SELECT
		|	TemporaryTableInventory.Period AS Period,
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	TemporaryTableInventory.Products AS Products,
		|	TemporaryTableInventory.Characteristic AS Characteristic,
		|	TemporaryTableInventory.Batch AS Batch,
		|	TemporaryTableInventory.Company AS Company,
		|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
		|	TemporaryTableInventory.Cell AS Cell,
		|	TemporaryTableInventory.OperationKind AS OperationKind,
		|	1 AS Quantity
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableInventory.Period,
		|	VALUE(AccumulationRecordType.Receipt),
		|	SerialNumbers.SerialNumber,
		|	TemporaryTableInventory.Products,
		|	TemporaryTableInventory.Characteristic,
		|	TemporaryTableInventory.Batch,
		|	TemporaryTableInventory.Company,
		|	TemporaryTableInventory.StructuralUnitCorr,
		|	TemporaryTableInventory.CorrCell,
		|	TemporaryTableInventory.OperationKind,
		|	1
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
		|WHERE
		|	NOT TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableInventory.Period AS EventDate,
		|	CASE
		|		WHEN TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
		|			THEN VALUE(Enum.SerialNumbersOperations.Expense)
		|		ELSE VALUE(Enum.SerialNumbersOperations.Record)
		|	END AS Operation,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	TemporaryTableInventory.Products AS Products,
		|	TemporaryTableInventory.Characteristic AS Characteristic
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultsArray[1].Unload());
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", ResultsArray[0].Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryTransfer, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange",
	// "RegisterRecordsInventoryChange" temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsPOSSummaryUpdate
	 OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Cell) IN
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
		|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
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
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPOSSummaryUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryUpdate.Company AS CompanyPresentation,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryUpdate.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryUpdate.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryUpdate AS RegisterRecordsPOSSummaryUpdate
		|		INNER JOIN AccumulationRegister.POSSummary.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit) IN
		|					(SELECT
		|						RegisterRecordsPOSSummaryUpdate.Company AS Company,
		|						RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnit
		|					FROM
		|						RegisterRecordsPOSSummaryUpdate AS RegisterRecordsPOSSummaryUpdate)) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryUpdate.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryUpdate.StructuralUnit = POSSummaryBalances.StructuralUnit
		|			AND (ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();

		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectInventoryTransfer = DocumentRefInventoryTransfer.GetObject()
		EndIf;

		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Function checks if the document is
// posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_InventoryTransfer";

	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		If TemplateName = "MerchandiseFillingFormSender" Then
			
			Query.Text = 
			"SELECT
			|	InventoryTransfer.Date AS DocumentDate,
			|	InventoryTransfer.StructuralUnit AS WarehousePresentation,
			|	InventoryTransfer.Cell AS CellPresentation,
			|	InventoryTransfer.Number,
			|	InventoryTransfer.Company.Prefix AS Prefix,
			|	InventoryTransfer.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryTransfer.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN InventoryTransfer.Inventory.Products.Description
			|			ELSE InventoryTransfer.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	InventoryTransfer.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS InventoryTransfer
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryTransfer.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Inventory transfer #%1 dated %2'"),
			  	DocumentNumber,
			  	Format(Header.DocumentDate, "DLF=DD"));
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Date and time of printing: %1. User: %2.'"),
			  	CurrentDate(),
		  		Users.CurrentUser());
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf TemplateName = "MerchandiseFillingFormRecipient" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT
			|	InventoryTransfer.Date AS DocumentDate,
			|	InventoryTransfer.StructuralUnitPayee AS WarehousePresentation,
			|	InventoryTransfer.CellPayee AS CellPresentation,
			|	InventoryTransfer.Number,
			|	InventoryTransfer.Company.Prefix AS Prefix,
			|	InventoryTransfer.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryTransfer.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN InventoryTransfer.Inventory.Products.Description
			|			ELSE InventoryTransfer.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	InventoryTransfer.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS InventoryTransfer
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryTransfer.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Inventory transfer #%1 dated %2.'"),
				DocumentNumber,
			  	Format(Header.DocumentDate, "DLF=DD"));
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Date and time of printing: %1. User: %2.'"),
			  	CurrentDate(),
			  	Users.CurrentUser());
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingFormSender") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingFormSender", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingFormSender"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingFormRecipient") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingFormRecipient", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingFormRecipient"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingFormSender";
	PrintCommand.Presentation = NStr("en = 'Goods content form (Sender)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 23;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingFormRecipient";
	PrintCommand.Presentation = NStr("en = 'Goods content form (Recipient)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 26;
	
	If AccessRight("view", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromGoodsMovement";
		PrintCommand.Presentation = NStr("en = 'Print labels'");
		PrintCommand.FormsList = "DocumentForm,ListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 29;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromGoodsMovement";
		PrintCommand.Presentation = NStr("en = 'Print price tags'");
		PrintCommand.FormsList = "DocumentForm,ListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 32;
		
	EndIf;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 33;
	
EndProcedure

#EndRegion

#Region Public 

#Region InfoBaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "InventoryTransfer";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryToGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "ConsumptionGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Ref.GLExpenseAccount";
	GLAccountFields.Receiver = "SignedOutEquipmentGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryReceivedGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Ref.BusinessLine";
	GLAccountFields.Receiver = "BusinessLine";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf