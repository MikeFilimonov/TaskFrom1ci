#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
		
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SUM(TemporaryTable.VATAmount) AS VATExpenses,
	|	SUM(TemporaryTable.VATAmountCur) AS VATExpensesCur
	|FROM
	|	TemporaryTableProduction AS TemporaryTable
	|
	|GROUP BY
	|	TemporaryTable.Period,
	|	TemporaryTable.Company";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATExpenses = 0;
	VATExpensesCur = 0;
	
	While Selection.Next() Do
		VATExpenses		= Selection.VATExpenses;
		ATExpensesCur	= Selection.VATExpensesCur;
	EndDo;

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.LineNumber AS LineNumber,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AccountStatementSales.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AccountStatementSales.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment,
	|	FALSE
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
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
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
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
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
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
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	4,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN &VATExpensesCur
	|		ELSE 0
	|	END,
	|	&VATExpenses,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableProduction AS TableAccountingJournalEntries
	|WHERE
	|	&VATExpenses <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	OfflineRecords.LineNumber,
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
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("PrepaymentReversal",							NStr("en = 'Advance payment reversal'", MainLanguageCode));
	Query.SetParameter("ReversingSupplies",								NStr("en = 'Delivery reversal'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("TextVAT",										Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("VATExpenses",									VATExpenses);
	Query.SetParameter("VATExpensesCur",								VATExpensesCur);
	Query.SetParameter("Ref",											DocumentRefReportAboutRecycling);

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SourceDocument,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS CorrSalesOrder,
	|	TableInventory.DepartmentSales AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.BusinessLineSales AS BusinessLine,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	TableInventory.SalesRep AS SalesRep,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&InventoryWriteOff AS Content,
	|	&InventoryWriteOff AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	TableInventory.BusinessLineSales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.StructuralUnit,
	|	TableInventory.DepartmentSales,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.VATRate,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.SalesRep,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.DepartmentSales,
	|	TableInventory.SalesOrder,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	UNDEFINED,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	UNDEFINED,
	|	OfflineRecords.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	If FillAmount Then
		FillAmountInInventory(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure FillAmountInInventory(DocumentRef, StructureAdditionalProperties)
	
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
	|	TemporaryTableProduction AS TableInventory
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
	|						TemporaryTableProduction AS TableInventory)) AS InventoryBalances
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
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
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
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
									
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Record expenses'", MainLanguageCode);
			
			EndIf;
			
		EndIf;
		
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
					
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Record expenses'", MainLanguageCode);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	END AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount,
	|	&InventoryWriteOff AS Content,
	|	&InventoryWriteOff AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableWaste AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'", MainLanguageCode));
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", QueryResult.Unload());

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, RowTableInventory);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryDisposals");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.VATAmountSales) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.VATAmountSales) AS Amount,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.SalesRep,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
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
	|	OfflineRecords.SalesRep,
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
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableInventoryInWarehouses
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableInventoryInWarehouses.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell,
	|	SUM(TableInventoryInWarehouses.Quantity)
	|FROM
	|	TemporaryTableWaste AS TableInventoryInWarehouses
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockReceivedFromThirdParties(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockReceivedFromThirdParties.Period AS Period,
	|	TableStockReceivedFromThirdParties.Company AS Company,
	|	TableStockReceivedFromThirdParties.Products AS Products,
	|	TableStockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	TableStockReceivedFromThirdParties.Batch AS Batch,
	|	UNDEFINED AS Counterparty,
	|	UNDEFINED AS Contract,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND UseInventoryReservation.Value
	|			THEN TableStockReceivedFromThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableStockReceivedFromThirdParties,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	TableStockReceivedFromThirdParties.BatchStatus = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND UseInventoryReservation.Value
	|			THEN TableStockReceivedFromThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Contract,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	SUM(TableStockReceivedFromThirdParties.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.BatchStatus = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Contract,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryReception", NStr("en = 'Inventory receipt'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	CAST(&IncomeReflection AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
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
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
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
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Record income'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefReportAboutRecycling);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesOrders(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.SalesOrder AS SalesOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableSalesOrders
	|WHERE
	|	TableSalesOrders.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.SalesOrder <> UNDEFINED
	|
	|GROUP BY
	|	TableSalesOrders.Period,
	|	TableSalesOrders.Company,
	|	TableSalesOrders.Products,
	|	TableSalesOrders.Characteristic,
	|	TableSalesOrders.SalesOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en = 'Incurrence of customer liabilities'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit", NStr("en = 'Prepayment setoff'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ExpectedPayments", NStr("en = 'Expected payments'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END
	|	) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END
	|	) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfCustomerLiability AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableProduction AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CustomerAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	CASE
	|		WHEN Calendar.DoOperationsByDocuments
	|			THEN Calendar.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN Calendar.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND Calendar.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Calendar.Order
	|		ELSE UNDEFINED
	|	END,
	|	Calendar.SettlementsCurrency,
	|	Calendar.SettlemensTypeWhere,
	|	0,
	|	0,
	|	0,
	|	0,
	|	Calendar.Amount,
	|	Calendar.AmountCur,
	|	CAST(&ExpectedPayments AS String(100))
	|FROM
	|	TemporaryTablePaymentCalendar AS Calendar
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable AS TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.BusinessLineSales AS BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome
	|FROM
	|	TemporaryTableProduction AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Amount <> 0
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();

	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained In TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountIncome AS AmountIncome
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	SubcontractorReportIssued.Ref AS Ref,
	|	SubcontractorReportIssued.Date AS Date,
	|	SubcontractorReportIssued.AmountIncludesVAT AS AmountIncludesVAT,
	|	SubcontractorReportIssued.CashAssetsType AS CashAssetsType,
	|	SubcontractorReportIssued.Contract AS Contract,
	|	SubcontractorReportIssued.PettyCash AS PettyCash,
	|	SubcontractorReportIssued.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorReportIssued.BankAccount AS BankAccount
	|INTO Document
	|FROM
	|	Document.SubcontractorReportIssued AS SubcontractorReportIssued
	|WHERE
	|	SubcontractorReportIssued.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssuedPaymentCalendar.PaymentDate AS Period,
	|	Document.CashAssetsType AS CashAssetsType,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN SubcontractorReportIssuedPaymentCalendar.PaymentAmount
	|		ELSE SubcontractorReportIssuedPaymentCalendar.PaymentAmount + SubcontractorReportIssuedPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.SubcontractorReportIssued.PaymentCalendar AS SubcontractorReportIssuedPaymentCalendar
	|		ON Document.Ref = SubcontractorReportIssuedPaymentCalendar.Ref
	|			AND (SubcontractorReportIssuedPaymentCalendar.PaymentDate > Document.Date)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Quote AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN PaymentCalendar.SettlementsCurrency
	|		ELSE PaymentCalendar.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN CAST(PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE PaymentCalendar.PaymentAmount
	|	END AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfDocument
	|		ON PaymentCalendar.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PaymentCalendar.SettlementsCurrency = SettlementsExchangeRates.Currency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure	

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	If DocumentRefReportAboutRecycling.DiscountsMarkups.Count() = 0 Or Not GetFunctionalOption("UseAutomaticDiscounts") Then
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
	|	TemporaryTableProduction.Products,
	|	TemporaryTableProduction.Characteristic,
	|	TemporaryTableProduction.Document AS DocumentDiscounts,
	|	TemporaryTableProduction.Counterparty AS RecipientDiscounts
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableProduction.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefReportAboutRecycling, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = "
	|SELECT
	|	SubcontractorReportIssuedProducts.LineNumber AS LineNumber,
	|	SubcontractorReportIssuedProducts.Ref.Date AS Period,
	|	SubcontractorReportIssuedProducts.Ref AS Document,
	|	SubcontractorReportIssuedProducts.Ref.Counterparty AS Counterparty,
	|	SubcontractorReportIssuedProducts.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SubcontractorReportIssuedProducts.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	SubcontractorReportIssuedProducts.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorReportIssuedProducts.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	SubcontractorReportIssuedProducts.Ref.Contract AS Contract,
	|	SubcontractorReportIssuedProducts.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	&Company AS Company,
	|	SubcontractorReportIssuedProducts.Ref.Department AS DepartmentSales,
	|	SubcontractorReportIssuedProducts.Ref.Responsible AS Responsible,
	|	SubcontractorReportIssuedProducts.Products.BusinessLine AS BusinessLineSales,
	|	SubcontractorReportIssuedProducts.Products.BusinessLine.GLAccountRevenueFromSales AS AccountStatementSales,
	|	SubcontractorReportIssuedProducts.Products.BusinessLine.GLAccountCostOfSales AS GLAccountCost,
	|	SubcontractorReportIssuedProducts.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SubcontractorReportIssuedProducts.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SubcontractorReportIssuedProducts.Products.InventoryGLAccount AS GLAccount,
	|	SubcontractorReportIssuedProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportIssuedProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportIssuedProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE WHEN SubcontractorReportIssuedProducts.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|		THEN UNDEFINED
	|		ELSE SubcontractorReportIssuedProducts.Ref.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportIssuedProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReportIssuedProducts.Quantity
	|		ELSE SubcontractorReportIssuedProducts.Quantity * SubcontractorReportIssuedProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportIssuedProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReportIssuedProducts.Reserve
	|		ELSE SubcontractorReportIssuedProducts.Reserve * SubcontractorReportIssuedProducts.MeasurementUnit.Factor
	|	END AS Reserve,
	|	SubcontractorReportIssuedProducts.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedProducts.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportIssuedProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportIssuedProducts.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SubcontractorReportIssuedProducts.VATAmount * SubcontractorReportIssuedProducts.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedProducts.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportIssuedProducts.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportIssuedProducts.VATAmount * SubcontractorReportIssuedProducts.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedProducts.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportIssuedProducts.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportIssuedProducts.Total * SubcontractorReportIssuedProducts.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedProducts.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedProducts.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportIssuedProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportIssuedProducts.VATAmount * RegExchangeRates.ExchangeRate * SubcontractorReportIssuedProducts.Ref.Multiplicity / (SubcontractorReportIssuedProducts.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SubcontractorReportIssuedProducts.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportIssuedProducts.Total * RegExchangeRates.ExchangeRate * SubcontractorReportIssuedProducts.Ref.Multiplicity / (SubcontractorReportIssuedProducts.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportIssuedProducts.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	SubcontractorReportIssuedProducts.ConnectionKey AS ConnectionKey,
	|	SubcontractorReportIssuedProducts.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	SubcontractorReportIssuedProducts.SalesRep AS SalesRep
	|INTO TemporaryTableProduction
	|FROM
	|	Document.SubcontractorReportIssued.Products AS SubcontractorReportIssuedProducts
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReportIssuedProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssuedInventory.LineNumber AS LineNumber,
	|	SubcontractorReportIssuedInventory.ConnectionKey AS ConnectionKey,
	|	SubcontractorReportIssuedInventory.Ref AS Document,
	|	SubcontractorReportIssuedInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorReportIssuedInventory.Ref.Counterparty AS Counterparty,
	|	SubcontractorReportIssuedInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SubcontractorReportIssuedInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	SubcontractorReportIssuedInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorReportIssuedInventory.Ref.Contract AS Contract,
	|	SubcontractorReportIssuedInventory.Products.InventoryGLAccount AS GLAccount,
	|	SubcontractorReportIssuedInventory.Batch.Status AS BatchStatus,
	|	SubcontractorReportIssuedInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportIssuedInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportIssuedInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportIssuedInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReportIssuedInventory.Quantity
	|		ELSE SubcontractorReportIssuedInventory.Quantity * SubcontractorReportIssuedInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	SubcontractorReportIssuedInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportIssuedInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportIssuedInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SubcontractorReportIssuedInventory.VATAmount * SubcontractorReportIssuedInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportIssuedInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportIssuedInventory.VATAmount * SubcontractorReportIssuedInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportIssuedInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportIssuedInventory.Total * SubcontractorReportIssuedInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SubcontractorReportIssuedInventory.Total AS SettlementsAmountTakenPassed,
	|	SubcontractorReportIssuedInventory.Ref.SalesOrder AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SubcontractorReportIssued.Inventory AS SubcontractorReportIssuedInventory
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReportIssuedInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssuedDisposals.LineNumber AS LineNumber,
	|	SubcontractorReportIssuedDisposals.Ref.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorReportIssuedDisposals.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SubcontractorReportIssuedDisposals.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SubcontractorReportIssuedDisposals.Products.InventoryGLAccount AS GLAccount,
	|	SubcontractorReportIssuedDisposals.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportIssuedDisposals.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportIssuedDisposals.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SubcontractorReportIssuedDisposals.Ref.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportIssuedDisposals.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReportIssuedDisposals.Quantity
	|		ELSE SubcontractorReportIssuedDisposals.Quantity * SubcontractorReportIssuedDisposals.MeasurementUnit.Factor
	|	END AS Quantity
	|INTO TemporaryTableWaste
	|FROM
	|	Document.SubcontractorReportIssued.Disposals AS SubcontractorReportIssuedDisposals
	|WHERE
	|	SubcontractorReportIssuedDisposals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Ref.SalesOrder AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SubcontractorReportIssued.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.SalesOrder,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssuedDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	SubcontractorReportIssuedDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(CASE
	|			WHEN SubcontractorReportIssuedDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportIssuedDiscountsMarkups.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportIssuedDiscountsMarkups.Amount * SubcontractorReportIssuedDiscountsMarkups.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportIssuedDiscountsMarkups.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SubcontractorReportIssuedDiscountsMarkups.Ref.Date AS Period,
	|	SubcontractorReportIssuedDiscountsMarkups.Ref.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.SubcontractorReportIssued.DiscountsMarkups AS SubcontractorReportIssuedDiscountsMarkups
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReportIssuedDiscountsMarkups.Ref = &Ref
	|	AND SubcontractorReportIssuedDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssuedSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SubcontractorReportIssuedSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SubcontractorReportIssued.SerialNumbers AS SubcontractorReportIssuedSerialNumbers
	|WHERE
	|	SubcontractorReportIssuedSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS PaymentDate,
	|	&Company AS Company,
	|	&Ref AS Ref,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.SubcontractorReportIssued.PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	CounterpartyRef.DoOperationsByContracts AS DoOperationsByContracts,
	|	CounterpartyRef.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CounterpartyRef.DoOperationsByOrders AS DoOperationsByOrders,
	|	CounterpartyRef.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Header.Contract AS Contract,
	|	CounterpartyContractsRef.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	Header.SalesOrder AS Order,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * Header.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * Header.Multiplicity) AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * Header.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * Header.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Calendar.PaymentAmount
	|		ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		INNER JOIN Document.SubcontractorReportIssued AS Header
	|		ON (Header.Ref = Calendar.Ref)
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON (CounterpartyRef.Ref = Header.Counterparty)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON (CounterpartyContractsRef.Ref = Header.Contract)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroupWithHeader AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader";
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableInventory(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableInventoryDisposals(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableIncomeAndExpensesRetained(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
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
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Period AS EventDate,
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
	|	TemporaryTableProduction AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
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
Procedure RunControl(DocumentRefReportAboutRecycling, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "TransferInventoryInWarehousesChange", 
	// "RegisterRecordsStockReceivedFromThirdPartiesChange" contain entries, it is necessary to perform control of product selling.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
	 OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
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
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
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
		|WHERE
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) IN
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
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
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() Then
			DocumentObjectSubcontractorReportIssued = DocumentRefReportAboutRecycling.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSubcontractorReportIssued, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSubcontractorReportIssued, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectSubcontractorReportIssued, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectSubcontractorReportIssued, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectSubcontractorReportIssued, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Function checks if the document is
// posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SubcontractorReportIssued";

	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "Act" Then
		
			Query = New Query();
			Query.SetParameter("ObjectsArray", ObjectsArray);
			Query.Text = 
			"SELECT
			|	SubcontractorReportIssued.Ref AS Ref,
			|	SubcontractorReportIssued.Number AS Number,
			|	SubcontractorReportIssued.Date AS DocumentDate,
			|	SubcontractorReportIssued.Company AS Company,
			|	SubcontractorReportIssued.Counterparty AS Counterparty,
			|	SubcontractorReportIssued.AmountIncludesVAT AS AmountIncludesVAT,
			|	SubcontractorReportIssued.DocumentCurrency AS DocumentCurrency,
			|	SubcontractorReportIssued.Company.Prefix AS Prefix,
			|	SubcontractorReportIssued.Released,
			|	SubcontractorReportIssued.Products.(
			|		LineNumber AS LineNumber,
			|		CASE
			|			WHEN (CAST(SubcontractorReportIssued.Products.Products.DescriptionFull AS String(1000))) = """"
			|				THEN SubcontractorReportIssued.Products.Products.Description
			|			ELSE CAST(SubcontractorReportIssued.Products.Products.DescriptionFull AS String(1000))
			|		END AS Product,
			|		Products.SKU AS SKU,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Price AS Price,
			|		Amount AS Amount,
			|		VATAmount AS VATAmount,
			|		Total AS Total,
			|		Characteristic,
			|		Content,
			|		DiscountMarkupPercent,
			|		CASE
			|			WHEN SubcontractorReportIssued.Products.DiscountMarkupPercent <> 0
			|					OR SubcontractorReportIssued.Products.AutomaticDiscountAmount <> 0
			|				THEN 1
			|			ELSE 0
			|		END AS IsDiscount,
			|		AutomaticDiscountAmount,
			|		ConnectionKey
			|	),
			|	SubcontractorReportIssued.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.SubcontractorReportIssued AS SubcontractorReportIssued
			|WHERE
			|	SubcontractorReportIssued.Ref IN(&ObjectsArray)
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
				
				StringSelectionProducts = Header.Products.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
				
				SpreadsheetDocument.PrintParametersName = "PRINTING_PARAMETERS_ReportRecycling_Act";
				
				Template = PrintManagement.PrintedFormsTemplate("Document.SubcontractorReportIssued.PF_MXL_Act");
				
				InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
				InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
				
				If Header.DocumentDate < Date('20110101') Then
					DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
				Else
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
				EndIf;		
				
				TemplateArea = Template.GetArea("Title");
				TemplateArea.Parameters.HeaderText = "Act # "
				                                        + DocumentNumber
				                                        + " dated "
				                                        + Format(Header.DocumentDate, "DLF=DD");
				
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("Vendor");
				TemplateArea.Parameters.VendorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("Customer");
				TemplateArea.Parameters.RecipientPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
				SpreadsheetDocument.Put(TemplateArea);
				
				AreDiscounts = Header.Products.Unload().Total("IsDiscount") <> 0;
		
				If AreDiscounts Then
					
					TemplateArea = Template.GetArea("TableWithDiscountHeader");
					SpreadsheetDocument.Put(TemplateArea);
					TemplateArea = Template.GetArea("RowWithDiscount");
					
				Else
					
					TemplateArea = Template.GetArea("TableHeader");
					SpreadsheetDocument.Put(TemplateArea);
					TemplateArea = Template.GetArea("String");
					
				EndIf;
				
				Amount		= 0;
				VATAmount	= 0;
				Total		= 0;
				Quantity	= 0;
				
				While StringSelectionProducts.Next() Do
					TemplateArea.Parameters.Fill(StringSelectionProducts);
					
					If ValueIsFilled(StringSelectionProducts.Content) Then
						TemplateArea.Parameters.Product = StringSelectionProducts.Content;
					Else
						StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, StringSelectionProducts.ConnectionKey);
						TemplateArea.Parameters.Product = DriveServer.GetProductsPresentationForPrinting(
							StringSelectionProducts.Product,
							StringSelectionProducts.Characteristic,
							StringSelectionProducts.SKU,
							StringSerialNumbers);
					EndIf;
					
					If AreDiscounts Then
						If StringSelectionProducts.DiscountMarkupPercent = 100 Then
							Discount = StringSelectionProducts.Price * StringSelectionProducts.Quantity;
							TemplateArea.Parameters.Discount         = Discount;
							TemplateArea.Parameters.AmountWithoutDiscount = Discount;
						ElsIf StringSelectionProducts.DiscountMarkupPercent = 0 AND StringSelectionProducts.AutomaticDiscountAmount = 0 Then
							TemplateArea.Parameters.Discount         = 0;
							TemplateArea.Parameters.AmountWithoutDiscount = StringSelectionProducts.Amount;
						Else
							Discount = StringSelectionProducts.Quantity * StringSelectionProducts.Price - StringSelectionProducts.Amount; // AutomaticDiscounts
							TemplateArea.Parameters.Discount         = Discount;
							TemplateArea.Parameters.AmountWithoutDiscount = StringSelectionProducts.Amount + Discount;
						EndIf;
					EndIf;
					
					SpreadsheetDocument.Put(TemplateArea);
					
					Amount		= Amount 	+ StringSelectionProducts.Amount;
					VATAmount	= VATAmount	+ StringSelectionProducts.VATAmount;
					Total		= Total		+ StringSelectionProducts.Total;
					Quantity	= Quantity+ 1;
					
				EndDo;
				
				TemplateArea = Template.GetArea("Total");
				TemplateArea.Parameters.Total = DriveServer.AmountsFormat(Amount);
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("TotalVAT");
				If VATAmount = 0 Then
					TemplateArea.Parameters.VAT = "Without tax (VAT)";
					TemplateArea.Parameters.TotalVAT = "-";
				Else
					TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
					TemplateArea.Parameters.TotalVAT = DriveServer.AmountsFormat(VATAmount);
				EndIf; 
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("AmountInWords");
				AmountToBeWrittenInWords = Total;
				TemplateArea.Parameters.TotalRow = "Total titles "
				                                        + String(Quantity)
				                                        + ", in the amount of "
				                                        + DriveServer.AmountsFormat(AmountToBeWrittenInWords, Header.DocumentCurrency);
				
				TemplateArea.Parameters.AmountInWords = WorkWithExchangeRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.DocumentCurrency);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("Signatures");
				
				ParameterValues = New Structure;
				
				SNPReleaseMade = "";
				DriveServer.SurnameInitialsByName(SNPReleaseMade, String(Header.Released));
				ParameterValues.Insert("Released", SNPReleaseMade);
				
				TemplateArea.Parameters.Fill(ParameterValues);
				SpreadsheetDocument.Put(TemplateArea);
				
				PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
				
			EndDo;
			
		ElsIf TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	SubcontractorReportIssued.Date AS DocumentDate,
			|	SubcontractorReportIssued.StructuralUnit AS WarehousePresentation,
			|	SubcontractorReportIssued.Cell AS CellPresentation,
			|	SubcontractorReportIssued.Number,
			|	SubcontractorReportIssued.Company.Prefix AS Prefix,
			|	SubcontractorReportIssued.Products.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(SubcontractorReportIssued.Products.Products.DescriptionFull AS String(100))) = """"
			|				THEN SubcontractorReportIssued.Products.Products.Description
			|			ELSE SubcontractorReportIssued.Products.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	SubcontractorReportIssued.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.SubcontractorReportIssued AS SubcontractorReportIssued
			|WHERE
			|	SubcontractorReportIssued.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Products.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ReportAboutrocessing_FormOfProductContent";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.SubcontractorReportIssued.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "Subcontractor report issued # "
													+ DocumentNumber
													+ " from "
													+ Format(Header.DocumentDate, "DLF=DD");
													
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
			TemplateArea.Parameters.PrintingTime = "Date and time of printing: "
												 	+ CurrentDate()
													+ ". User: "
													+ Users.CurrentUser();
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
//   TemplateNames   - String    - Names of layouts separated  by commas 
//   ObjectsArray    - Array     - Array of refs to objects that need to be printed
//   PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   OutputParameters     - Structure   - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Act") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Act", "Processing Service Report", PrintForm(ObjectsArray, PrintObjects, "Act"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
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
	PrintCommand.ID = "Act";
	PrintCommand.Presentation = NStr("en = 'Customized document set'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Act";
	PrintCommand.Presentation = NStr("en = 'Acceptance note'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 2;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Goods content form'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 3;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 4;

EndProcedure

#EndRegion

#EndIf