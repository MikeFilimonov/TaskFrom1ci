#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SourceDocument,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.ProductsOnCommission AS ProductsOnCommission,
	|	UNDEFINED AS CorrSalesOrder,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.CorrespondentAccountAccountingInventory AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsType AS ProductsType,
	|	TableInventory.BusinessLine AS BusinessLine,
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
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS CustomerCorrOrder,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(CASE
	|			WHEN &FillAmount
	|				THEN TableInventory.VATAmount
	|			ELSE 0
	|		END) AS VATAmount,
	|	SUM(CASE
	|			WHEN &FillAmount
	|				THEN TableInventory.Amount
	|			ELSE 0
	|		END) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCostOfSales AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS Content,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Date,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	TableInventory.Department,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.BusinessUnits.EmptyRef)),
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.BusinessUnits.EmptyRef)),
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.CorrespondentAccountAccountingInventory,
	|	TableInventory.Products,
	|	TableInventory.ProductsType,
	|	TableInventory.BusinessLine,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.VATRate,
	|	TableInventory.GLAccountCostOfSales,
	|	TableInventory.ProductsOnCommission,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.SalesOrder,
	|	TableInventory.InventoryGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	UNDEFINED,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Products,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	0,
	|	OfflineRecords.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryIncrease", NStr("en = 'Inventory receipt'", MainLanguageCode));
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'", MainLanguageCode));
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If FillAmount Then
		GenerateTableInventorySale(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySale(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT DISTINCT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryGLAccount AS GLAccount,
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
	|	TemporaryTableInventory AS TableInventory";
	
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
	|		UNDEFINED AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.InventoryGLAccount,
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
	
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	For Ct = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[Ct];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("SalesOrder", Undefined);
			
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
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			
			If RowTableInventory.ProductsOnCommission Then
				
				TableRowExpense.ContentOfAccountingRecord = Undefined;
				
			ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.Department;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.AccountDr;
				
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Record expenses'", MainLanguageCode);
				
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.SalesOrder AS SalesOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.AmountVATPurchaseSale) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.AmountVATPurchaseSale) AS Amount,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CompletePosting
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Document,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Cost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Date AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND &CompletePosting
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Date,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockReceivedFromThirdParties(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableStockReceivedFromThirdParties.Date AS Period,
	|	TableStockReceivedFromThirdParties.Company AS Company,
	|	TableStockReceivedFromThirdParties.Products AS Products,
	|	TableStockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	TableStockReceivedFromThirdParties.Batch AS Batch,
	|	UNDEFINED AS Counterparty,
	|	UNDEFINED AS Contract,
	|	UNDEFINED AS Order,
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity,
	|	CAST(&InventoryIncreaseProductsOnCommission AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TableStockReceivedFromThirdParties.ProductsOnCommission
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Date,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryIncreaseProductsOnCommission", NStr("en = 'Commission goods sales'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Date AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales AS GLAccount,
	|	CAST(&IncomeReflection AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	NOT TableIncomeAndExpenses.ProductsOnCommission
	|	AND &CompletePosting
	|	AND TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|WHERE
	|	&CompletePosting
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Income accrued'", MainLanguageCode));
	Query.SetParameter("CompletePosting",								StructureAdditionalProperties.ForPosting.CompletePosting);
	Query.SetParameter("Ref",											DocumentRefReportOnRetailSales);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Amount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentData.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentData.Company AS Company,
	|	DocumentData.CashCR AS CashCR,
	|	DocumentData.CashCRGLAccount AS GLAccount,
	|	DocumentData.DocumentCurrency AS Currency,
	|	SUM(DocumentData.Amount) AS Amount,
	|	SUM(DocumentData.AmountCur) AS AmountCur,
	|	SUM(DocumentData.Amount) AS AmountForBalance,
	|	SUM(DocumentData.AmountCur) AS AmountCurForBalance,
	|	CAST(&CashFundsReceipt AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableInventory AS DocumentData
	|WHERE
	|	&CompletePosting
	|	AND DocumentData.Amount <> 0
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentData.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency,
	|	SUM(DocumentData.Amount),
	|	SUM(DocumentData.AmountCur),
	|	-SUM(DocumentData.Amount),
	|	-SUM(DocumentData.AmountCur),
	|	CAST(&PaymentWithPaymentCards AS String(100))
	|FROM
	|	TemporaryTablePaymentCards AS DocumentData
	|WHERE
	|	&CompletePosting
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|INDEX BY
	|	Company,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	Query.SetParameter("CashFundsReceipt", NStr("en = 'Cash receipt to cash register'", MainLanguageCode));
	Query.SetParameter("PaymentWithPaymentCards", NStr("en = 'Payment with payment cards'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssetsInRetailCashes.Company AS Company,
	|	TemporaryTableCashAssetsInRetailCashes.CashCR AS CashCR
	|FROM
	|	TemporaryTableCashAssetsInRetailCashes AS TemporaryTableCashAssetsInRetailCashes";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashInCashRegisters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashInCashRegisters(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashInCashRegisters", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableAccountingJournalEntries.Date AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.CashCRGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &AccountsPayable
	|		ELSE TableAccountingJournalEntries.GLAccountRevenueFromSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&CompletePosting
	|	AND TableAccountingJournalEntries.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.POSTerminalGlAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.POSTerminalGlAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.POSTerminalGlAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount,
	|	&ReflectionOfPaymentByCards,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentCards AS TableAccountingJournalEntries
	|WHERE
	|	&CompletePosting
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS TableAccountingJournalEntries
	|WHERE
	|	&CompletePosting
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&CompletePosting
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
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
	|	Order";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("AccountsPayable",								Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("ReflectionOfPaymentByCards",					NStr("en = 'Payment with payment cards'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							Constants.PresentationCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("CompletePosting",								StructureAdditionalProperties.ForPosting.CompletePosting);
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefReportOnRetailSales);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Document AS ShipmentDocument,
	|	TemporaryTableInventory.Date AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	VALUE(Catalog.Counterparties.RetailCustomer) AS Customer,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	VALUE(Enum.VATOperationTypes.Sales) AS OperationType,
	|	TemporaryTableInventory.ProductsType AS ProductType,
	|	SUM(TemporaryTableInventory.VATAmountCur) * CASE
	|		WHEN TemporaryTableInventory.DocumentCurrency = TemporaryTableInventory.NationalCurrency
	|			THEN 1
	|		ELSE DocExchangeRates.ExchangeRate / DocExchangeRates.Multiplicity
	|	END AS VATAmount,
	|	SUM(TemporaryTableInventory.AmountCur - TemporaryTableInventory.VATAmountCur) * CASE
	|		WHEN TemporaryTableInventory.DocumentCurrency = TemporaryTableInventory.NationalCurrency
	|			THEN 1
	|		ELSE DocExchangeRates.ExchangeRate / DocExchangeRates.Multiplicity
	|	END AS AmountExcludesVAT
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DocExchangeRates
	|		ON TemporaryTableInventory.DocumentCurrency = DocExchangeRates.Currency
	|WHERE
	|	NOT TemporaryTableInventory.VATRate.NotTaxable
	|
	|GROUP BY
	|	TemporaryTableInventory.VATRate,
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.DocumentCurrency,
	|	TemporaryTableInventory.NationalCurrency,
	|	DocExchangeRates.Multiplicity,
	|	DocExchangeRates.ExchangeRate,
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.Date,
	|	TemporaryTableInventory.Company";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndProcedure

#Region DiscountCards

// Generates values table containing data for posting on the SalesByDiscountCard register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.DiscountCard AS DiscountCard,
	|	TableSales.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CompletePosting
	|	AND TableSales.DiscountCard <> VALUE(Catalog.DiscountCards.EmptyRef)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.DiscountCard,
	|	TableSales.CardOwner";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	If DocumentRefReportOnRetailSales.DiscountsMarkups.Count() = 0 OR Not GetFunctionalOption("UseAutomaticDiscounts") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableAutoDiscountsMarkups.Products,
	|	TemporaryTableAutoDiscountsMarkups.Characteristic,
	|	TemporaryTableAutoDiscountsMarkups.Document AS DocumentDiscounts,
	|	TemporaryTableAutoDiscountsMarkups.StructuralUnit AS RecipientDiscounts
	|FROM
	|	TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|WHERE
	|	&CompletePosting";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefReportOnRetailSales, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &NationalCurrency, &DocumentCurrency)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RetailSalesReportInventory.LineNumber AS LineNumber,
	|	RetailSalesReportInventory.ConnectionKey AS ConnectionKey,
	|	RetailSalesReportInventory.Ref AS Document,
	|	RetailSalesReportInventory.Ref.Stocktaking AS BasisDocument,
	|	RetailSalesReportInventory.Ref.Item AS Item,
	|	RetailSalesReportInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	RetailSalesReportInventory.Ref.Date AS Date,
	|	RetailSalesReportInventory.Ref.CashCR AS CashCR,
	|	RetailSalesReportInventory.Ref.CashCR.Owner AS CashCROwner,
	|	RetailSalesReportInventory.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	&Company AS Company,
	|	UNDEFINED AS SalesOrder,
	|	RetailSalesReportInventory.Ref.Department AS Department,
	|	RetailSalesReportInventory.Responsible AS Responsible,
	|	RetailSalesReportInventory.Products.ProductsType AS ProductsType,
	|	RetailSalesReportInventory.Products.BusinessLine AS BusinessLine,
	|	RetailSalesReportInventory.RevenueGLAccount AS GLAccountRevenueFromSales,
	|	RetailSalesReportInventory.COGSGLAccount AS GLAccountCostOfSales,
	|	RetailSalesReportInventory.Ref.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	UNDEFINED AS Cell,
	|	RetailSalesReportInventory.InventoryGLAccount AS InventoryGLAccount,
	|	UNDEFINED AS CorrespondentAccountAccountingInventory,
	|	CASE
	|		WHEN &UseBatches
	|				AND RetailSalesReportInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	RetailSalesReportInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN RetailSalesReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN RetailSalesReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN RetailSalesReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN RetailSalesReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	CASE
	|		WHEN VALUETYPE(RetailSalesReportInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN RetailSalesReportInventory.Quantity
	|		ELSE RetailSalesReportInventory.Quantity * RetailSalesReportInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	RetailSalesReportInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN RetailSalesReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE RetailSalesReportInventory.VATAmount * DocCurrencyExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocCurrencyExchangeRates.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(RetailSalesReportInventory.VATAmount * DocCurrencyExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocCurrencyExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(RetailSalesReportInventory.Total * DocCurrencyExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocCurrencyExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST(RetailSalesReportInventory.VATAmount AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(RetailSalesReportInventory.Total AS NUMBER(15, 2)) AS AmountCur,
	|	RetailSalesReportInventory.Total AS SettlementsAmountTakenPassed,
	|	RetailSalesReportInventory.DiscountCard AS DiscountCard,
	|	RetailSalesReportInventory.DiscountCard.CardOwner AS CardOwner,
	|	&PresentationCurrency AS PresentationCurrency,
	|	&NationalCurrency AS NationalCurrency,
	|	RetailSalesReportInventory.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	Document.ShiftClosure.Inventory AS RetailSalesReportInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DocCurrencyExchangeRates
	|		ON (DocCurrencyExchangeRates.Currency = &DocumentCurrency)
	|WHERE
	|	RetailSalesReportInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabularSection.LineNumber AS LineNumber,
	|	TabularSection.Ref.Date AS Date,
	|	&Ref AS Document,
	|	&Company AS Company,
	|	TabularSection.Ref.CashCR AS CashCR,
	|	TabularSection.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	TabularSection.POSTerminal.GLAccount AS POSTerminalGlAccount,
	|	TabularSection.Ref.DocumentCurrency AS DocumentCurrency,
	|	CAST(TabularSection.Amount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	TabularSection.Amount AS AmountCur
	|INTO TemporaryTablePaymentCards
	|FROM
	|	Document.ShiftClosure.PaymentWithPaymentCards AS TabularSection
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRatesSliceLast
	|		ON (AccountingExchangeRatesSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &DocumentCurrency)
	|WHERE
	|	TabularSection.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RetailSalesReportDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(CASE
	|			WHEN RetailSalesReportDiscountsMarkups.Ref.DocumentCurrency = &NationalCurrency
	|				THEN RetailSalesReportDiscountsMarkups.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE RetailSalesReportDiscountsMarkups.Amount * ManagExchangeRates.Multiplicity / ManagExchangeRates.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	RetailSalesReportDiscountsMarkups.Ref.Date AS Period,
	|	RetailSalesReportDiscountsMarkups.Products AS Products,
	|	RetailSalesReportDiscountsMarkups.Characteristic AS Characteristic,
	|	RetailSalesReportDiscountsMarkups.Ref AS Document,
	|	RetailSalesReportDiscountsMarkups.Ref.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.ShiftClosure.DiscountsMarkups AS RetailSalesReportDiscountsMarkups
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &NationalCurrency)
	|WHERE
	|	RetailSalesReportDiscountsMarkups.Ref = &Ref
	|	AND RetailSalesReportDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ShiftClosureSerialNumbers.ConnectionKey AS ConnectionKey,
	|	ShiftClosureSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.ShiftClosure.SerialNumbers AS ShiftClosureSerialNumbers
	|WHERE
	|	ShiftClosureSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("NationalCurrency", Constants.FunctionalCurrency.Get());
	Query.SetParameter("DocumentCurrency", CommonUse.ObjectAttributeValue(DocumentRefReportOnRetailSales, "DocumentCurrency"));
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	GenerateTableVATOutput(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	&CompletePosting";	
		
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReportOnRetailSales, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
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
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS CompanyPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS ProductsPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS BatchPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Contract AS ContractPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS OrderPresentation,
		|	StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		INNER JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Counterparty, Contract, Order) IN
		|					(SELECT
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS Counterparty,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Contract AS Contract,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS Order
		|					FROM
		|						RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange)) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty = StockReceivedFromThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Contract = StockReceivedFromThirdPartiesBalances.Contract
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|			AND (ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0)
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
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty() Then
			DocumentShiftClosure = DocumentRefReportOnRetailSales.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentShiftClosure, QueryResultSelection, Cancel);
		EndIf;

		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentShiftClosure, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentShiftClosure, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentShiftClosure, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////
// SHIFT OPENING AND CLOSING PROCEDURE

// Function opens petty cash shift.
//
Function CashCRSessionOpen(CashCR, ErrorDescription = "") Export
	
	CompletedSuccessfully = True;
	
	StructureStateCashCRSession = GetCashCRSessionStatus(CashCR);
	
	OpeningDateOfCashCRSession = CurrentDate();
	
	If StructureStateCashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen Then
		
		// If shift is opened, then since the opening there must be not more than 24 hours.
		If OpeningDateOfCashCRSession - StructureStateCashCRSession.StatusModificationDate < 86400 Then
			
			// Everything is OK
			
		Else
			
			CompletedSuccessfully = False;
			// Shift may not have been closed.
			ErrorDescription = NStr("en = 'More than 24 hours have passed since the register shift was opened. Close the register shift.'");
			
		EndIf;
		
	Else
		
		// Shift is closed. Open new petty cash shift.
		
		NewCashCRSession = Documents.ShiftClosure.CreateDocument();
		NewCashCRSession.Author = Users.CurrentUser();
		NewCashCRSession.Fill(New Structure("CashCR", CashCR));
		
		NewCashCRSession.Date                   = OpeningDateOfCashCRSession;
		NewCashCRSession.CashCRSessionStatus    = Enums.ShiftClosureStatus.IsOpen;
		NewCashCRSession.CashCRSessionStart    = OpeningDateOfCashCRSession;
		NewCashCRSession.CashCRSessionEnd = '00010101';
		
		If NewCashCRSession.CheckFilling() Then
			NewCashCRSession.Write(DocumentWriteMode.Posting);
		Else
			CompletedSuccessfully = False;
			ErrorDescription = NStr("en = 'Check settings of the retail warehouse and cash register.'");
		EndIf;
		
	EndIf;
	
	Return CompletedSuccessfully;
	
EndFunction

// Function closes petty cash shift.
//
Function CloseCashCRSession(ObjectCashCRSession) Export
	
	StructureReturns = New Structure;
	StructureReturns.Insert("ShiftClosure");
	StructureReturns.Insert("ErrorDescription");
	
	BeginTransaction();
	
	Try
		
		TempTablesManager = New TempTablesManager;
		
		// Data preparation.
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SalesSlips.Ref AS Ref,
		|	SalesSlips.StructuralUnit AS StructuralUnit,
		|	SalesSlips.DocumentCurrency AS DocumentCurrency,
		|	SalesSlips.PriceKind AS PriceKind,
		|	SalesSlips.CashCR AS CashCR,
		|	SalesSlips.Department AS Department,
		|	SalesSlips.Responsible AS Responsible,
		|	SalesSlips.Company AS Company,
		|	SalesSlips.DiscountCard AS DiscountCard,
		|	SalesSlips.POSTerminal AS POSTerminal,
		|	SalesSlips.Posted AS Posted,
		|	SalesSlips.SalesSlipNumber AS SalesSlipNumber,
		|	SalesSlips.Archival AS Archival,
		|	CASE
		|		WHEN CashRegisters.UseWithoutEquipmentConnection
		|			THEN SUBSTRING(SalesSlips.Number, 6, 6)
		|		ELSE SalesSlips.SalesSlipNumber
		|	END AS ReceiptNumber
		|INTO TT_SalesSlips
		|FROM
		|	Document.SalesSlip AS SalesSlips
		|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
		|		ON SalesSlips.CashCR = CashRegisters.Ref
		|WHERE
		|	SalesSlips.CashCRSession = &CashCRSession
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductReturns.Ref AS Ref,
		|	ProductReturns.StructuralUnit AS StructuralUnit,
		|	ProductReturns.DocumentCurrency AS DocumentCurrency,
		|	ProductReturns.PriceKind AS PriceKind,
		|	ProductReturns.CashCR AS CashCR,
		|	ProductReturns.Department AS Department,
		|	ProductReturns.Responsible AS Responsible,
		|	ProductReturns.Company AS Company,
		|	ProductReturns.DiscountCard AS DiscountCard,
		|	ProductReturns.POSTerminal AS POSTerminal,
		|	ProductReturns.Posted AS Posted,
		|	ProductReturns.SalesSlipNumber AS SalesSlipNumber,
		|	ProductReturns.Archival AS Archival,
		|	CASE
		|		WHEN CashRegisters.UseWithoutEquipmentConnection
		|			THEN SUBSTRING(SalesSlips.Number, 6, 6)
		|		ELSE SalesSlips.SalesSlipNumber
		|	END AS ReceiptNumber
		|INTO TT_ProductReturns
		|FROM
		|	Document.ProductReturn AS ProductReturns
		|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
		|		ON ProductReturns.CashCR = CashRegisters.Ref
		|		LEFT JOIN Document.SalesSlip AS SalesSlips
		|		ON ProductReturns.SalesSlip = SalesSlips.Ref
		|WHERE
		|	ProductReturns.CashCRSession = &CashCRSession
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesSlipInventory.Products AS Products,
		|	SalesSlipInventory.Characteristic AS Characteristic,
		|	SalesSlipInventory.Batch AS Batch,
		|	SUM(SalesSlipInventory.Quantity) AS Quantity,
		|	SalesSlipInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesSlipInventory.Price AS Price,
		|	CASE
		|		WHEN &UseAutomaticDiscounts
		|			THEN SalesSlipInventory.DiscountMarkupPercent + SalesSlipInventory.AutomaticDiscountsPercent
		|		ELSE SalesSlipInventory.DiscountMarkupPercent
		|	END AS DiscountMarkupPercent,
		|	SalesSlipInventory.VATRate AS VATRate,
		|	SUM(SalesSlipInventory.Amount) AS Amount,
		|	SUM(SalesSlipInventory.VATAmount) AS VATAmount,
		|	SUM(SalesSlipInventory.Total) AS Total,
		|	SalesSlipInventory.StructuralUnit AS StructuralUnit,
		|	SalesSlipInventory.DocumentCurrency AS DocumentCurrency,
		|	SalesSlipInventory.PriceKind AS PriceKind,
		|	SalesSlipInventory.CashCR AS CashCR,
		|	SalesSlipInventory.Department AS Department,
		|	SalesSlipInventory.Responsible AS Responsible,
		|	SalesSlipInventory.Company AS Company,
		|	SalesSlipInventory.DiscountCard AS DiscountCard,
		|	SalesSlipInventory.ReceiptNumber AS ReceiptNumber,
		|	SalesSlipInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	SUM(SalesSlipInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
		|	SalesSlipInventory.RevenueGLAccount AS RevenueGLAccount,
		|	SalesSlipInventory.VATOutputGLAccount AS VATOutputGLAccount
		|FROM
		|	(SELECT
		|		SalesSlipInventory.Products AS Products,
		|		SalesSlipInventory.Characteristic AS Characteristic,
		|		SalesSlipInventory.Batch AS Batch,
		|		SalesSlipInventory.Quantity AS Quantity,
		|		SalesSlipInventory.MeasurementUnit AS MeasurementUnit,
		|		SalesSlipInventory.Price AS Price,
		|		SalesSlipInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|		SalesSlipInventory.VATRate AS VATRate,
		|		SalesSlipInventory.Amount AS Amount,
		|		SalesSlipInventory.VATAmount AS VATAmount,
		|		SalesSlipInventory.Total AS Total,
		|		TT_SalesSlips.StructuralUnit AS StructuralUnit,
		|		TT_SalesSlips.DocumentCurrency AS DocumentCurrency,
		|		TT_SalesSlips.PriceKind AS PriceKind,
		|		TT_SalesSlips.CashCR AS CashCR,
		|		TT_SalesSlips.Department AS Department,
		|		TT_SalesSlips.Responsible AS Responsible,
		|		TT_SalesSlips.Company AS Company,
		|		TT_SalesSlips.DiscountCard AS DiscountCard,
		|		TT_SalesSlips.ReceiptNumber AS ReceiptNumber,
		|		SalesSlipInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|		SalesSlipInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
		|		SalesSlipInventory.RevenueGLAccount AS RevenueGLAccount,
		|		SalesSlipInventory.VATOutputGLAccount AS VATOutputGLAccount
		|	FROM
		|		TT_SalesSlips AS TT_SalesSlips
		|			INNER JOIN Document.SalesSlip.Inventory AS SalesSlipInventory
		|			ON TT_SalesSlips.Ref = SalesSlipInventory.Ref
		|	WHERE
		|		TT_SalesSlips.Posted
		|		AND TT_SalesSlips.SalesSlipNumber > 0
		|		AND NOT TT_SalesSlips.Archival
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ProductReturnInventory.Products,
		|		ProductReturnInventory.Characteristic,
		|		ProductReturnInventory.Batch,
		|		-ProductReturnInventory.Quantity,
		|		ProductReturnInventory.MeasurementUnit,
		|		ProductReturnInventory.Price,
		|		ProductReturnInventory.DiscountMarkupPercent,
		|		ProductReturnInventory.VATRate,
		|		-ProductReturnInventory.Amount,
		|		-ProductReturnInventory.VATAmount,
		|		-ProductReturnInventory.Total,
		|		TT_ProductReturns.StructuralUnit,
		|		TT_ProductReturns.DocumentCurrency,
		|		TT_ProductReturns.PriceKind,
		|		TT_ProductReturns.CashCR,
		|		TT_ProductReturns.Department,
		|		TT_ProductReturns.Responsible,
		|		TT_ProductReturns.Company,
		|		TT_ProductReturns.DiscountCard,
		|		TT_ProductReturns.ReceiptNumber,
		|		ProductReturnInventory.AutomaticDiscountsPercent,
		|		-ProductReturnInventory.AutomaticDiscountAmount,
		|		ProductReturnInventory.RevenueGLAccount,
		|		ProductReturnInventory.VATOutputGLAccount
		|	FROM
		|		TT_ProductReturns AS TT_ProductReturns
		|			INNER JOIN Document.ProductReturn.Inventory AS ProductReturnInventory
		|			ON TT_ProductReturns.Ref = ProductReturnInventory.Ref
		|	WHERE
		|		TT_ProductReturns.Posted
		|		AND TT_ProductReturns.SalesSlipNumber > 0
		|		AND NOT TT_ProductReturns.Archival) AS SalesSlipInventory
		|
		|GROUP BY
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SalesSlipInventory.MeasurementUnit,
		|	SalesSlipInventory.Price,
		|	SalesSlipInventory.DiscountMarkupPercent,
		|	SalesSlipInventory.StructuralUnit,
		|	SalesSlipInventory.DocumentCurrency,
		|	SalesSlipInventory.PriceKind,
		|	SalesSlipInventory.CashCR,
		|	SalesSlipInventory.Company,
		|	SalesSlipInventory.Department,
		|	SalesSlipInventory.Responsible,
		|	SalesSlipInventory.VATRate,
		|	SalesSlipInventory.DiscountCard,
		|	SalesSlipInventory.AutomaticDiscountsPercent,
		|	SalesSlipInventory.ReceiptNumber,
		|	CASE
		|		WHEN &UseAutomaticDiscounts
		|			THEN SalesSlipInventory.DiscountMarkupPercent + SalesSlipInventory.AutomaticDiscountsPercent
		|		ELSE SalesSlipInventory.DiscountMarkupPercent
		|	END,
		|	SalesSlipInventory.RevenueGLAccount,
		|	SalesSlipInventory.VATOutputGLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PaymentWithPaymentCards.POSTerminal AS POSTerminal,
		|	PaymentWithPaymentCards.ChargeCardKind AS ChargeCardKind,
		|	PaymentWithPaymentCards.ChargeCardNo AS ChargeCardNo,
		|	SUM(PaymentWithPaymentCards.Amount) AS Amount
		|FROM
		|	(SELECT
		|		SalesSlipPaymentWithPaymentCards.Ref.POSTerminal AS POSTerminal,
		|		SalesSlipPaymentWithPaymentCards.ChargeCardKind AS ChargeCardKind,
		|		SalesSlipPaymentWithPaymentCards.ChargeCardNo AS ChargeCardNo,
		|		SalesSlipPaymentWithPaymentCards.Amount AS Amount,
		|		TT_SalesSlips.CashCR AS CashCR,
		|		TT_SalesSlips.Company AS Company,
		|		TT_SalesSlips.StructuralUnit AS Warehouse,
		|		TT_SalesSlips.DocumentCurrency AS Currency,
		|		TT_SalesSlips.PriceKind AS PriceKind
		|	FROM
		|		TT_SalesSlips AS TT_SalesSlips
		|			INNER JOIN Document.SalesSlip.PaymentWithPaymentCards AS SalesSlipPaymentWithPaymentCards
		|			ON TT_SalesSlips.Ref = SalesSlipPaymentWithPaymentCards.Ref
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.POSTerminal,
		|		ReceiptsCRReturnPaymentWithPaymentCards.ChargeCardKind,
		|		ReceiptsCRReturnPaymentWithPaymentCards.ChargeCardNo,
		|		-ReceiptsCRReturnPaymentWithPaymentCards.Amount,
		|		TT_ProductReturns.CashCR,
		|		TT_ProductReturns.Company,
		|		TT_ProductReturns.StructuralUnit,
		|		TT_ProductReturns.DocumentCurrency,
		|		TT_ProductReturns.PriceKind
		|	FROM
		|		TT_ProductReturns AS TT_ProductReturns
		|			INNER JOIN Document.ProductReturn.PaymentWithPaymentCards AS ReceiptsCRReturnPaymentWithPaymentCards
		|			ON TT_ProductReturns.Ref = ReceiptsCRReturnPaymentWithPaymentCards.Ref) AS PaymentWithPaymentCards
		|
		|GROUP BY
		|	PaymentWithPaymentCards.POSTerminal,
		|	PaymentWithPaymentCards.ChargeCardKind,
		|	PaymentWithPaymentCards.ChargeCardNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	COUNT(DISTINCT SalesSlips.Responsible) AS CountResponsible
		|FROM
		|	(SELECT
		|		TT_SalesSlips.Responsible AS Responsible
		|	FROM
		|		TT_SalesSlips AS TT_SalesSlips
		|	WHERE
		|		TT_SalesSlips.Posted
		|		AND TT_SalesSlips.SalesSlipNumber > 0
		|		AND NOT TT_SalesSlips.Archival
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TT_ProductReturns.Responsible
		|	FROM
		|		TT_ProductReturns AS TT_ProductReturns
		|	WHERE
		|		TT_ProductReturns.Posted
		|		AND TT_ProductReturns.SalesSlipNumber > 0
		|		AND NOT TT_ProductReturns.Archival) AS SalesSlips
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesSlipInventory.Products AS Products,
		|	SalesSlipInventory.Characteristic AS Characteristic,
		|	SalesSlipDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
		|	SalesSlipDiscountsMarkups.Amount AS Amount
		|INTO TU_AutoDiscountsMarkupsJoin
		|FROM
		|	TT_SalesSlips AS TT_SalesSlips
		|		INNER JOIN Document.SalesSlip.Inventory AS SalesSlipInventory
		|		ON TT_SalesSlips.Ref = SalesSlipInventory.Ref
		|		INNER JOIN Document.SalesSlip.DiscountsMarkups AS SalesSlipDiscountsMarkups
		|		ON TT_SalesSlips.Ref = SalesSlipDiscountsMarkups.Ref
		|			AND (SalesSlipInventory.ConnectionKey = SalesSlipDiscountsMarkups.ConnectionKey)
		|WHERE
		|	TT_SalesSlips.Posted
		|	AND TT_SalesSlips.SalesSlipNumber > 0
		|	AND NOT TT_SalesSlips.Archival
		|
		|UNION ALL
		|
		|SELECT
		|	ProductReturnInventory.Products,
		|	ProductReturnInventory.Characteristic,
		|	ProductReturnDiscountsMarkups.DiscountMarkup,
		|	-ProductReturnDiscountsMarkups.Amount
		|FROM
		|	TT_ProductReturns AS TT_ProductReturns
		|		INNER JOIN Document.ProductReturn.Inventory AS ProductReturnInventory
		|		ON TT_ProductReturns.Ref = ProductReturnInventory.Ref
		|		INNER JOIN Document.ProductReturn.DiscountsMarkups AS ProductReturnDiscountsMarkups
		|		ON TT_ProductReturns.Ref = ProductReturnDiscountsMarkups.Ref
		|			AND (ProductReturnInventory.ConnectionKey = ProductReturnDiscountsMarkups.ConnectionKey)
		|WHERE
		|	TT_ProductReturns.Posted
		|	AND TT_ProductReturns.SalesSlipNumber > 0
		|	AND NOT TT_ProductReturns.Archival
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TU_AutoDiscountsMarkupsJoin.Products AS Products,
		|	TU_AutoDiscountsMarkupsJoin.Characteristic AS Characteristic,
		|	TU_AutoDiscountsMarkupsJoin.DiscountMarkup AS DiscountMarkup,
		|	SUM(TU_AutoDiscountsMarkupsJoin.Amount) AS Amount
		|FROM
		|	TU_AutoDiscountsMarkupsJoin AS TU_AutoDiscountsMarkupsJoin
		|
		|GROUP BY
		|	TU_AutoDiscountsMarkupsJoin.Products,
		|	TU_AutoDiscountsMarkupsJoin.Characteristic,
		|	TU_AutoDiscountsMarkupsJoin.DiscountMarkup
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesSlipSalesRefunds.Products AS Products,
		|	SalesSlipSalesRefunds.Characteristic AS Characteristic,
		|	SalesSlipSalesRefunds.Batch AS Batch,
		|	SalesSlipSalesRefunds.MeasurementUnit AS MeasurementUnit,
		|	SalesSlipSalesRefunds.Price AS Price,
		|	SalesSlipSalesRefunds.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	SalesSlipSalesRefunds.VATRate AS VATRate,
		|	SalesSlipSalesRefunds.SerialNumber AS SerialNumber,
		|	SalesSlipSalesRefunds.ReceiptNumber AS ReceiptNumber,
		|	SUM(SalesSlipSalesRefunds.FlagOfSales) AS FlagOfSales
		|FROM
		|	(SELECT
		|		SalesSlipInventory.Products AS Products,
		|		SalesSlipInventory.Characteristic AS Characteristic,
		|		SalesSlipInventory.Batch AS Batch,
		|		SalesSlipInventory.MeasurementUnit AS MeasurementUnit,
		|		SalesSlipInventory.Price AS Price,
		|		SalesSlipInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|		SalesSlipInventory.VATRate AS VATRate,
		|		SalesSlipSerialNumbers.SerialNumber AS SerialNumber,
		|		TT_SalesSlips.ReceiptNumber AS ReceiptNumber,
		|		1 AS FlagOfSales
		|	FROM
		|		TT_SalesSlips AS TT_SalesSlips
		|			INNER JOIN Document.SalesSlip.Inventory AS SalesSlipInventory
		|			ON TT_SalesSlips.Ref = SalesSlipInventory.Ref
		|			INNER JOIN Document.SalesSlip.SerialNumbers AS SalesSlipSerialNumbers
		|			ON TT_SalesSlips.Ref = SalesSlipSerialNumbers.Ref
		|				AND (SalesSlipInventory.ConnectionKey = SalesSlipSerialNumbers.ConnectionKey)
		|	WHERE
		|		TT_SalesSlips.Posted
		|		AND TT_SalesSlips.SalesSlipNumber > 0
		|		AND NOT TT_SalesSlips.Archival
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ProductReturnInventory.Products,
		|		ProductReturnInventory.Characteristic,
		|		ProductReturnInventory.Batch,
		|		ProductReturnInventory.MeasurementUnit,
		|		ProductReturnInventory.Price,
		|		ProductReturnInventory.DiscountMarkupPercent,
		|		ProductReturnInventory.VATRate,
		|		ProductReturnSerialNumbers.SerialNumber,
		|		TT_ProductReturns.ReceiptNumber,
		|		-1
		|	FROM
		|		TT_ProductReturns AS TT_ProductReturns
		|			INNER JOIN Document.ProductReturn.Inventory AS ProductReturnInventory
		|			ON TT_ProductReturns.Ref = ProductReturnInventory.Ref
		|			INNER JOIN Document.ProductReturn.SerialNumbers AS ProductReturnSerialNumbers
		|			ON TT_ProductReturns.Ref = ProductReturnSerialNumbers.Ref
		|				AND (ProductReturnInventory.ConnectionKey = ProductReturnSerialNumbers.ConnectionKey)
		|	WHERE
		|		TT_ProductReturns.Posted
		|		AND TT_ProductReturns.SalesSlipNumber > 0
		|		AND NOT TT_ProductReturns.Archival) AS SalesSlipSalesRefunds
		|
		|GROUP BY
		|	SalesSlipSalesRefunds.Products,
		|	SalesSlipSalesRefunds.Characteristic,
		|	SalesSlipSalesRefunds.Batch,
		|	SalesSlipSalesRefunds.MeasurementUnit,
		|	SalesSlipSalesRefunds.VATRate,
		|	SalesSlipSalesRefunds.SerialNumber,
		|	SalesSlipSalesRefunds.ReceiptNumber,
		|	SalesSlipSalesRefunds.Price,
		|	SalesSlipSalesRefunds.DiscountMarkupPercent
		|
		|HAVING
		|	SUM(SalesSlipSalesRefunds.FlagOfSales) > 0";
		
		Query.TempTablesManager = TempTablesManager;
		Query.SetParameter("CashCRSession", ObjectCashCRSession.Ref);
		// AutomaticDiscounts
		Query.SetParameter("UseAutomaticDiscounts", GetFunctionalOption("UseAutomaticDiscounts"));
		// End AutomaticDiscounts
		
		Result = Query.ExecuteBatch();
		
		Inventory = Result[2].Unload();
		PaymentWithPaymentCards = Result[3].Unload();
		
		ObjectCashCRSession.Inventory.Clear();
		ObjectCashCRSession.PaymentWithPaymentCards.Clear();
		
		If Inventory.Count() > 0 Then
			ObjectCashCRSession.PositionResponsible = ?(
				Result[4].Unload()[0].CountResponsible > 1,
				Enums.AttributeStationing.InTabularSection,
				Enums.AttributeStationing.InHeader
			);
		EndIf;
		
		For Each TSRow In Inventory Do
			
			If TSRow.Total <> 0 Then
				RowOfTabularSectionInventory = ObjectCashCRSession.Inventory.Add();
				FillPropertyValues(RowOfTabularSectionInventory, TSRow);
			EndIf;
			
		EndDo;
		
		GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ObjectCashCRSession); 
		
		For Each TSRow In PaymentWithPaymentCards Do
			
			If TSRow.Amount <> 0 Then
				TabularSectionRow = ObjectCashCRSession.PaymentWithPaymentCards.Add();
				FillPropertyValues(TabularSectionRow, TSRow);
			EndIf;
			
		EndDo;
		
		// AutomaticDiscounts
		ObjectCashCRSession.DiscountsMarkups.Clear();
		If GetFunctionalOption("UseAutomaticDiscounts") Then
			
			AutomaticDiscounts = Result[6].Unload();
			For Each TSRow In AutomaticDiscounts Do
				
				If TSRow.Amount <> 0 Then
					TabularSectionRow = ObjectCashCRSession.DiscountsMarkups.Add();
					FillPropertyValues(TabularSectionRow, TSRow);
				EndIf;
				
			EndDo;
			
		EndIf;
		// End AutomaticDiscounts
		
		// Serial numbers
		ObjectCashCRSession.SerialNumbers.Clear();
		WorkWithSerialNumbersClientServer.FillConnectionKeysInTabularSectionProducts(ObjectCashCRSession, "Inventory");
		If GetFunctionalOption("UseSerialNumbers") Then
			
			SerialNumbers = Result[7].Unload();
			For Each TSRow In ObjectCashCRSession.Inventory Do
				
				ConnectionKey = 0;
				FilterStructure = New Structure("Products, Characteristic, Batch, MeasurementUnit, Price, VATRate, ReceiptNumber");
				FillPropertyValues(FilterStructure, TSRow);
				
				SerialNumbersByFilter = SerialNumbers.FindRows(FilterStructure);
				
				If SerialNumbersByFilter.Count()>0 Then
					
					ConnectionKey = TSRow.ConnectionKey;
					
					For Each Str In SerialNumbersByFilter Do
						NewRow = ObjectCashCRSession.SerialNumbers.Add();
						NewRow.ConnectionKey = ConnectionKey;
						NewRow.SerialNumber = Str.SerialNumber;
					EndDo;
				EndIf;
				
				WorkWithSerialNumbersClientServer.UpdateStringPresentationOfSerialNumbersOfLine(TSRow, ObjectCashCRSession, "ConnectionKey");
				
			EndDo;
			
		EndIf;
		// Serial numbers
		
		ClosingDateOfCashCRSession = CurrentDate();
		ObjectCashCRSession.CashCRSessionStatus    = Enums.ShiftClosureStatus.Closed;
		ObjectCashCRSession.Date                   = ClosingDateOfCashCRSession;
		ObjectCashCRSession.CashCRSessionEnd = ClosingDateOfCashCRSession;
		ObjectCashCRSession.DocumentAmount         = ObjectCashCRSession.Inventory.Total("Total");
		
		If Inventory.Count() > 0 Then
			ObjectCashCRSession.Responsible = Inventory[0].Responsible;
		EndIf;
		
		If Not ValueIsFilled(ObjectCashCRSession.Responsible) Then
			ObjectCashCRSession.Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
		EndIf;
		
		ObjectCashCRSession.Write(DocumentWriteMode.Posting);
		
		CommitTransaction();
		
		StructureReturns.ShiftClosure = ObjectCashCRSession.Ref;
		StructureReturns.ErrorDescription = "";
		
	Except
		
		RollbackTransaction();
		
		StructureReturns.ShiftClosure = Undefined;
		StructureReturns.ErrorDescription = NStr("en = 'An error occurred while generating retail sales report.
		                                         |Cash session closing is not completed.'"
		);
		
	EndTry;
	
	Return StructureReturns;
	
EndFunction

// Function deletes deferred receipts.
//
Function DeleteDeferredReceipts(CashCRSession, ErrorDescription)
	
	Result = True;
	
	BeginTransaction();
	
	Query = New Query(
	"SELECT
	|	SalesSlip.Ref AS Ref
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Status <> &Status
	|	AND SalesSlip.CashCRSession = &CashCRSession
	|
	|UNION ALL
	|
	|SELECT
	|	ProductReturn.Ref
	|FROM
	|	Document.ProductReturn AS ProductReturn
	|WHERE
	|	ProductReturn.SalesSlipNumber = 0
	|	AND ProductReturn.CashCRSession = &CashCRSession");
	Query.SetParameter("CashCRSession", CashCRSession.Ref);
	Query.SetParameter("Status",        Enums.SalesSlipStatus.Issued);
	SalesSlipSelection = Query.Execute().Select();
	
	Try
		
		While SalesSlipSelection.Next() Do
			SalesSlipObject = SalesSlipSelection.Ref.GetObject();
			SalesSlipObject.Delete();
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		Result = False;
		
		ErrorDescription = NStr("en = 'An error occurred while deleting deferred receipts.
		                        |Additional
		                        |description: %AdditionalDetails%'");
		ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);
		
	EndTry;
	
	Return Result;
	
EndFunction

// Function archives receipts CR by the petty cash shift.
//
Procedure RunReceiptsBackup(ObjectCashCRSession, ErrorDescription = "") Export
	
	BeginTransaction();

	Query = New Query(
	"SELECT
	|	2 AS Order,
	|	SalesSlip.Ref AS Ref
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	NOT SalesSlip.Archival
	|	AND SalesSlip.Posted
	|	AND SalesSlip.SalesSlipNumber > 0
	|	AND SalesSlip.CashCRSession = &CashCRSession
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	ProductReturn.Ref
	|FROM
	|	Document.ProductReturn AS ProductReturn
	|WHERE
	|	NOT ProductReturn.Archival
	|	AND ProductReturn.Posted
	|	AND ProductReturn.SalesSlipNumber > 0
	|	AND ProductReturn.CashCRSession = &CashCRSession
	|
	|ORDER BY
	|	Order");
	Query.SetParameter("CashCRSession", ObjectCashCRSession.Ref);
	SalesSlipSelection = Query.Execute().Select();
	
	Try
		
		While SalesSlipSelection.Next() Do
			SalesSlipObject = SalesSlipSelection.Ref.GetObject();
			SalesSlipObject.Archival = True;
			SalesSlipObject.Write(DocumentWriteMode.Posting);
		EndDo;
		
		ObjectCashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.ClosedReceiptsArchived;
		ObjectCashCRSession.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);
		ObjectCashCRSession.Write(DocumentWriteMode.Posting);
		
		If WorkWithSerialNumbers.UseSerialNumbersBalance() = True Then
			Set = AccumulationRegisters.SerialNumbers.CreateRecordSet();
			Set.Filter.Recorder.Set(SalesSlipSelection.Ref);
			Set.Write(True);
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'An error occurred while archiving receipts CR. Receipts CR are not archived.
				|Additional description: %1'"),
			ErrorInfo().Description);
	EndTry;

EndProcedure

// Procedure closes petty cash shift.
//
Function CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription = "") Export
	
	DocumentArray = New Array;
	
	StructureStateCashCRSession = GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen Then
		
		ObjectCashCRSession = StructureStateCashCRSession.CashCRSession.GetObject();
		
		StructureReturns = Documents.ShiftClosure.CloseCashCRSession(ObjectCashCRSession);
		If StructureReturns.ShiftClosure = Undefined Then
			
			ErrorDescription = StructureReturns.ErrorDescription;
			
		Else
			
			DocumentArray.Add(StructureReturns.ShiftClosure);
			
			If Constants.DeleteNonIssuedSalesSlips.Get() Then
				DeleteDeferredReceipts(StructureStateCashCRSession.CashCRSession.GetObject(), ErrorDescription);
			EndIf;
			
			If Constants.ArchiveSalesSlipsDuringTheShiftClosure.Get() Then
				RunReceiptsBackup(StructureStateCashCRSession.CashCRSession.GetObject(), ErrorDescription);
			EndIf;
			
		EndIf;
		
	Else
		
		// Session is not opened.
		
	EndIf;
	
	Return DocumentArray;
	
EndFunction

#Region ShiftStateCheckFunctions

// Function returns empty string of petty cash shift state.
//
Function GetCashCRSessionDescriptionStructure()
	
	StatusCashCRSession = New Structure;
	StatusCashCRSession.Insert("StatusModificationDate");
	StatusCashCRSession.Insert("CashCRSessionStatus");
	StatusCashCRSession.Insert("CashCRSession");
	StatusCashCRSession.Insert("CashInPettyCash");
	StatusCashCRSession.Insert("CashCRSessionNumber");
	StatusCashCRSession.Insert("SessionIsOpen", False);
	
	// Description of petty cash shift attributes
	StatusCashCRSession.Insert("CashCR");
	StatusCashCRSession.Insert("DocumentCurrency");
	StatusCashCRSession.Insert("DocumentCurrencyPresentation");
	StatusCashCRSession.Insert("PriceKind");
	StatusCashCRSession.Insert("Company");
	StatusCashCRSession.Insert("Responsible");
	StatusCashCRSession.Insert("Department");
	StatusCashCRSession.Insert("StructuralUnit");
	StatusCashCRSession.Insert("AmountIncludesVAT");
	StatusCashCRSession.Insert("IncludeVATInPrice");
	StatusCashCRSession.Insert("VATTaxation");
	
	Return StatusCashCRSession;
	
EndFunction

// Function returns structure that characterizes last petty cash shift state by receipt CR.
//
Function GetCashCRSessionStatus(CashCR) Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ShiftClosure.Number AS CashCRSessionNumber,
	|	ShiftClosure.Ref AS CashCRSession,
	|	ShiftClosure.CashCRSessionStatus AS CashCRSessionStatus,
	|	ShiftClosure.CashCR AS CashCR,
	|	ShiftClosure.DocumentCurrency AS DocumentCurrency,
	|	ShiftClosure.DocumentCurrency.Presentation AS DocumentCurrencyPresentation,
	|	ShiftClosure.PriceKind AS PriceKind,
	|	ShiftClosure.Company AS Company,
	|	ShiftClosure.Responsible AS Responsible,
	|	ShiftClosure.Department AS Department,
	|	ShiftClosure.StructuralUnit AS StructuralUnit,
	|	ShiftClosure.AmountIncludesVAT AS AmountIncludesVAT,
	|	ShiftClosure.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SessionIsOpen,
	|	CASE
	|		WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|			THEN ShiftClosure.CashCRSessionStart
	|		ELSE ShiftClosure.CashCRSessionEnd
	|	END AS StatusModificationDate,
	|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS CashInPettyCash,
	|	ShiftClosure.VATTaxation AS VATTaxation
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(, CashCR = &CashCR) AS CashAssetsInRetailCashesBalances
	|		ON ShiftClosure.CashCR = CashAssetsInRetailCashesBalances.CashCR
	|WHERE
	|	ShiftClosure.Posted
	|	AND ShiftClosure.CashCR = &CashCR
	|
	|ORDER BY
	|	ShiftClosure.Date DESC,
	|	CashCRSession DESC";
	
	Query.SetParameter("CashCR", CashCR);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	CashShiftDescription = GetCashCRSessionDescriptionStructure();
	
	If Selection.Next() Then
		FillPropertyValues(CashShiftDescription, Selection);
	EndIf;
	
	Return CashShiftDescription;
	
EndFunction

// Function returns structure that characterizes petty cash shift state on date.
//
Function GetCashCRSessionAttributesToDate(CashCR, DateTime) Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ShiftClosure.Number AS CashCRSessionNumber,
	|	ShiftClosure.Ref AS CashCRSession,
	|	ShiftClosure.CashCRSessionStatus AS CashCRSessionStatus,
	|	ShiftClosure.CashCR AS CashCR,
	|	ShiftClosure.DocumentCurrency AS DocumentCurrency,
	|	ShiftClosure.DocumentCurrency.Presentation AS DocumentCurrencyPresentation,
	|	ShiftClosure.PriceKind AS PriceKind,
	|	ShiftClosure.Company AS Company,
	|	ShiftClosure.Responsible AS Responsible,
	|	ShiftClosure.Department AS Department,
	|	ShiftClosure.StructuralUnit AS StructuralUnit,
	|	ShiftClosure.AmountIncludesVAT AS AmountIncludesVAT,
	|	ShiftClosure.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SessionIsOpen,
	|	CASE
	|		WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|			THEN ShiftClosure.CashCRSessionStart
	|		ELSE ShiftClosure.CashCRSessionEnd
	|	END AS StatusModificationDate,
	|	ISNULL(CashAssetsInRetailCashesBalances.AmountBalance, 0) AS CashInPettyCash,
	|	ShiftClosure.VATTaxation AS VATTaxation
	|FROM
	|	(SELECT
	|		MAX(CASE
	|				WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|					THEN ShiftClosure.CashCRSessionStart
	|				ELSE ShiftClosure.CashCRSessionEnd
	|			END) AS StatusModificationDate,
	|		ShiftClosure.CashCR AS CashCR
	|	FROM
	|		Document.ShiftClosure AS ShiftClosure
	|	WHERE
	|		ShiftClosure.Posted
	|		AND ShiftClosure.CashCR = &CashCR
	|		AND CASE
	|				WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|					THEN ShiftClosure.CashCRSessionStart
	|				ELSE ShiftClosure.CashCRSessionEnd
	|			END <= &DateTime
	|	
	|	GROUP BY
	|		ShiftClosure.CashCR) AS CashChange
	|		LEFT JOIN Document.ShiftClosure AS ShiftClosure
	|		ON CashChange.CashCR = ShiftClosure.CashCR
	|			AND (ShiftClosure.Posted)
	|			AND (CashChange.StatusModificationDate = CASE
	|				WHEN ShiftClosure.CashCRSessionStatus = VALUE(Enum.ShiftClosureStatus.IsOpen)
	|					THEN ShiftClosure.CashCRSessionStart
	|				ELSE ShiftClosure.CashCRSessionEnd
	|			END)
	|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(&DateTime, CashCR = &CashCR) AS CashAssetsInRetailCashesBalances
	|		ON CashChange.CashCR = CashAssetsInRetailCashesBalances.CashCR";
	
	Query.SetParameter("CashCR", CashCR);
	Query.SetParameter("DateTime", DateTime+100);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	StatusCashCRSession = GetCashCRSessionDescriptionStructure();
	
	If Selection.Next() Then
		FillPropertyValues(StatusCashCRSession, Selection);
	EndIf;
	
	Return StatusCashCRSession;
	
EndFunction

// Function receives open petty cash shift by Receipt CR in the specified period.
// Used to control petty cash shifts intersection.
// Only one petty cash shift can simultaneously exist during one period.
//
Function GetOpenCashCRSession(CashCR, CashCRSession = Undefined, CashCRSessionStart, CashCRSessionEnd) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ShiftClosure.Ref
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.CashCRSessionStart <= &CashCRSessionStart
	|	AND CASE
	|			WHEN ShiftClosure.CashCRSessionEnd = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE ShiftClosure.CashCRSessionEnd >= &CashCRSessionStart
	|		END
	|	AND ShiftClosure.CashCR = &CashCR
	|	AND ShiftClosure.Ref <> &CashCRSession
	|	AND ShiftClosure.Posted
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	ShiftClosure.Ref
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	&CashCRSessionEnd <> DATETIME(1, 1, 1)
	|	AND ShiftClosure.CashCRSessionStart <= &CashCRSessionEnd
	|	AND CASE
	|			WHEN ShiftClosure.CashCRSessionEnd = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE ShiftClosure.CashCRSessionEnd >= &CashCRSessionEnd
	|		END
	|	AND ShiftClosure.CashCR = &CashCR
	|	AND ShiftClosure.Ref <> &CashCRSession
	|	AND ShiftClosure.Posted
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	ShiftClosure.Ref
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	&CashCRSessionEnd = DATETIME(1, 1, 1)
	|	AND ShiftClosure.CashCRSessionStart >= &CashCRSessionStart
	|	AND ShiftClosure.CashCR = &CashCR
	|	AND ShiftClosure.Ref <> &CashCRSession
	|	AND ShiftClosure.Posted";
	
	Query.SetParameter("CashCR",               CashCR);
	Query.SetParameter("CashCRSessionStart",    CashCRSessionStart);
	Query.SetParameter("CashCRSessionEnd", CashCRSessionEnd);
	Query.SetParameter("CashCRSession",          CashCRSession);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Function checks petty cash shift state on date. If shift is not opened - error description is returned.
//
Function SessionIsOpen(CashCRSession, Date, ErrorDescription = "") Export
	
	SessionIsOpen = False;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ShiftClosure.CashCRSessionStatus AS CashCRSessionStatus,
	|	ShiftClosure.CashCRSessionStart AS CashCRSessionStart,
	|	ShiftClosure.CashCRSessionEnd AS CashCRSessionEnd
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.Posted
	|	AND ShiftClosure.Ref = &CashCRSession";
	
	Query.SetParameter("CashCRSession", CashCRSession);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		
		If Selection.CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen Then
			
			// If shift is opened, then since the opening there must be not more than 24 hours.
			If Date - Selection.CashCRSessionStart < 86400 Then
				SessionIsOpen = True;
			Else
				ErrorDescription = NStr("en = 'More than 24 hours have passed since the register shift was opened. Close the register shift'");
				SessionIsOpen = False;
			EndIf;
			
		ElsIf ValueIsFilled(Selection.CashCRSessionStatus) Then
			
			If Selection.CashCRSessionEnd >= Date AND Selection.CashCRSessionStart <= Date Then
				SessionIsOpen = True;
			Else
				ErrorDescription = NStr("en = 'Shift is not opened'");
				SessionIsOpen = False;
			EndIf;
			
		EndIf;
		
	Else
		
		ErrorDescription = NStr("en = 'Shift is not opened'");
		SessionIsOpen = False;
		
	EndIf;
	
	Return SessionIsOpen;
	
EndFunction

#EndRegion

#Region PrintInterface

// Function generates tabular document of petty cash book cover.
//
Function GeneratePrintFormOfReportAboutRetailSales(ObjectsArray, PrintObjects)
	
	Template = PrintManagement.PrintedFormsTemplate("Document.ShiftClosure.PF_MXL_ShiftClosure");
	
	Spreadsheet = New SpreadsheetDocument;
	Spreadsheet.PrintParametersName = "PRINT_PARAMETERS_Check_SaleInvoice";
	
	For Each SalesSlip In ObjectsArray Do
		
		FirstLineNumber = Spreadsheet.TableHeight + 1;
		
		Query = New Query;
		Query.SetParameter("CurrentDocument", SalesSlip.Ref);
		
		Query.Text =
		"SELECT
		|	ShiftClosure.Number AS Number,
		|	ShiftClosure.Date AS Date,
		|	ShiftClosure.CashCR AS CashCR,
		|	ShiftClosure.DocumentCurrency AS Currency,
		|	ShiftClosure.CashCR.Presentation AS Customer,
		|	ShiftClosure.Company AS Company,
		|	ShiftClosure.Company.Prefix AS Prefix,
		|	ShiftClosure.Company.Presentation AS Vendor,
		|	ShiftClosure.DocumentAmount AS DocumentAmount,
		|	ShiftClosure.AmountIncludesVAT AS AmountIncludesVAT,
		|	ShiftClosure.Responsible.Ind AS Responsible,
		|	ShiftClosure.Inventory.(
		|		LineNumber AS LineNumber,
		|		Products AS Products,
		|		Products.Presentation AS InventoryItem,
		|		Products.DescriptionFull AS InventoryFullDescr,
		|		Products.Code AS Code,
		|		Products.SKU AS SKU,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Price AS Price,
		|		Amount AS Amount,
		|		VATAmount AS VATAmount,
		|		Total AS Total,
		|		DiscountMarkupPercent,
		|		CASE
		|			WHEN ShiftClosure.Inventory.DiscountMarkupPercent <> 0
		|					OR ShiftClosure.Inventory.AutomaticDiscountAmount <> 0
		|				THEN 1
		|			ELSE 0
		|		END AS IsDiscount,
		|		AutomaticDiscountAmount,
		|		ConnectionKey
		|	),
		|	ShiftClosure.SerialNumbers.(
		|		SerialNumber,
		|		ConnectionKey
		|	)
		|FROM
		|	Document.ShiftClosure AS ShiftClosure
		|WHERE
		|	ShiftClosure.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date, ,);
		
		If Header.Date < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
			
		// Output invoice header.
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = 
			"Shift closure No"
		  + DocumentNumber
		  + " from "
		  + Format(Header.Date, "DLF=DD");
		
		Spreadsheet.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		VendorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.VendorPresentation = VendorPresentation;
		TemplateArea.Parameters.Vendor = Header.Company;
		Spreadsheet.Put(TemplateArea);
		
		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		NumberArea = Template.GetArea("TableHeader|LineNumber");
		DataArea = Template.GetArea("TableHeader|Data");
		DiscountsArea = Template.GetArea("TableHeader|Discount");
		AmountArea  = Template.GetArea("TableHeader|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		Spreadsheet.Join(AmountArea);
		
		AreaColumnInventory = Template.Area("InventoryItem");
		
		If Not AreDiscounts Then
			AreaColumnInventory.ColumnWidth = AreaColumnInventory.ColumnWidth
											  + Template.Area("AmountWithoutDiscount").ColumnWidth
											  + Template.Area("DiscountAmount").ColumnWidth;
		EndIf;
		
		NumberArea = Template.GetArea("String|LineNumber");
		DataArea = Template.GetArea("String|Data");
		DiscountsArea = Template.GetArea("String|Discount");
		AmountArea  = Template.GetArea("String|Amount");
		
		Amount			= 0;
		VATAmount		= 0;
		Total			= 0;
		TotalDiscounts		= 0;
		TotalWithoutDiscounts	= 0;
		
		LinesSelectionInventory = Header.Inventory.Select();
		LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
		While LinesSelectionInventory.Next() Do
			
			If Not ValueIsFilled(LinesSelectionInventory.Products) Then
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Products value is not filled in one of the rows - String during printing is skipped.'"));
				Continue;
			EndIf;
			
			NumberArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Put(NumberArea);
			
			DataArea.Parameters.Fill(LinesSelectionInventory);
			StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
			DataArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				LinesSelectionInventory.InventoryItem,
				LinesSelectionInventory.Characteristic,
				LinesSelectionInventory.SKU,
				StringSerialNumbers
			);
			
			Spreadsheet.Join(DataArea);
			
			Discount = 0;
			
			If AreDiscounts Then
				If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
					Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
					DiscountsArea.Parameters.Discount         = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = Discount;
				ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
					DiscountsArea.Parameters.Discount         = 0;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
				Else
					Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
					DiscountsArea.Parameters.Discount         = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
				EndIf;
				Spreadsheet.Join(DiscountsArea);
			EndIf;
			
			AmountArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Join(AmountArea);
			
			Amount			= Amount			+ LinesSelectionInventory.Amount;
			VATAmount		= VATAmount		+ LinesSelectionInventory.VATAmount;
			Total			= Total			+ LinesSelectionInventory.Total;
			TotalDiscounts		= TotalDiscounts	+ Discount;
			TotalWithoutDiscounts	= Amount			+ TotalDiscounts;
			
		EndDo;
		
		// Output Total.
		NumberArea = Template.GetArea("Total|LineNumber");
		DataArea = Template.GetArea("Total|Data");
		DiscountsArea = Template.GetArea("Total|Discount");
		AmountArea  = Template.GetArea("Total|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		DataStructure = New Structure("Total", Amount);
		If VATAmount = 0 Then
			
			DataStructure.Insert("VAT", "Without tax (VAT)");
			DataStructure.Insert("VATAmount", "-");
			
		Else
			
			DataStructure.Insert("VAT", ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:"));
			DataStructure.Insert("VATAmount", DriveServer.AmountsFormat(VATAmount));
			
		EndIf; 
		
		DataArea.Parameters.Fill(DataStructure);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			DiscountsArea.Parameters.TotalDiscounts    = TotalDiscounts;
			DiscountsArea.Parameters.TotalWithoutDiscounts = TotalWithoutDiscounts;
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		
		AmountArea.Parameters.Fill(DataStructure);
		Spreadsheet.Join(AmountArea);
		
		// Output amount in writing.
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
													+ String(LinesSelectionInventory.Count())
													+ ", in the amount of "
													+ DriveServer.AmountsFormat(AmountToBeWrittenInWords, Header.Currency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithExchangeRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.Currency);
		Spreadsheet.Put(TemplateArea);
	
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.Responsible) Then
			
			ResponsibleData = DriveServer.IndData(
				DriveServer.GetCompany(Header.Company),
				Header.Responsible, 
				Header.Date);
			
			TemplateArea.Parameters.ResponsibleDetails	= ResponsibleData.Presentation;
			
		EndIf;
		
		Spreadsheet.Put(TemplateArea);
		
		Spreadsheet.PutHorizontalPageBreak();
		
		PrintManagement.SetDocumentPrintArea(Spreadsheet, FirstLineNumber, PrintObjects, SalesSlip);
		
	EndDo;
	
	Return Spreadsheet;
	
EndFunction

// Document printing procedure.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ShiftClosure") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ShiftClosure",
			"Retail report",
			GeneratePrintFormOfReportAboutRetailSales(ObjectsArray, PrintObjects)
		);
		
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
	PrintCommand.ID = "ShiftClosure";
	PrintCommand.Presentation = NStr("en = 'Shift closure'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure VATOutputEntriesGeneration() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	ShiftClosure.Ref AS Ref
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|		INNER JOIN Document.ShiftClosure.Inventory AS ShiftClosureInventory
	|		ON ShiftClosure.Ref = ShiftClosureInventory.Ref
	|		INNER JOIN Catalog.VATRates AS VATRates
	|		ON (ShiftClosureInventory.VATRate = VATRates.Ref)
	|			AND (NOT VATRates.NotTaxable)
	|		LEFT JOIN AccumulationRegister.VATOutput AS VATOutput
	|		ON ShiftClosure.Ref = VATOutput.Recorder
	|			AND (VATOutput.LineNumber = 1)
	|WHERE
	|	ShiftClosure.Posted
	|	AND ShiftClosure.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|	AND VATOutput.Recorder IS NULL";
	
	Sel = Query.Execute().Select();
	
	BeginTransaction();
	
	While Sel.Next() Do
		
		DocObject = Sel.Ref.GetObject();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		DocObject.AddAttributesToAdditionalPropertiesForPosting(DocObject.AdditionalProperties);
		
		Documents.ShiftClosure.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		DriveServer.ReflectVATOutput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
		
		DriveServer.WriteRecordSets(DocObject.ThisObject);
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

Procedure FillNewGLAccounts() Export
	
	DocumentName = "ShiftClosure";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountCostOfSales";
	GLAccountFields.Receiver = "COGSGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountRevenueFromSales";
	GLAccountFields.Receiver = "RevenueGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf