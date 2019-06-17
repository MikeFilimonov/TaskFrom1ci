#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region AccountingRecords

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
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
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|						THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur - (TableAccountingJournalEntries.BrokerageAmountCur - TableAccountingJournalEntries.BrokerageVATAmountCur)
	|					ELSE TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|		ELSE TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|	END AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	2,
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
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|				THEN CASE
	|						WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|							THEN TableAccountingJournalEntries.VATAmountCur - TableAccountingJournalEntries.BrokerageVATAmountCur
	|						ELSE TableAccountingJournalEntries.VATAmountCur
	|					END
	|			ELSE 0
	|		END),
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|				THEN TableAccountingJournalEntries.VATAmount - TableAccountingJournalEntries.BrokerageVATAmount
	|			ELSE TableAccountingJournalEntries.VATAmount
	|		END),
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmountCur > 0
	|
	|GROUP BY
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	TableAccountingJournalEntries.Period,
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
	
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAccountSalesFromConsignee);

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
Procedure GenerateTableInventory(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
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
	|	TableInventory.KeepBackComissionFee AS KeepBackComissionFee,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	SUM(TableInventory.BrokerageAmount) AS BrokerageAmount,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&AccountSalesFromConsignee AS Content,
	|	&AccountSalesFromConsignee AS ContentOfAccountingRecord,
	|	TableInventory.SalesRep AS SalesRep
	|FROM
	|	TemporaryTableInventory AS TableInventory
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
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.VATRate,
	|	TableInventory.KeepBackComissionFee,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.DepartmentSales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount,
	|	TableInventory.SalesRep";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("AccountSalesFromConsignee", NStr("en = 'Account sales from consignee'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
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
	|	TemporaryTableInventory AS TableInventory
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
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
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
			
			// Add the row for the order.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
									
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				StringTableSale = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(StringTableSale, RowTableInventory);
				
				StringTableSale.Quantity = 0;
				StringTableSale.Amount = 0;
				StringTableSale.VATAmount = 0;
				StringTableSale.Cost = AmountToBeWrittenOff;
				
				If RowTableInventory.KeepBackComissionFee Then
					
					// It is necessary to increase the sales cost by the amount of fee.
					NewRow	= StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
					FillPropertyValues(NewRow, RowTableInventory);
					
					NewRow.Quantity		= 0;
					NewRow.Amount			= 0;
					NewRow.VATAmount		= 0;
					NewRow.Cost	= RowTableInventory.BrokerageAmount;
					
				EndIf;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Cost of goods sold'", MainLanguageCode);
				
			EndIf;
			
		EndIf;
			
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
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
	|				AND TableSales.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.VATAmount - TableSales.BrokerageVATAmount
	|			ELSE TableSales.VATAmount
	|		END) AS VATAmount,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.Amount - TableSales.BrokerageAmount
	|			ELSE TableSales.Amount
	|		END - CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.VATAmount - TableSales.BrokerageVATAmount
	|			ELSE TableSales.VATAmount
	|		END) AS Amount,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
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
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockTransferredToThirdParties(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	TableStockTransferredToThirdParties.Contract AS Contract,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableStockTransferredToThirdParties
	|
	|GROUP BY
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	TableStockTransferredToThirdParties.Contract,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	MAX(TableIncomeAndExpenses.LineNumber) AS LineNumber,
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
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackComissionFee
	|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount - (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount)
	|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount
	|		END) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
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
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue from account sales'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAccountSalesFromConsignee);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Accounts receivable recognition'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ExpectedPayments",				NStr("en = 'Expected payment'", MainLanguageCode));
	
	Query.Text = "
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
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
	|			AND DocumentTable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN DocumentTable.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Amount
	|		END) AS Amount,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Amount
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountCurForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|		ELSE
	|			CASE WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Amount
	|		END
	|	END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|		ELSE
	|			CASE WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.AmountCur
	|		END
	|	END) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfCustomerLiability AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
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
	|			AND DocumentTable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN DocumentTable.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(DocumentTable.LineNumber),
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
	|			AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
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
	|			AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
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
	|	MAX(DocumentTable.LineNumber),
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
	|	Calendar.LineNumber,
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
	|	CASE WHEN Calendar.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|		THEN Calendar.Order
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
	
	// Setting the exclusive lock for the controlled accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
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
	|	CASE
	|		WHEN DocumentTable.KeepBackComissionFee
	|			THEN (DocumentTable.Amount - DocumentTable.VATAmount) - (DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount)    
	|			ELSE DocumentTable.Amount -  DocumentTable.VATAmount      
	|	END AS AmountIncome
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
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
Procedure GenerateTablePaymentCalendar(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	AccountSalesFromConsignee.Ref AS Ref,
	|	AccountSalesFromConsignee.Date AS Date,
	|	AccountSalesFromConsignee.AmountIncludesVAT AS AmountIncludesVAT,
	|	AccountSalesFromConsignee.CashAssetsType AS CashAssetsType,
	|	AccountSalesFromConsignee.Contract AS Contract,
	|	AccountSalesFromConsignee.PettyCash AS PettyCash,
	|	AccountSalesFromConsignee.DocumentCurrency AS DocumentCurrency,
	|	AccountSalesFromConsignee.BankAccount AS BankAccount
	|INTO Document
	|FROM
	|	Document.AccountSalesFromConsignee AS AccountSalesFromConsignee
	|WHERE
	|	AccountSalesFromConsignee.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesFromConsigneePaymentCalendar.PaymentDate AS Period,
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
	|			THEN AccountSalesFromConsigneePaymentCalendar.PaymentAmount
	|		ELSE AccountSalesFromConsigneePaymentCalendar.PaymentAmount + AccountSalesFromConsigneePaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.AccountSalesFromConsignee.PaymentCalendar AS AccountSalesFromConsigneePaymentCalendar
	|		ON Document.Ref = AccountSalesFromConsigneePaymentCalendar.Ref
	|			AND (AccountSalesFromConsigneePaymentCalendar.PaymentDate > Document.Date)
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

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	AccountSalesFromConsigneeInventory.LineNumber AS LineNumber,
	|	AccountSalesFromConsigneeInventory.ConnectionKey AS ConnectionKey,
	|	AccountSalesFromConsigneeInventory.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
	|	AccountSalesFromConsigneeInventory.Ref AS Document,
	|	AccountSalesFromConsigneeInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	AccountSalesFromConsigneeInventory.Ref.Counterparty AS Counterparty,
	|	AccountSalesFromConsigneeInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AccountSalesFromConsigneeInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AccountSalesFromConsigneeInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AccountSalesFromConsigneeInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	AccountSalesFromConsigneeInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AccountSalesFromConsigneeInventory.Ref.Contract AS Contract,
	|	AccountSalesFromConsigneeInventory.Ref.Counterparty AS StructuralUnit,
	|	AccountSalesFromConsigneeInventory.Ref.KeepBackComissionFee AS KeepBackComissionFee,
	|	AccountSalesFromConsigneeInventory.Ref.Department AS DepartmentSales,
	|	AccountSalesFromConsigneeInventory.Ref.Responsible AS Responsible,
	|	AccountSalesFromConsigneeInventory.Products.BusinessLine AS BusinessLineSales,
	|	AccountSalesFromConsigneeInventory.RevenueGLAccount AS AccountStatementSales,
	|	AccountSalesFromConsigneeInventory.COGSGLAccount AS GLAccountCost,
	|	AccountSalesFromConsigneeInventory.InventoryTransferredGLAccount AS GLAccount,
	|	AccountSalesFromConsigneeInventory.VATOutputGLAccount AS VATOutputGLAccount,
	|	AccountSalesFromConsigneeInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AccountSalesFromConsigneeInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AccountSalesFromConsigneeInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(AccountSalesFromConsigneeInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AccountSalesFromConsigneeInventory.Quantity
	|		ELSE AccountSalesFromConsigneeInventory.Quantity * AccountSalesFromConsigneeInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	AccountSalesFromConsigneeInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesFromConsigneeInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesFromConsigneeInventory.VATAmount * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesFromConsigneeInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesFromConsigneeInventory.VATAmount * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesFromConsigneeInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesFromConsigneeInventory.Total * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesFromConsigneeInventory.VATAmount * RegExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity / (AccountSalesFromConsigneeInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesFromConsigneeInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesFromConsigneeInventory.Total * RegExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity / (AccountSalesFromConsigneeInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesFromConsigneeInventory.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesFromConsigneeInventory.TransmissionVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesFromConsigneeInventory.TransmissionVATAmount * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS CostVAT,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesFromConsigneeInventory.TransmissionAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesFromConsigneeInventory.TransmissionAmount + AccountSalesFromConsigneeInventory.TransmissionVATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesFromConsigneeInventory.TransmissionAmount * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|					ELSE (AccountSalesFromConsigneeInventory.TransmissionAmount + AccountSalesFromConsigneeInventory.TransmissionVATAmount) * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS Cost,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesFromConsigneeInventory.BrokerageVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesFromConsigneeInventory.BrokerageVATAmount * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmount,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesFromConsigneeInventory.BrokerageAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesFromConsigneeInventory.BrokerageAmount * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|					ELSE (AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount) * AccountSalesFromConsigneeInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmount,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesFromConsigneeInventory.BrokerageAmount * RegExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity / (AccountSalesFromConsigneeInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount) * RegExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity / (AccountSalesFromConsigneeInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesFromConsigneeInventory.BrokerageAmount
	|					ELSE AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesFromConsigneeInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesFromConsigneeInventory.BrokerageVATAmount * RegExchangeRates.ExchangeRate * AccountSalesFromConsigneeInventory.Ref.Multiplicity / (AccountSalesFromConsigneeInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesFromConsigneeInventory.BrokerageVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmountCur,
	|	CASE
	|		WHEN AccountSalesFromConsigneeInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN AccountSalesFromConsigneeInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CAST(CASE
	|			WHEN AccountSalesFromConsigneeInventory.Ref.AmountIncludesVAT
	|				THEN AccountSalesFromConsigneeInventory.TransmissionAmount
	|			ELSE AccountSalesFromConsigneeInventory.TransmissionAmount + AccountSalesFromConsigneeInventory.TransmissionVATAmount
	|		END AS NUMBER(15, 2)) AS SettlementsAmountTakenPassed,
	|	AccountSalesFromConsigneeInventory.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	AccountSalesFromConsigneeInventory.SalesRep AS SalesRep
	|INTO TemporaryTableInventory
	|FROM
	|	Document.AccountSalesFromConsignee.Inventory AS AccountSalesFromConsigneeInventory
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
	|	AccountSalesFromConsigneeInventory.Ref = &Ref
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
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	DocumentTable.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.AccountSalesFromConsignee.Prepayment AS DocumentTable
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
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
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
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesFromConsigneeSerialNumbers.ConnectionKey AS ConnectionKey,
	|	AccountSalesFromConsigneeSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.AccountSalesFromConsignee.SerialNumbers AS AccountSalesFromConsigneeSerialNumbers
	|WHERE
	|	AccountSalesFromConsigneeSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.Ref AS Ref,
	|	Calendar.PaymentDate AS PaymentDate,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.AccountSalesFromConsignee.PaymentCalendar AS Calendar
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
	|	UNDEFINED AS Order,
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
	|		INNER JOIN Document.AccountSalesFromConsignee AS Header
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
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
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
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKeySerialNumbers = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult.Unload());
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAccountSalesFromConsignee, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "RegisterRecordsInventoryChange", "TransfersStockTransferredToThirdPartiesChange"
	// temprorary tables contain records, it is necessary to control the sale of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
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
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockTransferredToThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange, 0) + ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockTransferredToThirdParties,
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockTransferredToThirdParties
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockTransferredToThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Counterparty, Contract, Order) In
		|					(SELECT
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS Batch,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS Counterparty,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Contract AS Contract,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Order AS Order
		|					FROM
		|						RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange)) AS StockTransferredToThirdPartiesBalances
		|		ON RegisterRecordsStockTransferredToThirdPartiesChange.Company = StockTransferredToThirdPartiesBalances.Company
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Products = StockTransferredToThirdPartiesBalances.Products
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic = StockTransferredToThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Batch = StockTransferredToThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty = StockTransferredToThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Contract = StockTransferredToThirdPartiesBalances.Contract
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Order = StockTransferredToThirdPartiesBalances.Order
		|WHERE
		|	(ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) < 0)
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
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectAccountSalesFromConsignee = DocumentRefAccountSalesFromConsignee.GetObject();
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectAccountSalesFromConsignee, QueryResultSelection, Cancel);
		EndIf;
		
		// The negative balance of transferred inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocumentObjectAccountSalesFromConsignee, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectAccountSalesFromConsignee, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

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

Procedure FillNewGLAccounts() Export
	
	DocumentName = "AccountSalesFromConsignee";
	
	Tables = New Array();
	
	// Table "Inventory"
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountRevenueFromSales";
	GLAccountFields.Receiver = "RevenueGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountCostOfSales";
	GLAccountFields.Receiver = "COGSGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf