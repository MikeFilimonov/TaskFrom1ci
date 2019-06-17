#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("InventoryIncrease",	NStr("en = 'Inventory purchase'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",		NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Products AS Products,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.Batch AS Batch,
	|	CASE
	|		WHEN DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	DocumentTable.Quantity AS Quantity,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS Amount,
	|	TRUE AS FixedCost,
	|	&InventoryIncrease AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.GLAccount,
	|	VALUE(Catalog.Products.EmptyRef),
	|	DocumentTable.Characteristic,
	|	DocumentTable.Batch,
	|	CASE
	|		WHEN DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END,
	|	0,
	|	DocumentTable.Amount - DocumentTable.VATAmount,
	|	TRUE,
	|	&OtherExpenses
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	(DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	ResultTable = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	Query.Text =
	"SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ExpenseReportInventory.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	ExpenseReportInventory.Products AS Products,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS ExpenseReportInventory
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventoryCostLayer(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	MIN(Inventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.Products AS Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	Inventory.Characteristic AS Characteristic,
	|	&Ref AS CostLayer,
	|	Inventory.Batch AS Batch,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount - Inventory.VATAmount) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableInventory AS Inventory
	|WHERE
	|	&UseFIFO
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateAdvanceHoldersTable(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefExpenseReport);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RepaymentOfAdvanceHolderDebt",	NStr("en = 'Refund from advance holder'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTables.LineNumber) AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTables.Period AS Period,
	|	DocumentTables.Employee AS Employee,
	|	DocumentTables.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	DocumentTables.OverrunGLAccount AS GLAccount,
	|	DocumentTables.Currency AS Currency,
	|	&Ref AS Document,
	|	SUM(DocumentTables.Amount) AS Amount,
	|	SUM(DocumentTables.AmountCur) AS AmountCur
	|INTO TemporaryTableCostsAccountablePerson
	|FROM
	|	(SELECT
	|		MAX(DocumentTable.LineNumber) AS LineNumber,
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Employee AS Employee,
	|		DocumentTable.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount AS OverrunGLAccount,
	|		DocumentTable.Currency AS Currency,
	|		SUM(DocumentTable.Amount) AS Amount,
	|		SUM(DocumentTable.AmountCur) AS AmountCur
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		MAX(DocumentTable.LineNumber),
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency,
	|		SUM(DocumentTable.Amount),
	|		SUM(DocumentTable.AmountCur)
	|	FROM
	|		TemporaryTableExpenses AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		MAX(DocumentTable.LineNumber),
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.DocumentCurrency,
	|		SUM(DocumentTable.Amount),
	|		SUM(DocumentTable.PaymentAmount)
	|	FROM
	|		TemporaryTablePayments AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.DocumentCurrency) AS DocumentTables
	|
	|GROUP BY
	|	DocumentTables.Period,
	|	DocumentTables.Employee,
	|	DocumentTables.AdvanceHoldersGLAccount,
	|	DocumentTables.OverrunGLAccount,
	|	DocumentTables.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.Ref.Employee AS Employee,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount AS GLAccount,
	|	DocumentTable.Document.CashCurrency AS Currency,
	|	DocumentTable.Document AS Document,
	|	SUM(CAST(DocumentTable.Amount * ExchangeRatesOfIssuedAdvances.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfIssuedAdvances.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.Amount) AS AmountCur,
	|	-SUM(CAST(DocumentTable.Amount * ExchangeRatesOfIssuedAdvances.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfIssuedAdvances.Multiplicity) AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(DocumentTable.Amount) AS AmountCurForBalance
	|INTO TemporaryTableAdvancesPaid
	|FROM
	|	Document.ExpenseReport.AdvancesPaid AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfIssuedAdvances
	|		ON DocumentTable.Document.CashCurrency = ExchangeRatesOfIssuedAdvances.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Employee,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount,
	|	DocumentTable.Document.CashCurrency
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount";
	
	Query.ExecuteBatch();
	
	// Setting the exclusive lock of controlled balances of payments to accountable persons.
	Query.Text = 
	"SELECT
	|	TemporaryTableAdvancesPaid.Company AS Company,
	|	TemporaryTableAdvancesPaid.Employee AS Employee,
	|	TemporaryTableAdvancesPaid.Currency AS Currency,
	|	TemporaryTableAdvancesPaid.Document AS Document
	|FROM
	|	TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AdvanceHolders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	
	"SELECT
	|	DocumentTable.Amount AS Amount
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePayments.Amount
	|FROM
	|	TemporaryTablePayments AS TemporaryTablePayments
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsBalances.Company AS Company,
	|	AccountsBalances.Employee AS Employee,
	|	AccountsBalances.Currency AS Currency,
	|	AccountsBalances.Document AS Document,
	|	AccountsBalances.Employee.AdvanceHoldersGLAccount AS GLAccount,
	|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.Employee AS Employee,
	|		TemporaryTable.Currency AS Currency,
	|		TemporaryTable.Document AS Document,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTableAdvancesPaid AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.Employee,
	|		TableBalances.Currency,
	|		TableBalances.Document,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.AdvanceHolders.Balance(
	|				&PointInTime,
	|				(Company, Employee, Currency, Document) In
	|					(SELECT DISTINCT
	|						TemporaryTableAdvancesPaid.Company,
	|						TemporaryTableAdvancesPaid.Employee,
	|						TemporaryTableAdvancesPaid.Currency,
	|						TemporaryTableAdvancesPaid.Document
	|					FROM
	|						TemporaryTableAdvancesPaid)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.Employee,
	|		DocumentRegisterRecords.Currency,
	|		DocumentRegisterRecords.Document,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AdvanceHolders AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
	|
	|GROUP BY
	|	AccountsBalances.Company,
	|	AccountsBalances.Employee,
	|	AccountsBalances.Currency,
	|	AccountsBalances.Document,
	|	AccountsBalances.Employee.AdvanceHoldersGLAccount
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TableAccounts.Company AS Company,
	|	TableAccounts.Employee AS Employee,
	|	TableAccounts.Currency AS Currency,
	|	TableAccounts.Document AS Document,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
	|	TableAccounts.GLAccount AS GLAccount
	|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
	|FROM
	|	TemporaryTableAdvancesPaid AS TableAccounts
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TableAccounts.Company = TableBalances.Company
	|			AND TableAccounts.Employee = TableBalances.Employee
	|			AND TableAccounts.Currency = TableBalances.Currency
	|			AND TableAccounts.Document = TableBalances.Document
	|			AND TableAccounts.GLAccount = TableBalances.GLAccount
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT DISTINCT
	|						TemporaryTableAdvancesPaid.Currency
	|					FROM
	|						TemporaryTableAdvancesPaid)) AS CalculationExchangeRatesSliceLast
	|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Employee AS Employee,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur
	|FROM
	|	TemporaryTableAdvancesPaid AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Currency,
	|	DocumentTable.Amount - ISNULL(TableAdvancesPaid.Amount, 0),
	|	DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0)
	|FROM
	|	TemporaryTableCostsAccountablePerson AS DocumentTable
	|		LEFT JOIN (SELECT
	|			TemporaryTableAdvancesPaid.Currency AS Currency,
	|			SUM(TemporaryTableAdvancesPaid.Amount) AS Amount,
	|			SUM(TemporaryTableAdvancesPaid.AmountCur) AS AmountCur
	|		FROM
	|			TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid
	|		
	|		GROUP BY
	|			TemporaryTableAdvancesPaid.Currency) AS TableAdvancesPaid
	|		ON DocumentTable.Currency = TableAdvancesPaid.Currency
	|WHERE
	|	DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0) > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
	
	ResultsArray = Query.ExecuteBatch();
	AmountTable = ResultsArray[0].Unload(); // table for round-off error calculation
	ResultTable = ResultsArray[3].Unload();
	
	AmountTotal = AmountTable.Total("Amount"); // amount for round-off error calculation
	AmountOfResult = ResultTable.Total("Amount");
	ResultDifference = AmountTotal - AmountOfResult;
	
	If ResultDifference <> 0
		AND ResultTable.Count() > 0 Then
		ResultTable[0].Amount = ResultTable[0].Amount + ResultDifference;
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithAdvanceHolders", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefExpenseReport);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("VendorObligationsRepayment",	NStr("en = 'Payment to supplier'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePayments.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePayments.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePayments.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	&VendorObligationsRepayment AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePayments.GLAccount AS GLAccount,
	|	TemporaryTablePayments.Currency AS Currency,
	|	TemporaryTablePayments.Counterparty AS Counterparty,
	|	TemporaryTablePayments.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByOrders
	|			THEN TemporaryTablePayments.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePayments.Period AS Date,
	|	SUM(TemporaryTablePayments.Amount) AS Amount,
	|	SUM(TemporaryTablePayments.AmountCur) AS AmountCur,
	|	-SUM(TemporaryTablePayments.Amount) AS AmountForBalance,
	|	-SUM(TemporaryTablePayments.AmountCur) AS AmountCurForBalance,
	|	SUM(TemporaryTablePayments.Amount) AS AmountForPayment,
	|	SUM(TemporaryTablePayments.AmountCur) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePayments AS TemporaryTablePayments
	|
	|GROUP BY
	|	TemporaryTablePayments.LineNumber,
	|	TemporaryTablePayments.GLAccount,
	|	TemporaryTablePayments.Currency,
	|	TemporaryTablePayments.Counterparty,
	|	TemporaryTablePayments.Contract,
	|	TemporaryTablePayments.Period,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePayments.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePayments.Document
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByOrders
	|			THEN TemporaryTablePayments.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
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

	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	ResultTable = ResultsArray[QueryNumber].Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefExpenseReport, StructureAdditionalProperties)
   	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefExpenseReport);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",					NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
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
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END,
	|	CASE
	|		WHEN DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END,
	|	DocumentTable.GLAccount,
	|	&OtherExpenses,
	|	0,
	|	DocumentTable.Amount - DocumentTable.VATAmount,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	(DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	DocumentTable.LineNumber";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.Item,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
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
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item";
	
	QueryResult = Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	LockItem.UseFromDataSource("Document", "Document");
	Block.Lock();
	
	TableAmountForWriteOff = QueryResult.Unload();
	
	// Generating the table with remaining balance.
	Query.Text =
	"SELECT
	|	&Period AS Period,
	|	IncomeAndExpensesRetainedBalances.Company AS Company,
	|	IncomeAndExpensesRetainedBalances.Document AS Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|	VALUE(Catalog.CashFlowItems.EmptyRef) AS Item,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountExpenseBalance) AS AmountExpenseBalance
	|FROM
	|	(SELECT
	|		IncomeAndExpensesRetainedBalances.Company AS Company,
	|		IncomeAndExpensesRetainedBalances.Document AS Document,
	|		IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|		IncomeAndExpensesRetainedBalances.AmountIncomeBalance AS AmountIncomeBalance,
	|		IncomeAndExpensesRetainedBalances.AmountExpenseBalance AS AmountExpenseBalance
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained.Balance(
	|				,
	|				Company = &Company
	|					AND Document In
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							TemporaryTablePayments AS DocumentTable)) AS IncomeAndExpensesRetainedBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Company,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Document,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.BusinessLine,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|		END
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained AS DocumentRegisterRecordsOfIncomeAndExpensesPending
	|	WHERE
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Recorder = &Ref) AS IncomeAndExpensesRetainedBalances
	|
	|GROUP BY
	|	IncomeAndExpensesRetainedBalances.Company,
	|	IncomeAndExpensesRetainedBalances.Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine
	|
	|ORDER BY
	|	Document";
	
	TableSumBalance = Query.Execute().Unload();

	TableSumBalance.Indexes.Add("Document");
	
	// Calculation of the write-off amounts.
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountExpenseBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountRowBalances.AmountExpenseBalance;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpenseBalance;
			ElsIf AmountRowBalances.AmountExpenseBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item";
	
	TableAmountForWriteOff = Query.Execute().Unload();
	
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountIncomeBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountRowBalances.AmountIncomeBalance;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating a temporary table with amounts,
	// items and directions of activities. Required to generate movements of income
	// and expenses by cash method.
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	Table.Item AS Item,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	Query.SetParameter("Table", TableSumBalance);
	
	Query.Execute();
	
	// Generating the table for recording in the register.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	Table.Item AS Item,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	UNDEFINED AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.AmountVATPurchase) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.AmountVATPurchase) AS Amount
	|FROM
	|	TemporaryTableInventory AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	UNDEFINED,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate,
	|	SUM(TablePurchases.Quantity),
	|	SUM(TablePurchases.AmountVATPurchase),
	|	SUM(TablePurchases.Amount - TablePurchases.AmountVATPurchase)
	|FROM
	|	TemporaryTableExpenses AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("InventoryIncrease",				NStr("en = 'Inventory purchase'", MainLanguageCode));
	Query.SetParameter("VendorsPayment",				NStr("en = 'Payment to supplier'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",					NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",							DocumentRefExpenseReport);
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.AdvanceHoldersGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(&OtherExpenses AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&InventoryIncrease AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&VendorsPayment AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0)
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0)
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount - ISNULL(TableAdvancesPaid.Amount, 0),
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableCostsAccountablePerson AS DocumentTable
	|		LEFT JOIN (SELECT
	|			TemporaryTableAdvancesPaid.Currency AS Currency,
	|			SUM(TemporaryTableAdvancesPaid.Amount) AS Amount,
	|			SUM(TemporaryTableAdvancesPaid.AmountCur) AS AmountCur
	|		FROM
	|			TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid
	|		
	|		GROUP BY
	|			TemporaryTableAdvancesPaid.Currency) AS TableAdvancesPaid
	|		ON DocumentTable.Currency = TableAdvancesPaid.Currency
	|WHERE
	|	DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0) > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	DocumentTable.Order AS Quote,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.DocumentCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.Currency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.AmountCur
	|			ELSE CAST(DocumentTable.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.DocumentCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.Currency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.AmountCur
	|			ELSE CAST(DocumentTable.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = ExchangeRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|		ON DocumentTable.DocumentCurrency = ExchangeRatesOfPettyCashe.Currency
	|WHERE
	|	(VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = TYPE(Document.PurchaseOrder)
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Order
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	UNDEFINED AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.Currency
	|		ELSE DocumentTable.DocumentCurrency
	|	END AS Currency,
	|	DocumentTable.QuoteToPaymentCalendar AS Quote,
	|	SUM(CASE
	|			WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|				THEN -DocumentTable.AmountCur
	|			ELSE -DocumentTable.PaymentAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.Currency
	|		ELSE DocumentTable.DocumentCurrency
	|	END,
	|	DocumentTable.QuoteToPaymentCalendar
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefExpenseReport, StructureAdditionalProperties) Export
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",									DocumentRefExpenseReport);
	Query.SetParameter("PointInTime",							New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",					StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",							StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryIncrease",						NStr("en = 'Inventory receipt'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",							NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod",	StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Document.Item AS Item
	|FROM
	|	Document.ExpenseReport.AdvancesPaid AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND &IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Item = QueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Query.SetParameter("Item", Item);
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.Employee AS Employee,
	|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Ref.Employee.OverrunGLAccount AS OverrunGLAccount,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Counterparty.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	DocumentTable.Order AS Order,
	|	CASE
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS QuoteToPaymentCalendar,
	|	DocumentTable.ExchangeRate AS ExchangeRate,
	|	DocumentTable.Multiplicity AS Multiplicity,
	|	CASE
	|		WHEN DocumentTable.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Item
	|	END AS Item,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(DocumentTable.PaymentAmount * DocumentTable.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePayments
	|FROM
	|	Document.ExpenseReport.Payments AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Order,
	|	DocumentTable.ExchangeRate,
	|	DocumentTable.Multiplicity,
	|	DocumentTable.Item,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.Ref.Employee.OverrunGLAccount,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount,
	|	DocumentTable.Ref.Employee,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.DocumentCurrency,
	|	DocumentTable.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Counterparty.DoOperationsByOrders,
	|	CASE
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	ExpenseReportInventory.Cell AS Cell,
	|	ExpenseReportInventory.GLAccount AS GLAccount,
	|	ExpenseReportInventory.Products AS Products,
	|	ExpenseReportInventory.BusinessLine AS BusinessLine,
	|	ExpenseReportInventory.Employee AS Employee,
	|	ExpenseReportInventory.Currency AS Currency,
	|	ExpenseReportInventory.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	ExpenseReportInventory.OverrunGLAccount AS OverrunGLAccount,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.SalesOrder AS SalesOrder,
	|	ExpenseReportInventory.Quantity AS Quantity,
	|	ExpenseReportInventory.Amount AS Amount,
	|	ExpenseReportInventory.AmountCur AS AmountCur,
	|	ExpenseReportInventory.VATAmount AS VATAmount,
	|	ExpenseReportInventory.VATRate AS VATRate,
	|	ExpenseReportInventory.AmountVATPurchase AS AmountVATPurchase,
	|	ExpenseReportInventory.VATAmountCur AS VATAmountCur,
	|	CASE
	|		WHEN ExpenseReportInventory.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN &Item
	|		ELSE ExpenseReportInventory.Item
	|	END AS Item,
	|	&Ref AS Document
	|INTO TemporaryTableInventory
	|FROM
	|	(SELECT
	|		ExpenseReportInventory.LineNumber AS LineNumber,
	|		ExpenseReportInventory.Ref.Date AS Period,
	|		&Company AS Company,
	|		ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|		ExpenseReportInventory.Cell AS Cell,
	|		ExpenseReportInventory.Products.InventoryGLAccount AS GLAccount,
	|		ExpenseReportInventory.Products.BusinessLine AS BusinessLine,
	|		ExpenseReportInventory.Products AS Products,
	|		ExpenseReportInventory.Ref.Employee AS Employee,
	|		ExpenseReportInventory.VATRate AS VATRate,
	|		ExpenseReportInventory.Ref.DocumentCurrency AS Currency,
	|		ExpenseReportInventory.Ref.Employee.OverrunGLAccount AS OverrunGLAccount,
	|		ExpenseReportInventory.Ref.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		ExpenseReportInventory.SalesOrder AS SalesOrder,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN ExpenseReportInventory.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		CASE
	|			WHEN &UseBatches
	|				THEN ExpenseReportInventory.Batch
	|			ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|		END AS Batch,
	|		CASE
	|			WHEN VALUETYPE(ExpenseReportInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN ExpenseReportInventory.Quantity
	|			ELSE ExpenseReportInventory.Quantity * ExpenseReportInventory.MeasurementUnit.Factor
	|		END AS Quantity,
	|		CASE
	|			WHEN ExpenseReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE ExpenseReportInventory.VATAmount
	|		END AS VATAmountCur,
	|		CASE
	|			WHEN ExpenseReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CAST(ExpenseReportInventory.VATAmount * ExpenseReportInventory.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExpenseReportInventory.Ref.Multiplicity) AS NUMBER(15, 2))
	|		END AS VATAmount,
	|		CAST(ExpenseReportInventory.VATAmount * ExpenseReportInventory.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExpenseReportInventory.Ref.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchase,
	|		ExpenseReportInventory.Total AS AmountCur,
	|		CAST(ExpenseReportInventory.Total * ExpenseReportInventory.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExpenseReportInventory.Ref.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|		ExpenseReportInventory.Item AS Item,
	|		&InventoryIncrease AS ContentOfAccountingRecord
	|	FROM
	|		Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&PointInTime,
	|					Currency IN
	|						(SELECT
	|							Constants.PresentationCurrency
	|						FROM
	|							Constants AS Constants)) AS AccountingExchangeRates
	|			ON (TRUE)
	|	WHERE
	|		ExpenseReportInventory.Ref = &Ref) AS ExpenseReportInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportExpenses.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ExpenseReportExpenses.Period AS Period,
	|	ExpenseReportExpenses.Company AS Company,
	|	ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
	|	ExpenseReportExpenses.GLAccount AS GLAccount,
	|	ExpenseReportExpenses.Products AS Products,
	|	ExpenseReportExpenses.Employee AS Employee,
	|	ExpenseReportExpenses.Currency AS Currency,
	|	ExpenseReportExpenses.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	ExpenseReportExpenses.OverrunGLAccount AS OverrunGLAccount,
	|	ExpenseReportExpenses.Characteristic AS Characteristic,
	|	ExpenseReportExpenses.Batch AS Batch,
	|	ExpenseReportExpenses.Quantity AS Quantity,
	|	ExpenseReportExpenses.SalesOrder AS SalesOrder,
	|	ExpenseReportExpenses.Amount AS Amount,
	|	ExpenseReportExpenses.AmountCur AS AmountCur,
	|	ExpenseReportExpenses.VATRate AS VATRate,
	|	ExpenseReportExpenses.VATAmount AS VATAmount,
	|	ExpenseReportExpenses.VATAmountCur AS VATAmountCur,
	|	ExpenseReportExpenses.AmountVATPurchase AS AmountVATPurchase,
	|	ExpenseReportExpenses.Accounting_sAccountType AS Accounting_sAccountType,
	|	ExpenseReportExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN ExpenseReportExpenses.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN &Item
	|		ELSE ExpenseReportExpenses.Item
	|	END AS Item,
	|	TRUE AS FixedCost,
	|	&Ref AS Document
	|INTO TemporaryTableExpenses
	|FROM
	|	(SELECT
	|		ExpenseReportExpenses.LineNumber AS LineNumber,
	|		ExpenseReportExpenses.Ref.Date AS Period,
	|		&Company AS Company,
	|		ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
	|		ExpenseReportExpenses.Products.ExpensesGLAccount AS GLAccount,
	|		ExpenseReportExpenses.BusinessLine AS BusinessLine,
	|		ExpenseReportExpenses.Products AS Products,
	|		ExpenseReportExpenses.VATRate AS VATRate,
	|		ExpenseReportExpenses.Ref.Employee AS Employee,
	|		ExpenseReportExpenses.Ref.DocumentCurrency AS Currency,
	|		ExpenseReportExpenses.Ref.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		ExpenseReportExpenses.Ref.Employee.OverrunGLAccount AS OverrunGLAccount,
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|		VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|		CASE
	|			WHEN VALUETYPE(ExpenseReportExpenses.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN ExpenseReportExpenses.Quantity
	|			ELSE ExpenseReportExpenses.Quantity * ExpenseReportExpenses.MeasurementUnit.Factor
	|		END AS Quantity,
	|		ExpenseReportExpenses.SalesOrder AS SalesOrder,
	|		CASE
	|			WHEN ExpenseReportExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE ExpenseReportExpenses.VATAmount
	|		END AS VATAmountCur,
	|		CASE
	|			WHEN ExpenseReportExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CAST(ExpenseReportExpenses.VATAmount * ExpenseReportExpenses.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExpenseReportExpenses.Ref.Multiplicity) AS NUMBER(15, 2))
	|		END AS VATAmount,
	|		CAST(ExpenseReportExpenses.VATAmount * ExpenseReportExpenses.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExpenseReportExpenses.Ref.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchase,
	|		ExpenseReportExpenses.Total AS AmountCur,
	|		ExpenseReportExpenses.Item AS Item,
	|		CAST(ExpenseReportExpenses.Total * ExpenseReportExpenses.Ref.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExpenseReportExpenses.Ref.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|		ExpenseReportExpenses.Products.ExpensesGLAccount.TypeOfAccount AS Accounting_sAccountType
	|	FROM
	|		Document.ExpenseReport.Expenses AS ExpenseReportExpenses
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&PointInTime,
	|					Currency IN
	|						(SELECT
	|							Constants.PresentationCurrency
	|						FROM
	|							Constants AS Constants)) AS AccountingExchangeRates
	|			ON (TRUE)
	|	WHERE
	|		ExpenseReportExpenses.Ref = &Ref) AS ExpenseReportExpenses";
	
	Query.ExecuteBatch();
	
	GenerateTableInventory(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTablePurchases(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInventoryCostLayer(DocumentRefExpenseReport, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefExpenseReport, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.	
	If StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
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
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Cell) In
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
		|	RegisterRecordsAdvanceHoldersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Employee) AS EmployeePresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Currency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Document) AS DocumentPresentation,
		|	ISNULL(AdvanceHoldersBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAdvanceHoldersChange.SumCurChange + ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AccountablePersonBalance,
		|	RegisterRecordsAdvanceHoldersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountChange AS AmountChange,
		|	RegisterRecordsAdvanceHoldersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAdvanceHoldersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange
		|		LEFT JOIN AccumulationRegister.AdvanceHolders.Balance(
		|				&ControlTime,
		|				(Company, Employee, Currency, Document) In
		|					(SELECT
		|						RegisterRecordsAdvanceHoldersChange.Company AS Company,
		|						RegisterRecordsAdvanceHoldersChange.Employee AS Employee,
		|						RegisterRecordsAdvanceHoldersChange.Currency AS Currency,
		|						RegisterRecordsAdvanceHoldersChange.Document AS Document
		|					FROM
		|						RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange)) AS AdvanceHoldersBalances
		|		ON RegisterRecordsAdvanceHoldersChange.Company = AdvanceHoldersBalances.Company
		|			AND RegisterRecordsAdvanceHoldersChange.Employee = AdvanceHoldersBalances.Employee
		|			AND RegisterRecordsAdvanceHoldersChange.Currency = AdvanceHoldersBalances.Currency
		|			AND RegisterRecordsAdvanceHoldersChange.Document = AdvanceHoldersBalances.Document
		|WHERE
		|	(VALUETYPE(AdvanceHoldersBalances.Document) = Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) > 0
		|			OR VALUETYPE(AdvanceHoldersBalances.Document) <> Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
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
			DocumentObjectExpenseReport = DocumentRefExpenseReport.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

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

	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
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

EndProcedure

#EndRegion

#EndIf