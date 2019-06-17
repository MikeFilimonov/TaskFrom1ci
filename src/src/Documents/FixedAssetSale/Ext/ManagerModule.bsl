#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("AccrueDepreciation", NStr("en = 'Accrue depreciation'", MainLanguageCode));
	Query.SetParameter("OtherExpenses", NStr("en = 'Expenses incurred'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	TRUE AS FixedCost,
	|	&AccrueDepreciation AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	&AccrueDepreciation AS ContentOfAccountingRecord,
	|	DocumentTable.MonthlyDepreciation AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	DocumentTable.BusinessLineSales,
	|	UNDEFINED,
	|	DocumentTable.BusinessLineSales.GLAccountRevenueFromSales,
	|	&OtherIncome,
	|	DocumentTable.Amount,
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	DocumentTable.BusinessLineSales,
	|	UNDEFINED,
	|	DocumentTable.BusinessLineSales.GLAccountCostOfSales,
	|	&OtherExpenses,
	|	0,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	5,
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

	Query.SetParameter("AccrueDepreciation",							NStr("en = 'Accrue depreciation'", MainLanguageCode));
	Query.SetParameter("OtherIncome",									NStr("en = 'Other income'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",									NStr("en = 'Other expenses'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",											DocumentRefPassWA);
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("AccrueDepreciation",					NStr("en = 'Accrue depreciation'", MainLanguageCode));
	Query.SetParameter("DepreciationDebiting",					NStr("en = 'Depreciation deduction'", MainLanguageCode));
	Query.SetParameter("WriteOffOfFixedAssetFromAccounting",	NStr("en = 'Fixed asset sale'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.MonthlyDepreciation AS Depreciation,
	|	0 AS Cost,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	DocumentTable.DepreciationAccount AS GLAccount,
	|	&AccrueDepreciation AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.FixedAsset,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	DocumentTable.DepreciationAccount,
	|	&DepreciationDebiting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.Cost,
	|	DocumentTable.Cost,
	|	DocumentTable.GLAccount,
	|	&WriteOffOfFixedAssetFromAccounting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetStatuses(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.FixedAssetStatus.RemoveFromAccounting) AS State,
	|	FALSE AS AccrueDepreciation,
	|	FALSE AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsStates", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefPassWA);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Accounts receivable recognition'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	UNDEFINED AS Order,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	SUM(DocumentTable.Amount) AS AmountForPayment,
	|	SUM(DocumentTable.AmountCur) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
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
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	UNDEFINED,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
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
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	UNDEFINED,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
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
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPassWA);
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
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefPassWA, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPassWA);
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
Procedure GenerateTableAccountingJournalEntries(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.AccountAccountingDepreciation AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.DepreciationAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	CAST(&AccrueDepreciation AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.DepreciationAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	&DepreciationDebiting,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BusinessLineSales.GLAccountCostOfSales,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	&OtherExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.BusinessLineSales.GLAccountRevenueFromSales,
	|	CASE
	|		WHEN DocumentTable.BusinessLineSales.GLAccountRevenueFromSales.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineSales.GLAccountRevenueFromSales.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&OtherIncome,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
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
	|	6,
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
	|SELECT
	|	7,
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
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("AccrueDepreciation",								NStr("en = 'Accrue depreciation'", MainLanguageCode));
	Query.SetParameter("DepreciationDebiting",								NStr("en = 'Depreciation write-off'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",										NStr("en = 'Other expenses'", MainLanguageCode));
	Query.SetParameter("OtherIncome",										NStr("en = 'Other income'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",								NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",								NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",												DocumentRefPassWA);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPassWA, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPassWA);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	&Ref AS Document,
	|	&Company AS Company,
	|	FixedAssetParametersSliceLast.StructuralUnit AS StructuralUnit,
	|	FixedAssetParametersSliceLast.GLExpenseAccount AS AccountAccountingDepreciation,
	|	FixedAssetParametersSliceLast.GLExpenseAccount.TypeOfAccount AS DepreciationAccountType,
	|	FixedAssetParametersSliceLast.BusinessLine AS BusinessLine,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.GLAccount AS GLAccount,
	|	DocumentTable.FixedAsset.DepreciationAccount AS DepreciationAccount,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	UNDEFINED AS SalesOrder,
	|	DocumentTable.VATRate AS VATRate,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.Depreciation AS Depreciation,
	|	DocumentTable.MonthlyDepreciation AS MonthlyDepreciation,
	|	DocumentTable.DepreciatedCost AS DepreciatedCost,
	|	CAST(CASE
	|			WHEN DocumentTable.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN DocumentTable.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE DocumentTable.VATAmount * DocumentTable.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocumentTable.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN DocumentTable.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE DocumentTable.Total * DocumentTable.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocumentTable.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN DocumentTable.Total * RegExchangeRates.ExchangeRate * DocumentTable.Ref.Multiplicity / (DocumentTable.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE DocumentTable.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TRUE AS FixedCost
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.FixedAssetSale.FixedAssets AS DocumentTable
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(&PointInTime, ) AS FixedAssetParametersSliceLast
	|		ON (&Company = FixedAssetParametersSliceLast.Company)
	|			AND DocumentTable.FixedAsset = FixedAssetParametersSliceLast.FixedAsset
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentTable.Ref = &Ref
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
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.ArApAdjustments)
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
	|	Document.FixedAssetSale.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
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
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.ArApAdjustments)
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
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders";
	
	Query.Execute();
	
	GenerateTableInventory(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableFixedAssetStatuses(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefPassWA, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPassWA, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If there are records in temprorary tables,
	// it is necessary to control the occurrence of negative balances.
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange
		OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
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
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectFixedAssetSale = DocumentRefPassWA.GetObject()
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectFixedAssetSale, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of fixed assets depriciation.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectFixedAssetSale, QueryResultSelection, Cancel);
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

#EndIf